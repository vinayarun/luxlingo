import SwiftUI

// MARK: - SentenceAudioButton
// Prominent, labelled audio button for sentence-level playback in the reading exercise.
struct SentenceAudioButton: View {
    let sentence: String
    private let tts = TTSService.shared

    private var isActive:  Bool { tts.activeText == sentence }
    private var isPlaying: Bool { isActive && tts.playState == .playing }
    private var isLoading: Bool { isActive && tts.playState == .loading }

    @State private var pulseScale: CGFloat   = 1.0
    @State private var pulseOpacity: Double  = 0.0

    var body: some View {
        Button {
            LuxHaptic.light()
            Task { await tts.speak(sentence) }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    // Pulsing ring when playing
                    Circle()
                        .stroke(Color.luxGreen.opacity(0.25), lineWidth: 2.5)
                        .scaleEffect(pulseScale)
                        .opacity(pulseOpacity)

                    Circle()
                        .fill(
                            isActive
                                ? LinearGradient(colors: [Color.luxGreen.opacity(0.18), Color.luxGreen.opacity(0.08)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color(.systemGray5), Color(.systemGray6)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 48, height: 48)

                    if isLoading {
                        ProgressView().scaleEffect(0.75).tint(Color.luxGreen)
                    } else {
                        Image(systemName: isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(isActive ? .luxGreen : Color(.systemGray2))
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 1) {
                    Text(isPlaying ? "Playing…" : "Hear sentence")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(isActive ? .luxGreen : .secondary)
                    Text(isLoading ? "Loading audio…" : "Tap to replay")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isActive ? Color.luxGreen.opacity(0.07) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? Color.luxGreen.opacity(0.30) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.luxSpring, value: isActive)
        .animation(.luxQuick, value: isPlaying)
        .onChange(of: isPlaying) { _, playing in
            if playing {
                withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    pulseScale   = 1.7
                    pulseOpacity = 0
                }
            } else {
                pulseScale   = 1.0
                pulseOpacity = 0
            }
        }
    }
}

// MARK: - SpeakerButton
// Small inline speaker for word-level playback (chip labels, vocab rows, etc.)
struct SpeakerButton: View {
    let text: String
    var audioUrl: String? = nil
    private let tts = TTSService.shared

    private var isActive:  Bool { tts.activeText == text }
    private var isLoading: Bool { isActive && tts.playState == .loading }
    private var isPlaying: Bool { isActive && tts.playState == .playing }

    var body: some View {
        Button {
            LuxHaptic.light()
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
                        .scaleEffect(0.70)
                        .tint(isActive ? .luxGreen : .secondary)
                } else {
                    Image(systemName: isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .foregroundColor(isActive ? .luxGreen : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}
