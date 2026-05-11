import SwiftUI

struct NRuleHunterView: View {
    let sentence: String
    let targetWordIndex: Int // Index of the word with the 'n'
    @Binding var currentSelection: String // "n" or ""
    let showHint: Bool
    let onToggle: (String) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Sentence Card — uses flow layout so long sentences wrap naturally
            let words = sentence.split(separator: " ").map(String.init)
            CenteredWordFlow(spacing: 4, lineSpacing: 8) {
                ForEach(0..<words.count, id: \.self) { i in
                    if i == targetWordIndex {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(words[i].hasSuffix("n") ? String(words[i].dropLast()) : words[i])
                                .font(.title2)
                                .fontWeight(.bold)

                            Button(action: {
                                let newValue = (currentSelection == "n") ? "" : "n"
                                onToggle(newValue)
                            }) {
                                Text(currentSelection.isEmpty ? "_" : "n")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .frame(width: 28)
                                    .background(Color.luxPurple.opacity(0.2))
                                    .foregroundColor(.luxPurple)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.luxPurple, lineWidth: 2)
                                    )
                                    .scaleEffect(currentSelection.isEmpty ? 1.1 : 1.0)
                                    .shadow(color: .luxPurple.opacity(currentSelection.isEmpty ? 0.3 : 0), radius: 4)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 2)
                            .animation(.luxSpring, value: currentSelection)
                        }
                    } else {
                        Text(words[i])
                            .font(.title2)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            
            if showHint {
                VStack(alignment: .leading, spacing: 12) {
                    Label("The Luxembourgish N-Rule (Eifeler Regel)", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundColor(.luxAmber)

                    Text("Words ending in **'n'** (like *den, een, kënnen*) **drop the 'n'** when the next word starts with certain consonants.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)

                    Text("Keep the **'n'** if the next word starts with **UNITED ZOHA** (U, N, I, T, E, D, Z, O, H, A) or any vowel. Otherwise, drop it.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                .padding()
                .background(Color.luxAmber.opacity(0.1))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
