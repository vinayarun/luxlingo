import Foundation
import AVFoundation

// MARK: - Data models

struct PronunciationJob: Codable, Identifiable {
    var id: String { jobId }
    let jobId: String
    let targetWord: String
    let senseId: String
    let submittedAt: Date
}

struct PronunciationResult: Codable, Identifiable {
    var id: String { senseId + String(completedAt.timeIntervalSince1970) }
    let senseId: String
    let targetWord: String
    let transcription: String   // what LuxASR heard
    let score: Int              // 0–100
    let completedAt: Date
    var viewed: Bool = false    // cleared after shown to user
}

// MARK: - Service

@MainActor
@Observable
final class PronunciationService: NSObject {

    static let shared = PronunciationService()

    // ── Recording state ──────────────────────────────────────────────────────
    var isRecording      = false
    var amplitudeLevels  = [Float](repeating: 0, count: 14)  // normalised 0–1
    var timeElapsed: Double = 0                               // seconds since rec started
    var recordingURL: URL? = nil

    // ── Results ──────────────────────────────────────────────────────────────
    var pendingJobs: [PronunciationJob]  = []
    var completedResults: [PronunciationResult] = []
    /// Non-nil while there is a new result the exercise screen hasn't shown yet.
    var newResultAvailable: PronunciationResult? = nil

    // ── Private state ────────────────────────────────────────────────────────
    private var recorder: AVAudioRecorder?
    private var amplitudeTimer: Timer?
    private var pollTask: Task<Void, Never>?
    private var maxDuration: Double = 5
    private var activeRecordingURL: URL? = nil   // set in startRecording, cleared in stopRecording

    /// Becomes true when the timer auto-stops a recording — view observes this to advance phase.
    var autoStopFired = false

    private let luxASRBase = "https://luxasr.uni.lu"

    // MARK: - Init

    private override init() {
        super.init()
        loadPersistedState()
        // Resume polling for any jobs that were in-flight when the app last closed
        if !pendingJobs.isEmpty { startPolling() }
    }

    // MARK: - Recording

    /// Call from async context; returns false if microphone permission denied.
    func startRecording(maxDuration: Double) async -> Bool {
        self.maxDuration = maxDuration
        recordingURL = nil

        // Request permission
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { return false }

        // Configure audio session for recording (duck background audio)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default,
                                 options: [.duckOthers, .defaultToSpeaker])
        try? session.setActive(true)

        // Stable location in Documents (temp directory gets cleaned up too aggressively)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url  = docs.appendingPathComponent("pronunciation_\(Date().timeIntervalSince1970).wav")
        activeRecordingURL = url   // ← store it now, before the recorder even starts

        let settings: [String: Any] = [
            AVFormatIDKey:            Int(kAudioFormatLinearPCM),
            AVSampleRateKey:          16_000,
            AVNumberOfChannelsKey:    1,
            AVLinearPCMBitDepthKey:   16,
            AVLinearPCMIsFloatKey:    false,
            AVLinearPCMIsBigEndianKey: false
        ]

        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else {
            activeRecordingURL = nil; return false
        }
        rec.isMeteringEnabled = true
        rec.delegate = self
        rec.record()
        recorder = rec

        isRecording     = true
        autoStopFired   = false
        timeElapsed     = 0
        amplitudeLevels = [Float](repeating: 0, count: 14)

        amplitudeTimer = Timer.scheduledTimer(withTimeInterval: 1/16, repeats: true) { [weak self] _ in
            self?.tickTimer()
        }

