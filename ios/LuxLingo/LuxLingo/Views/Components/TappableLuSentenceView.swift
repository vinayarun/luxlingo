import SwiftUI

// Displays a Luxembourgish sentence as tappable word chips.
// Tapping a word fetches its English meaning from lod.lu and shows it in an inline card.
struct TappableLuSentenceView: View {
    let text: String
    var highlight: String = ""      // target lemma — shown green/bold
    var actualForm: String? = nil   // conjugated/n-rule form in sentence — shown amber if differs from highlight
    var highlightMeaning: String? = nil  // seed primary_en for the highlighted word; shown immediately, no network call

    @State private var tappedWord: String? = nil
    @State private var lookupResult: WordLookupResult? = nil
    @State private var isLoading = false

    private static let punct = CharacterSet(charactersIn: ".,?!:;\"()'«»")

    private var words: [String] {
        text.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            CenteredWordFlow(spacing: 4, lineSpacing: 6) {
                ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                    WordChip(
                        word: word,
                        isLemma: wordMatches(word, highlight),
                        isForm: wordMatchesForm(word),
                        isTapped: tappedWord.map { wordMatches(word, $0) } ?? false,
                        onTap: { handleTap(word: word) }
                    )
                }
            }

            if let tapped = tappedWord {
                WordLookupCard(
                    word: tapped,
                    result: lookupResult,
                    isLoading: isLoading,
                    onDismiss: dismiss,
                    isLessonWord: wordMatches(tapped, highlight) && highlightMeaning != nil
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.luxSpring, value: tappedWord)
        .animation(.luxSpring, value: lookupResult?.translations.first)
        .onChange(of: text) { _, _ in dismiss() }
    }

    private func wordMatches(_ word: String, _ target: String) -> Bool {
        guard !target.isEmpty else { return false }
        return word.trimmingCharacters(in: Self.punct).lowercased() == target.lowercased()
    }

    private func wordMatchesForm(_ word: String) -> Bool {
        guard let form = actualForm, !form.isEmpty else { return false }
        let clean = word.trimmingCharacters(in: Self.punct).lowercased()
        return clean == form.lowercased() && clean != highlight.lowercased()
    }

    private func handleTap(word: String) {
        let clean = word.trimmingCharacters(in: Self.punct)
        guard !clean.isEmpty else { return }
        if tappedWord?.lowercased() == clean.lowercased() { dismiss(); return }

        tappedWord = clean
        lookupResult = nil

        // For the highlighted (target) word we already know the correct contextual meaning
        // from the seed — use it directly instead of lod.lu to avoid polysemy issues.
        if wordMatches(word, highlight), let meaning = highlightMeaning {
            isLoading = false
            lookupResult = WordLookupResult(word: clean, translations: [meaning], partOfSpeech: nil)
            return
        }

        isLoading = true
        Task {
            let result = await WordLookupService.shared.lookup(word: clean)
            isLoading = false
            lookupResult = result
        }
    }

    private func dismiss() {
        tappedWord = nil
        lookupResult = nil
        isLoading = false
    }
}

// MARK: - Word Chip

private struct WordChip: View {
    let word: String
    let isLemma: Bool
    let isForm: Bool
    let isTapped: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(word)
                .fontWeight(isLemma ? .bold : isForm ? .semibold : .regular)
                .foregroundColor(foregroundColor)
                .underline(isForm, color: .luxAmber)
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
                .background(isTapped ? Color.accentColor.opacity(0.12) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        if isLemma { return .luxGreen }
        if isForm { return .luxAmber }
        if isTapped { return .accentColor }
        return .primary
    }
}

// MARK: - Word Lookup Card

struct WordLookupCard: View {
    let word: String
    let result: WordLookupResult?
    let isLoading: Bool
    let onDismiss: () -> Void
    var isLessonWord: Bool = false  // true when meaning comes from seed (the target being taught)

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(word)
                        .font(.subheadline).fontWeight(.bold)
                    if isLessonWord {
                        Text("lesson word")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.luxGreen.opacity(0.15))
                            .foregroundColor(.luxGreen)
                            .cornerRadius(4)
                    } else if let pos = result?.partOfSpeech {
                        Text(pos)
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                }

                if isLoading {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.75)
                        Text("Looking up…")
                            .font(.caption).foregroundColor(.secondary)
                    }
                } else if let translations = result?.translations, !translations.isEmpty {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(translations.enumerated()), id: \.offset) { i, t in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("\(i + 1).")
                                        .font(.caption).foregroundColor(.secondary)
                                        .frame(minWidth: 16, alignment: .trailing)
                                    Text(t)
                                        .font(.subheadline).foregroundColor(.secondary)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(.trailing, 6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: translations.count <= 3 ? nil : 100)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Not found in dictionary")
                            .font(.caption).foregroundColor(.secondary).italic()
                        Text("Tip: this may be an inflected form — look up the base word")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color(.tertiaryLabel))
                    .font(.title3)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }
}

// MARK: - Centered Flow Layout

struct CenteredWordFlow: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 6

    private struct Row {
        var items: [(LayoutSubview, CGSize)] = []
        var height: CGFloat = 0
        var totalWidth: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxW = proposal.width ?? UIScreen.main.bounds.width
        let rows = computeRows(subviews: subviews, maxWidth: maxW)
        let totalH = rows.reduce(0) { $0 + $1.height } + max(0, CGFloat(rows.count - 1)) * lineSpacing
        return CGSize(width: maxW, height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = computeRows(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX + (bounds.width - row.totalWidth) / 2
            for (sv, size) in row.items {
                sv.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func computeRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            let needed = current.items.isEmpty ? size.width : current.totalWidth + spacing + size.width
            if !current.items.isEmpty && needed > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.items.append((sv, size))
            current.height = max(current.height, size.height)
            current.totalWidth = current.items.count == 1 ? size.width : current.totalWidth + spacing + size.width
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
