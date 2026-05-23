import SwiftUI

// MARK: - SentenceAudioButton
// A prominent, labelled audio button for sentence-level playback in the reading exercise.
// Sits between the word chip (which has a small SpeakerButton) and the full-size
// AudioPromptButton used in listening/dictation exercises.
struct SentenceAudioButton: View {
    let sentence: String
    private let tts = TTSService.shared

    private var isActive:  Bool { tts.activeText == sentence }
    private var isPlaying: Bool { isActive && tts.playState == .playing }
    private var isLoading: Bool { isActive && tts.playState == .loading }

    var body: some View {
        Button {
            Task { await tts.speak(sentence) }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.luxGreen.opacity(0.12) : Color(.systemGray5))
                        .frame(width: 56, height: 56)
                    if isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(isActive ? .luxGreen : .secondary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                Text("Hear sentence")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - SpeakerButton
struct SpeakerButton: View {
    let text: String
    var audioUrl: String? = nil
    private let tts = TTSService.shared

    private var isActive: Bool { tts.activeText == text }
    private var isLoading: Bool { isActive && tts.playState == .loading }
    private var isPlaying: Bool { isActive && tts.playState == .playing }

    var body: some View {
        Button {
            Task {
                if let url = audioUrl {
                    await tts.speakUrl(url, identifier: text)
                } else {
                    await tts.speak(text)
                }
            }
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.75)
                } else {
                    Image(systemName: isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .foregroundColor(isActive ? .luxGreen : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
    }
}
