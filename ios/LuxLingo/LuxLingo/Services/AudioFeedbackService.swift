import AVFoundation
import UIKit

/// Plays short tonal feedback sounds and fires haptics on correct/wrong answers.
/// Audio uses the .ambient session category — sounds respect the mute switch and
/// mix with whatever the user is already listening to.
@MainActor
final class AudioFeedbackService {
    static let shared = AudioFeedbackService()

    private var correctPlayer: AVAudioPlayer?
    private var wrongPlayer: AVAudioPlayer?
    private let successGenerator = UINotificationFeedbackGenerator()
    private let errorGenerator   = UINotificationFeedbackGenerator()

    private init() {
        // Don't touch the audio session here — TTSService owns it and sets .playback,
        // which also lets our feedback tones play through even when the phone is muted.
        // That's the right call for a language learning app.
        correctPlayer = player(for: "correct")
        wrongPlayer   = player(for: "wrong")
        // Warm up haptic engines so first fire has no latency
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
        correctPlayer?.play()
        successGenerator.notificationOccurred(.success)
        successGenerator.prepare() // re-warm for next time
    }

    func playWrong() {
        wrongPlayer?.currentTime = 0
        wrongPlayer?.play()
        errorGenerator.notificationOccurred(.error)
        errorGenerator.prepare()
    }
}
