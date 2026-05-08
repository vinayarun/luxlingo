import SwiftUI

/// Strips parenthetical reflexive pronouns (e.g. "(mech)") and returns the verb form.
/// "ech hunn (mech)" → "hunn",  "hien/si/et huet (sech)" → "huet"
private func verbFormOnly(_ row: String) -> String {
    let parts = row.components(separatedBy: " ").filter { !$0.hasPrefix("(") }
    return parts.last ?? row
}

// MARK: - Flashcard Exercise
struct FlashcardExercise: View {
    let targetWord: String
    let translation: String
    let exampleSentenceLu: String
    let exampleSentenceEn: String
    var sentenceTargetWord: String? = nil  // actual form in sentence (may differ from lemma)
    var paradigm: [String]? = nil
    var lodAudioUrl: String? = nil
    var nRuleForm: String? = nil

    @State private var showConjugation = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                // Word + speaker button
                HStack(alignment: .center, spacing: 10) {
                    Text(targetWord)
                        .font(.system(size: targetWord.count > 10 ? 34 : 46, weight: .bold))
                        .foregroundColor(.luxGreen)
                        .shadow(color: .luxGreen.opacity(0.15), radius: 6, y: 3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    SpeakerButton(text: targetWord, audioUrl: lodAudioUrl)
                        .font(.title2)
                        .frame(width: 32, height: 32)
                        .background(Color.luxGreen.opacity(0.08))
                        .clipShape(Circle())
                }

                Text(translation)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                // Hint chips: conjugation and/or n-rule
                if paradigm != nil || nRuleForm != nil {
                    HStack(spacing: 8) {
                        if let p = paradigm {
                            Button {
                                showConjugation = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.caption2)
                                    let conjugatedForm = p.first(where: {
                                        verbFormOnly($0).lowercased() != targetWord.lowercased()
                                    }).map { verbFormOnly($0) } ?? ""
                                    Text(conjugatedForm.isEmpty ? "Conjugations" : "\(targetWord) → \(conjugatedForm)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                }
                                .foregroundColor(.luxAmber)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.luxAmber.opacity(0.12))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }

                        if let nForm = nRuleForm {
                            HStack(spacing: 4) {
                                Image(systemName: "n.circle")
                                    .font(.caption2)
                                Text("\(targetWord) → \(nForm)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("n-rule")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(.luxPurple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.luxPurple.opacity(0.10))
                            .cornerRadius(8)
                        }
                    }
                }

                Rectangle()
                    .fill(Color.luxGreen.opacity(0.3))
                    .frame(height: 1)
                    .frame(maxWidth: 60)
                    .padding(.vertical, 4)

                VStack(spacing: 8) {
                    if !exampleSentenceLu.isEmpty {
                        TappableLuSentenceView(
                            text: exampleSentenceLu,
                            highlight: targetWord,
                            actualForm: sentenceTargetWord,
                            highlightMeaning: translation
                        )
                        .font(.title3)
                    }

                    if !exampleSentenceEn.isEmpty {
                        Text(exampleSentenceEn)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 280)
            .background(
                LinearGradient(
                    colors: [Color.luxGreen.opacity(0.04), Color.luxGreen.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.luxGreen.opacity(0.2), lineWidth: 2)
            )
        }
        .sheet(isPresented: $showConjugation) {
            if let p = paradigm {
                ConjugationPanel(lemma: targetWord, translation: translation, rows: p)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Conjugation Highlighted Text
// Highlights the lemma in green/bold. If actualForm differs from lemma, highlights that form in amber+underline.
struct ConjugationHighlightedText: View {
    let text: String
    let lemma: String
    var actualForm: String? = nil  // conjugated/modified form in the sentence (nil = same as lemma)

    private static let punct = CharacterSet(charactersIn: ".,?!:;\"()'")

    var body: some View {
        let words = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        let lemmaLower = lemma.lowercased().trimmingCharacters(in: Self.punct)
        let actualLower = (actualForm ?? lemma).lowercased().trimmingCharacters(in: Self.punct)
        let hasConjugation = actualLower != lemmaLower

        return words.enumerated().reduce(Text("")) { result, pair in
            let (idx, word) = pair
            let wordClean = word.lowercased().trimmingCharacters(in: Self.punct)
            let spacer = idx < words.count - 1 ? " " : ""

            if wordClean == lemmaLower {
                return result + Text(word + spacer).foregroundColor(.luxGreen).fontWeight(.bold)
            } else if hasConjugation && wordClean == actualLower {
                return result + Text(word + spacer).foregroundColor(.luxAmber).fontWeight(.semibold).underline(true, color: .luxAmber)
            } else {
                return result + Text(word + spacer).foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Conjugation Panel (sheet content)
struct ConjugationPanel: View {
    let lemma: String
    let translation: String
    let rows: [String]   // ["ech kann", "du kanns", ...]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lemma)
                        .font(.title2.bold())
                        .foregroundColor(.luxGreen)
                    Text(translation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "book.closed")
                    .font(.title2)
                    .foregroundColor(.luxGreen.opacity(0.5))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)

            // Explanation
            if let conjugatedForm = conjugatedForm(from: rows) {
                Text("\"\(conjugatedForm)\" is a conjugated form of \"\(lemma)\"")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }

            Divider().padding(.horizontal, 24)

            Text("Present tense")
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                let allParts = row.components(separatedBy: " ")
                let verbParts = allParts.filter { !$0.hasPrefix("(") }
                let reflexive = allParts.first(where: { $0.hasPrefix("(") })
                let pronoun = verbParts.dropLast().joined(separator: " ")
                let form = verbParts.last ?? row
                HStack(spacing: 4) {
                    Text(pronoun)
                        .foregroundColor(.secondary)
                        .frame(width: 110, alignment: .leading)
                    Text(form)
                        .fontWeight(.semibold)
                        .foregroundColor(.luxGreen)
                    if let r = reflexive {
                        Text(r)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .font(.body)
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
            }

            Spacer()
        }
    }

    private func conjugatedForm(from rows: [String]) -> String? {
        guard rows.count > 2 else { return nil }
        let form = verbFormOnly(rows[2])
        return form.lowercased() == lemma.lowercased() ? nil : form
    }
}

// MARK: - Highlighted Text Component (used in Reading exercise)
struct HighlightedText: View {
    let text: String
    let highlight: String

    var body: some View {
        let parts = text.split(separator: " ", omittingEmptySubsequences: false)
        let highlightLower = highlight.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,?!:;\"() "))

        return parts.reduce(Text("")) { result, part in
            let partClean = part.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,?!:;\"() "))
            let isHighlight = partClean == highlightLower

            return result + Text(part + " ")
                .foregroundColor(isHighlight ? .luxGreen : .primary)
                .fontWeight(isHighlight ? .bold : .regular)
        }
    }
}

// MARK: - Matching Exercise
struct MatchingExerciseView: View {
    let pairs: [MatchingItemModel]
    let onComplete: () -> Void
    var onWrongMatch: (() -> Void)? = nil

    @State private var selectedLU: String? = nil   // pair id selected on left
    @State private var selectedEN: String? = nil   // pair id selected on right
    @State private var matchedPairIds: Set<String> = []
    @State private var wrongPairIds: Set<String> = []
    @State private var shakeOffset: CGFloat = 0
    @State private var luOrder: [String] = []      // shuffled pair ids for LU column
    @State private var enOrder: [String] = []      // shuffled pair ids for EN column

    var body: some View {
        VStack(spacing: 8) {
            // Column headers
            HStack {
                Text("Lëtzebuergesch")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Text("English")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }

            HStack(alignment: .top, spacing: 12) {
                // LU column (left)
                VStack(spacing: 8) {
                    ForEach(luOrder, id: \.self) { pairId in
                        if let pair = pairs.first(where: { $0.id == pairId }),
                           !matchedPairIds.contains(pairId) {
                            matchCard(
                                text: pair.nativeText,
                                isSelected: selectedLU == pairId,
                                isWrong: wrongPairIds.contains(pairId + "_LU")
                            ) { handleTap(pairId: pairId, side: .lu) }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // EN column (right)
                VStack(spacing: 8) {
                    ForEach(enOrder, id: \.self) { pairId in
                        if let pair = pairs.first(where: { $0.id == pairId }),
                           !matchedPairIds.contains(pairId) {
                            matchCard(
                                text: pair.translatedText,
                                isSelected: selectedEN == pairId,
                                isWrong: wrongPairIds.contains(pairId + "_EN")
                            ) { handleTap(pairId: pairId, side: .en) }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.luxSpring, value: matchedPairIds)
        .animation(.luxSpring, value: wrongPairIds)
        .onChange(of: matchedPairIds) { _, newValue in
            if newValue.count == pairs.count && !pairs.isEmpty {
                onComplete()
            }
        }
        .onAppear {
            if luOrder.isEmpty {
                let ids = pairs.map { $0.id }
                luOrder = ids.shuffled()
                enOrder = ids.shuffled()
            }
        }
    }

    @ViewBuilder
    private func matchCard(text: String, isSelected: Bool, isWrong: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    isWrong    ? Color.luxRed.opacity(0.8)
                    : isSelected ? Color.luxGreen
                    : Color(.systemGray6)
                )
                .foregroundColor(isWrong || isSelected ? .white : .primary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .offset(x: isWrong ? shakeOffset : 0)
        .transition(.scale.combined(with: .opacity))
    }

    private enum Side { case lu, en }

    private func handleTap(pairId: String, side: Side) {
        switch side {
        case .lu:
            selectedLU = (selectedLU == pairId) ? nil : pairId
        case .en:
            selectedEN = (selectedEN == pairId) ? nil : pairId
        }

        guard let luId = selectedLU, let enId = selectedEN else { return }

        if luId == enId {
            withAnimation(.luxSpring) { matchedPairIds.insert(luId) }
            selectedLU = nil
            selectedEN = nil
        } else {
            onWrongMatch?()
            wrongPairIds = [luId + "_LU", enId + "_EN"]
            withAnimation(.easeInOut(duration: 0.08).repeatCount(4, autoreverses: true)) {
                shakeOffset = 8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.luxQuick) {
                    shakeOffset = 0
                    wrongPairIds = []
                }
                selectedLU = nil
                selectedEN = nil
            }
        }
    }
}

// MARK: - Jumbled Word Row
struct JumbledWordRow: View {
    let availableTokens: [String]
    let selectedTokens: [String]
    let onTokenSelected: (String) -> Void
    let onTokenRemoved: (String) -> Void

    // Track stable display order so tokens don't re-sort on each render
    @State private var displayOrder: [String] = []

    var body: some View {
        VStack(spacing: 16) {
            // Selected tokens area (Collection Zone)
            FlowLayout(spacing: 8) {
                if selectedTokens.isEmpty {
                    Text("Tap words to build the sentence")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(Array(selectedTokens.enumerated()), id: \.offset) { _, token in
                        Button {
                            onTokenRemoved(token)
                        } label: {
                            Text(token)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.luxGreen)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.luxGreen.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6]))
            )
            .animation(.luxSpring, value: selectedTokens)

            // Separator
            HStack(spacing: 8) {
                Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                Text("available words").font(.caption2).foregroundColor(.secondary)
                Rectangle().fill(Color(.systemGray4)).frame(height: 1)
            }
            .padding(.horizontal, 8)

            // Available tokens (Token Pool) — preserve shuffled order
            FlowLayout(spacing: 8) {
                let selectedCounts = Dictionary(grouping: selectedTokens, by: { $0 }).mapValues { $0.count }
                let availableCounts = Dictionary(grouping: availableTokens, by: { $0 }).mapValues { $0.count }

                ForEach(displayOrder.indices, id: \.self) { index in
                    let token = displayOrder[index]
                    let usedCount = selectedCounts[token] ?? 0
                    let totalCount = availableCounts[token] ?? 0

                    if usedCount < totalCount {
                        Button {
                            onTokenSelected(token)
                        } label: {
                            Text(token)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Ghost placeholder to preserve layout
                        Text(token)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .foregroundColor(.clear)
                            .background(Color(.systemGray5).opacity(0.3))
                            .cornerRadius(10)
                    }
                }
            }
            .animation(.luxSpring, value: selectedTokens)
        }
        .onAppear {
            // Capture initial shuffled order once
            if displayOrder.isEmpty {
                displayOrder = availableTokens
            }
        }
        .onChange(of: availableTokens) { _, newTokens in
            displayOrder = newTokens
        }
    }
}

// MARK: - Flow Layout (replaces ExperimentalLayoutApi FlowRow)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0
        var rowMaxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowMaxHeight + spacing
                rowMaxHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            rowMaxHeight = max(rowMaxHeight, size.height)
            currentX += size.width + spacing
            maxHeight = max(maxHeight, currentY + rowMaxHeight)
        }

        return (CGSize(width: maxWidth, height: maxHeight), positions)
    }
}

// MARK: - Lesson Progress Bar
struct LessonProgressBar: View {
    let progress: Float

    // Gradient spans the full track width; the fill clips to show only the earned portion.
    // Blue → Amber → Green mirrors the three lesson phases so colour shifts naturally as you advance.
    private static let fillGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.28, green: 0.52, blue: 1.00), location: 0.00),
            .init(color: .luxAmber,                                  location: 0.45),
            .init(color: .luxGreen,                                  location: 1.00),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    private var glowColor: Color {
        if progress < 0.3 { return Color(red: 0.28, green: 0.52, blue: 1.00) }
        if progress < 0.7 { return .luxAmber }
        return .luxGreen
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))

                Capsule()
                    .fill(Self.fillGradient)
                    .frame(width: max(16, geo.size.width * CGFloat(min(1, max(0, progress)))))
                    .shadow(color: glowColor.opacity(0.45), radius: 5, y: 2)
            }
        }
        .frame(height: 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: progress)
    }
}
