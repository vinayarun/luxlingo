import AVFoundation
import UIKit

/// Plays short tonal feedback sounds and fires haptics on correct/wrong answers.
/// Audio uses .duckOthers (set by TTSService) — background podcasts/music briefly
/// lower while a tone plays, then restore automatically when the tone finishes.
@MainActor
final class AudioFeedbackService {
    static let shared = AudioFeedbackService()

    private var correctPlayer: AVAudioPlayer?
    private var wrongPlayer: AVAudioPlayer?
    private let successGenerator = UINotificationFeedbackGenerator()
    private let errorGenerator   = UINotificationFeedbackGenerator()
    // Delegate that deactivates the audio session when a short tone finishes,
    // letting iOS tell podcasts/music to restore their volume immediately.
    private let toneDelegate = _ToneDelegate()

    private init() {
        correctPlayer = player(for: "correct")
        wrongPlayer   = player(for: "wrong")
        correctPlayer?.delegate = toneDelegate
        wrongPlayer?.delegate   = toneDelegate
        successGenerator.prepare()
        errorGenerator.prepare()
    }

    private func player(for name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        let p = try? AVAudioPlayer(contentsOf: url)
        p?.prepareToPlay()
        return p
    }

    func playCorrect() {
        correctPlayer?.currentTime = 0
        correctPlayer?.volume = 1.0
        correctPlayer?.play()
        successGenerator.notificationOccurred(.success)
        successGenerator.prepare()
    }

    func playWrong() {
        wrongPlayer?.currentTime = 0
        wrongPlayer?.play()
        errorGenerator.notificationOccurred(.error)
        errorGenerator.prepare()
    }

    /// Softer confirmation for reading exercises — no "correct answer" connotation.
    func playReading() {
        correctPlayer?.currentTime = 0
        correctPlayer?.volume = 0.3
        correctPlayer?.play()
        correctPlayer?.volume = 1.0  // restore for next playCorrect call
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    /// Celebratory chime when all matching pairs are completed.
    func playMatchingComplete() {
        correctPlayer?.currentTime = 0
        correctPlayer?.volume = 1.0
        correctPlayer?.play()
        successGenerator.notificationOccurred(.success)
        successGenerator.prepare()
    }
}

// Deactivates the shared AVAudioSession when a short feedback tone finishes,
// signalling iOS to restore background audio (podcasts, music) to full volume.
private final class _ToneDelegate: NSObject, AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully _: Bool) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