        return true
    }

    @discardableResult
    func stopRecording() -> URL? {
        guard isRecording else { return recordingURL }
        recorder?.stop()
        recorder = nil
        amplitudeTimer?.invalidate(); amplitudeTimer = nil
        isRecording = false

        // Use the URL we stored at recording-start time — reliable, no directory scan needed
        let url = activeRecordingURL
        activeRecordingURL = nil
        recordingURL = url
        return url
    }

    private func tickTimer() {
        guard let rec = recorder, rec.isRecording else { return }
        rec.updateMeters()
        timeElapsed += 1/16

        // Shift amplitude history left and append new value
        let power = rec.averagePower(forChannel: 0)           // dB, typically –160…0
        let normalized = Float(max(0, min(1, (Double(power) + 50) / 50)))  // map –50…0 dB → 0…1
        amplitudeLevels.removeFirst()
        amplitudeLevels.append(normalized)

        // Auto-stop when time limit reached — set autoStopFired so the view can react
        if timeElapsed >= maxDuration {
            stopRecording()
            autoStopFired = true   // view's .onChange(of: service.autoStopFired) handles phase transition
        }
    }

    // MARK: - Submit to LuxASR

    func submitForScoring(audioURL: URL, targetWord: String, senseId: String) {
        Task {
            guard let audioData = try? Data(contentsOf: audioURL) else { return }

            var request = URLRequest(url: URL(string: "\(luxASRBase)/asr2?language=lb&diarization=Disabled&outfmt=text")!)
            request.httpMethod  = "POST"
            request.httpBody    = audioData
            request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
            request.setValue("pronunciation_practice.wav", forHTTPHeaderField: "X-Filename")
            request.timeoutInterval = 15

            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let json = try? JSONDecoder().decode([String: String].self, from: data),
                  let jobId = json["job_id"] else {
                print("[Pronunciation] LuxASR submission failed")
                return
            }

            let job = PronunciationJob(
                jobId: jobId,
                targetWord: targetWord,
                senseId: senseId,
                submittedAt: Date()
            )
            pendingJobs.append(job)
            persistState()
            startPolling()
            print("[Pronunciation] Submitted job \(jobId) for '\(targetWord)'")
        }
    }

    // MARK: - Polling

    private func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task {
            while !pendingJobs.isEmpty {
                try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3s interval
                await pollOnce()
            }
            pollTask = nil
        }
    }

    private func pollOnce() async {
        var remaining: [PronunciationJob] = []

        for job in pendingJobs {
            // Check status — use JSONSerialization (not Codable) because the response
            // mixes String and Bool values, e.g. "result_ready": true
            guard let statusURL = URL(string: "\(luxASRBase)/v3/asr/jobs/\(job.jobId)"),
                  let (statusData, _) = try? await URLSession.shared.data(from: statusURL),
                  let statusJson = try? JSONSerialization.jsonObject(with: statusData) as? [String: Any],
                  let status = statusJson["status"] as? String
            else { remaining.append(job); continue }

            print("[Pronunciation] Job \(job.jobId) status: \(status)")

            switch status {
            case "completed":
                if let result = await fetchResult(for: job) {
                    completedResults.append(result)
                    newResultAvailable = result
                    persistState()
                    print("[Pronunciation] Job \(job.jobId) score: \(result.score)% — heard: '\(result.transcription)'")
                }
            case "failed":
                print("[Pronunciation] Job \(job.jobId) failed")
            default:
                remaining.append(job)
            }
        }

        pendingJobs = remaining
        if pendingJobs.isEmpty {
            pollTask?.cancel()
            pollTask = nil
        }
    }

    private func fetchResult(for job: PronunciationJob) async -> PronunciationResult? {
        guard let resultURL = URL(string: "\(luxASRBase)/v3/asr/jobs/\(job.jobId)/result"),
              let (data, _) = try? await URLSession.shared.data(from: resultURL)
        else { return nil }

        // LuxASR returns either a bare quoted string ("some text") or a JSON object.
        // Use JSONSerialization for the object case to handle mixed types.
        var transcription = ""
        if let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) {
            if !raw.isEmpty && !raw.hasPrefix("{") {
                transcription = raw
            } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                transcription = (json["Luxembourgish"] as? String)
                    ?? (json.values.compactMap { $0 as? String }.first)
                    ?? ""
            }
        }

        let score = pronunciationScore(transcription: transcription, target: job.targetWord)
        return PronunciationResult(
            senseId:       job.senseId,
            targetWord:    job.targetWord,
            transcription: transcription,
            score:         score,
            completedAt:   Date()
        )
    }

    // MARK: - Scoring

    /// Normalised edit-distance score: 100 = perfect, 0 = nothing matched.
    private func pronunciationScore(transcription: String, target: String) -> Int {
        let t = normalize(transcription)
        let r = normalize(target)
        guard !r.isEmpty else { return 0 }
        if t == r { return 100 }
        let dist = levenshtein(t, r)
        let maxLen = max(t.count, r.count)
        return max(0, 100 - Int(Double(dist) / Double(maxLen) * 100))
    }

    private func normalize(_ s: String) -> String {
        s.lowercased()
         .folding(options: .diacriticInsensitive, locale: .current)
         .components(separatedBy: CharacterSet.alphanumerics.inverted)
         .joined(separator: " ")
         .trimmingCharacters(in: .whitespaces)
    }

    private func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var dp = Array(0...b.count)
        for i in 1...a.count {
            var prev = dp[0]; dp[0] = i
            for j in 1...b.count {
                let temp = dp[j]
                dp[j] = a[i-1] == b[j-1] ? prev : min(prev, min(dp[j], dp[j-1])) + 1
                prev = temp
            }
        }
        return dp[b.count]
    }

    // MARK: - Persistence

    private let jobsKey    = "pronunciation_pending_jobs"
    private let resultsKey = "pronunciation_completed_results"

    func persistState() {
        if let d = try? JSONEncoder().encode(pendingJobs) {
            UserDefaults.standard.set(d, forKey: jobsKey)
        }
        // Keep last 20 results
        let toStore = Array(completedResults.suffix(20))
        if let d = try? JSONEncoder().encode(toStore) {
            UserDefaults.standard.set(d, forKey: resultsKey)
        }
    }

    private func loadPersistedState() {
        if let d = UserDefaults.standard.data(forKey: jobsKey),
           let jobs = try? JSONDecoder().decode([PronunciationJob].self, from: d) {
            pendingJobs = jobs
        }
        if let d = UserDefaults.standard.data(forKey: resultsKey),
           let results = try? JSONDecoder().decode([PronunciationResult].self, from: d) {
            completedResults = results
        }
    }

    /// Mark all results as viewed (called after home-screen card is dismissed).
    func markAllResultsViewed() {
        for i in completedResults.indices { completedResults[i].viewed = true }
        persistState()
    }

    var hasUnviewedResults: Bool { completedResults.contains { !$0.viewed } }
}

// MARK: - AVAudioRecorderDelegate

extension PronunciationService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.isRecording = false
            // Restore audio session so TTS/tones can resume
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

// MARK: - URL creation date helper

private extension URL {
    var creationDate: Date? {
        (try? resourceValues(forKeys: [.creationDateKey]))?.creationDate
    }
}
