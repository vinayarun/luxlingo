import Foundation
import AVFoundation

enum TTSError: Error {
    case timeout
    case invalidAudio
    case sessionExpired
}

@MainActor
@Observable
final class TTSService {
    static let shared = TTSService()

    enum PlayState { case idle, loading, playing }

    var playState: PlayState = .idle
    var activeText: String = ""

    /// Playback speed for all audio (TTS and lod.lu pronunciation).
    /// 1.0 = normal, 0.85 = 15% slower — easier to follow for language learners.
    static let speechRate: Float = 0.85

    private let baseURL = "https://sproochmaschinn.lu"
    private var sessionId: String?
    private var lastUsed: Date = .distantPast
    private var player: AVAudioPlayer?
    private let playerDelegate = _PlayerDelegate()

    private init() {
        playerDelegate.onFinish = { [weak self] in
            self?.playState = .idle
            self?.activeText = ""
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    }

    // MARK: - Public

    func speakUrl(_ urlString: String, identifier: String) async {
        if activeText == identifier, playState != .idle {
            player?.stop()
            playState = .idle
            activeText = ""
            return
        }
        guard playState == .idle else { return }

        playState = .loading
        activeText = identifier

        do {
            guard let url = URL(string: urlString) else {
                playState = .idle
                activeText = ""
                return
            }
            let (data, _) = try await URLSession.shared.data(from: url)

            guard activeText == identifier else { return }

            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(data: data)
            p.enableRate = true
            p.rate = Self.speechRate
            p.delegate = playerDelegate
            player = p
            playState = .playing
            p.play()
            lastUsed = Date()
        } catch {
            playState = .idle
            activeText = ""
        }
    }

    func speak(_ text: String) async {
        // Tap again while active → stop
        if activeText == text, playState != .idle {
            player?.stop()
            playState = .idle
            activeText = ""
            return
        }
        guard playState == .idle else { return }

        playState = .loading
        activeText = text

        do {
            let sid = try await validSession()
            let requestId = try await submitTTS(sid: sid, text: text)
            let wav = try await pollAudio(requestId: requestId)

            guard activeText == text else { return } // cancelled mid-flight

            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(data: wav)
            p.delegate = playerDelegate
            player = p
            playState = .playing
            p.play()
            lastUsed = Date()
        } catch {
            playState = .idle
            activeText = ""
        }
    }

    // MARK: - Session

    private func validSession() async throws -> String {
        if let id = sessionId, Date().timeIntervalSince(lastUsed) < 540 {
            return id
        }
        return try await createSession()
    }

    private func createSession() async throws -> String {
        var req = URLRequest(url: URL(string: "\(baseURL)/api/session")!)
        req.httpMethod = "POST"
        let (data, _) = try await URLSession.shared.data(for: req)
        struct R: Decodable { let session_id: String }
        let id = try JSONDecoder().decode(R.self, from: data).session_id
        sessionId = id
        lastUsed = Date()
        return id
    }

    // MARK: - TTS

    private func submitTTS(sid: String, text: String) async throws -> String {
        var req = URLRequest(url: URL(string: "\(baseURL)/api/tts/\(sid)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct Body: Encodable { let text: String; let model: String }
        req.httpBody = try JSONEncoder().encode(Body(text: text, model: "claude"))
        let (data, resp) = try await URLSession.shared.data(for: req)
        if (resp as? HTTPURLResponse)?.statusCode == 404 {
            sessionId = nil
            throw TTSError.sessionExpired
        }
        struct R: Decodable { let request_id: String }
        return try JSONDecoder().decode(R.self, from: data).request_id
    }

    private func pollAudio(requestId: String) async throws -> Data {
        let url = URL(string: "\(baseURL)/api/result/\(requestId)")!
        for attempt in 0..<25 {
            // First check after 600ms, subsequent checks every 1s
            try await Task.sleep(nanoseconds: attempt == 0 ? 600_000_000 : 1_000_000_000)
            let (data, _) = try await URLSession.shared.data(from: url)
            struct R: Decodable {
                let status: String
                let result: AudioResult?
                struct AudioResult: Decodable { let data: String? }
            }
            let r = try JSONDecoder().decode(R.self, from: data)
            if r.status == "completed",
               let b64 = r.result?.data,
               let wav = Data(base64Encoded: b64) {
                return wav
            }
        }
        throw TTSError.timeout
    }
}

// MARK: - AVAudioPlayerDelegate bridge
private final class _PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully _: Bool) {
        DispatchQueue.main.async { self.onFinish?() }
    }
}
