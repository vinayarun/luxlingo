import SwiftUI

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
