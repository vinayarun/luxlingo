import SwiftUI
import AVFoundation

// MARK: - Shared MCQ button helper

struct MCQOptionButton: View {
    let option: String
    let isSelected: Bool
    let isCorrect: Bool
    let showFeedback: Bool
    let revealColors: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(option).font(.headline)
                Spacer()
                if revealColors && isCorrect {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
                } else if revealColors && isSelected && !isCorrect {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                revealColors
                    ? (isCorrect ? Color.luxGreen : (isSelected ? Color.luxRed : Color(.systemGray6)))
                    : (isSelected ? Color.luxGreen.opacity(0.15) : Color(.systemGray6))
            )
            .foregroundColor(revealColors && (isCorrect || isSelected) ? .white : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected && !showFeedback ? Color.luxGreen : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(showFeedback)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Shared audio prompt button
// Used by both Listening Comprehension and Audio Dictation.
// Auto-plays TTS when the word changes. If introVisible is true (lesson Ken Burns
// overlay is still running) it waits 2.7 s before playing so audio doesn't clash.

private struct AudioPromptButton: View {
    let word:         String
    let audioUrl:     String?
    let introVisible: Bool      // captured by value at task-start time

    // Tracks last word we played so re-renders don't re-trigger unnecessarily
    @State private var lastPlayedWord = ""

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 96, height: 96)
                SpeakerButton(text: word, audioUrl: audioUrl)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            Text("Tap to replay")
                .font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .task(id: word) {
            guard word != lastPlayedWord else { return }
            lastPlayedWord = word
            // If the lesson intro overlay is still animating, wait past it
            if introVisible {
                try? await Task.sleep(nanoseconds: 2_700_000_000)
            }
            if let url = audioUrl {
                await TTSService.shared.speakUrl(url, identifier: word)
            } else {
                await TTSService.shared.speak(word)
            }
        }
    }
}

// MARK: - Listening Comprehension Exercise
// The LU word is spoken automatically on load. LU text is never shown — purely auditory.

struct ListeningComprehensionExercise: View {
    let word:          String   // LU word to speak (lemma)
    let audioUrl:      String?  // LOD pronunciation URL if available
    let introVisible:  Bool     // true while lesson Ken Burns overlay is playing
    let options:       [String] // 3 EN translations (correct + 2 distractors)
    let selectedOption:  String?
    let correctOption:   String?
    let isFeedbackVisible: Bool
    let isWrongAnswer:     Bool
    let failureCount:      Int
    let onSelect:    (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            AudioPromptButton(word: word, audioUrl: audioUrl, introVisible: introVisible)
            Text("What does this word mean?")
                .font(.subheadline).foregroundColor(.secondary)
            ForEach(options, id: \.self) { option in
                let isSelected   = selectedOption == option
                let isCorrect    = correctOption  == option
                let revealColors = isFeedbackVisible && (failureCount >= 2 || !isWrongAnswer)
                MCQOptionButton(
                    option: option, isSelected: isSelected, isCorrect: isCorrect,
                    showFeedback: isFeedbackVisible, revealColors: revealColors,
                    onTap: { if !isFeedbackVisible { onSelect(option) } }
                )
            }
        }
    }
}

// MARK: - UIKit-backed text field for Audio Dictation
// SwiftUI @FocusState is unreliable inside animated view transitions on device.
// UITextField.becomeFirstResponder() is guaranteed to show the keyboard.

private struct DictationTextField: UIViewRepresentable {
    @Binding var text: String
    let borderColor: UIColor
    let isDisabled:  Bool

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder         = "Type here…"
        tf.textAlignment       = .center
        tf.autocapitalizationType = .none
        tf.autocorrectionType  = .no
        tf.spellCheckingType   = .no
        tf.smartDashesType     = .no
        tf.smartQuotesType     = .no
        tf.returnKeyType       = .done
        tf.font                = UIFont.systemFont(ofSize: 24, weight: .semibold)
        tf.borderStyle         = .none
        tf.backgroundColor     = .clear
        tf.delegate            = context.coordinator
        tf.addTarget(context.coordinator,
                     action: #selector(Coordinator.textChanged(_:)),
                     for: .editingChanged)
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        if tf.text != text { tf.text = text }
        tf.isEnabled           = !isDisabled
        tf.layer.borderColor   = borderColor.cgColor

        if !isDisabled {
            DispatchQueue.main.async {
                if !tf.isFirstResponder { tf.becomeFirstResponder() }
            }
        } else {
            if tf.isFirstResponder { tf.resignFirstResponder() }
        }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }

        @objc func textChanged(_ tf: UITextField) { text = tf.text ?? "" }
        func textFieldShouldReturn(_ tf: UITextField) -> Bool { true }
    }
}

// MARK: - Audio Dictation Exercise
// Hear the word, write it in Luxembourgish. No LU text shown.
// Levenshtein ≤ 2 is accepted as a typo and flagged; > 2 is wrong.

struct AudioDictationExercise: View {
    let word:         String
    let audioUrl:     String?
    let introVisible: Bool
    let userInput:    Binding<String>
    let feedback:     AnswerFeedback

    var body: some View {
        VStack(spacing: 20) {
            AudioPromptButton(word: word, audioUrl: audioUrl, introVisible: introVisible)

            Text("Write the word you hear in Luxembourgish")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // UIKit-backed field — guaranteed keyboard on device
            DictationTextField(
                text:        userInput,
                borderColor: uiBorderColor,
                isDisabled:  feedback != .none
            )
            .frame(height: 56)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(swiftBorderColor, lineWidth: 2)
            )

            // Spelling-error hint shown immediately on typo feedback
            if feedback == .typo {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.luxAmber)
                    Text("Close — the correct spelling is shown in the feedback.")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var swiftBorderColor: Color {
        switch feedback {
        case .correct: return .luxGreen
        case .typo:    return .luxAmber
        case .wrong:   return Color(UIColor.systemRed)
        default:       return .clear
        }
    }

    private var uiBorderColor: UIColor {
        switch feedback {
        case .correct: return UIColor(Color.luxGreen)
        case .typo:    return UIColor(Color.luxAmber)
        case .wrong:   return .systemRed
        default:       return .clear
        }
    }
}

// MARK: - Conjugation Match Exercise

struct ConjugationMatchExercise: View {
    let sentence: String
    let highlightedForm: String
    let options: [String]
    let selectedOption: String?
    let correctOption: String?
    let isFeedbackVisible: Bool
    let isWrongAnswer: Bool
    let failureCount: Int
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Sentence shown once, with the verb underlined
            VStack(spacing: 6) {
                Text("Which verb is this a form of?")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(.secondary)
                UnderlinedVerbSentenceText(sentence: sentence, highlight: highlightedForm)
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }

            ForEach(options, id: \.self) { option in
                let isSelected = selectedOption == option
                let isCorrect  = correctOption == option
                let revealColors = isFeedbackVisible && (failureCount >= 2 || !isWrongAnswer)
                MCQOptionButton(
                    option: option,
                    isSelected: isSelected,
                    isCorrect: isCorrect,
                    showFeedback: isFeedbackVisible,
                    revealColors: revealColors,
                    onTap: { if !isFeedbackVisible { onSelect(option) } }
                )
            }
        }
    }
}

// Sentence text where the target verb is bold + underlined (not just coloured)
private struct UnderlinedVerbSentenceText: View {
    let sentence: String
    let highlight: String

    var body: some View {
        let words = sentence.split(separator: " ").map(String.init)
        var result = AttributedString()
        for (i, word) in words.enumerated() {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            var part = AttributedString(word)
            if clean.lowercased() == highlight.lowercased() {
                part.foregroundColor = .primary
                part.font = .systemFont(ofSize: 17, weight: .bold)
                part.underlineStyle = .single
            }
            result += part
            if i < words.count - 1 { result += AttributedString(" ") }
        }
        return Text(result).font(.title3)
    }
}

// MARK: - Sentence with one word highlighted in accent colour

private struct HighlightedSentenceText: View {
    let sentence: String
    let highlight: String

    var body: some View {
        let words = sentence.split(separator: " ").map(String.init)
        var result = AttributedString()
        for (i, word) in words.enumerated() {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            var part = AttributedString(word)
            if clean.lowercased() == highlight.lowercased() {
                part.foregroundColor = UIColor(named: "AccentColor").map { Color($0) } ?? .accentColor
                part.font = .systemFont(ofSize: 17, weight: .bold)
            }
            result += part
            if i < words.count - 1 { result += AttributedString(" ") }
        }
        return Text(result).font(.title3)
    }
}

// MARK: - Paradigm Picker Exercise

struct ParadigmPickerExercise: View {
    let lemma: String
    let translation: String
    let pronoun: String
    let options: [String]
    let paradigmRows: [String]
    let selectedOption: String?
    let correctOption: String
    let isFeedbackVisible: Bool
    let isWrongAnswer: Bool
    let failureCount: Int
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Verb identity card
            VStack(spacing: 4) {
                Text(lemma)
                    .font(.largeTitle).fontWeight(.bold)
                Text(translation)
                    .font(.subheadline).foregroundColor(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Conjugation table (all rows, blank the target pronoun row)
            if !paradigmRows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(paradigmRows.enumerated()), id: \.offset) { idx, row in
                        let parts = row.split(separator: " ", maxSplits: 1)
                        let rowPronoun = String(parts.first ?? Substring(row))
                        let isTarget   = rowPronoun == pronoun
                        HStack {
                            Text(rowPronoun)
                                .font(.subheadline).foregroundColor(.secondary)
                                .frame(width: 90, alignment: .leading)
                            if isTarget {
                                Text("___")
                                    .font(.subheadline).fontWeight(.bold)
                                    .foregroundColor(.accentColor)
                            } else {
                                let form = parts.count > 1
                                    ? String(parts[1])
                                        .components(separatedBy: " ")
                                        .filter { !$0.hasPrefix("(") }
                                        .joined(separator: " ")
                                    : ""
                                Text(form)
                                    .font(.subheadline).fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(isTarget ? Color.accentColor.opacity(0.08) : Color.clear)
                        if idx < paradigmRows.count - 1 { Divider().padding(.leading, 12) }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            Text("Pick the correct form for '\(pronoun)'")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Option buttons
            ForEach(options, id: \.self) { option in
                let isSelected = selectedOption == option
                let isCorrect  = correctOption == option
                let revealColors = isFeedbackVisible && (failureCount >= 2 || !isWrongAnswer)
                MCQOptionButton(
                    option: option,
                    isSelected: isSelected,
                    isCorrect: isCorrect,
                    showFeedback: isFeedbackVisible,
                    revealColors: revealColors,
                    onTap: { if !isFeedbackVisible { onSelect(option) } }
                )
            }
        }
    }
}

/// Strips parenthetical reflexive pronouns (e.g. "(mech)") and returns the verb form.
/// "ech hunn (mech)" → "hunn",  "hien/si/et huet (sech)" → "huet"
private func verbFormOnly(_ row: String) -> String {
    let parts = row.components(separatedBy: " ").filter { !$0.hasPrefix("(") }
    return parts.last ?? row
}

/// Converts a Luxembourgish word to its vocab image asset name.
/// Matches the normalization in prepare_vocab_images.py exactly.
/// e.g. "Hond" → "vocab_hond", "Zëmmer" → "vocab_zemmer", "Stär" → "vocab_star"
func vocabAssetName(for word: String) -> String {
    let charMap: [Character: String] = [
        "ë": "e", "ä": "a", "ü": "u", "ö": "o",
        "é": "e", "è": "e", "à": "a", "â": "a",
        "ê": "e", "î": "i", "ô": "o", "û": "u",
        "ù": "u", "ÿ": "y", "æ": "ae", "œ": "oe",
    ]
    var result = ""
    for ch in word.lowercased() {
        if let mapped = charMap[ch] {
            result += mapped
        } else if ch.isLetter || ch.isNumber {
            result.append(ch)
        } else {
            result += "_"
        }
    }
    // Collapse repeated underscores and strip edges
    while result.contains("__") { result = result.replacingOccurrences(of: "__", with: "_") }
    result = result.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    return "vocab_" + result
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

    private var vocabImage: UIImage? { UIImage(named: vocabAssetName(for: targetWord)) }
    private var hasImage: Bool { vocabImage != nil }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {

                if let img = vocabImage {
                    // ── Image-first layout ───────────────────────────────────
                    VStack(spacing: 12) {
                        // Illustration
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .background(Color.white)
                            .cornerRadius(18)
                            .shadow(color: .black.opacity(0.10), radius: 8, y: 4)

                        // Word centred; speaker floats at trailing edge without shifting the word
                        Text(targetWord)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.luxGreen)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .overlay(alignment: .trailing) {
                                SpeakerButton(text: targetWord, audioUrl: lodAudioUrl)
                                    .font(.title3)
                                    .frame(width: 32, height: 32)
                                    .background(Color.luxGreen.opacity(0.08))
                                    .clipShape(Circle())
                            }

                        Text(translation)
                            .font(.title3).fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // ── Text-first layout (no image) ─────────────────────────
                    // Word centred on full width; speaker floats at the trailing edge
                    Text(targetWord)
                        .font(.system(size: targetWord.count > 10 ? 34 : 46, weight: .bold))
                        .foregroundColor(.luxGreen)
                        .shadow(color: .luxGreen.opacity(0.15), radius: 6, y: 3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .overlay(alignment: .trailing) {
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
                }

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
                ConjugationPanel(lemma: targetWord, translation: translation, rows: p,
                                 sentenceForm: sentenceTargetWord)
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
    var sentenceForm: String? = nil  // actual form used in the sentence, for the description line

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
        // Prefer the actual sentence form if provided
        if let sf = sentenceForm, !sf.isEmpty, sf.lowercased() != lemma.lowercased() {
            return sf
        }
        // Fallback: find the first row whose verb form differs from the lemma
        for row in rows {
            let form = verbFormOnly(row)
            if !form.isEmpty && form.lowercased() != lemma.lowercased() {
                return form
            }
        }
        return nil
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

// MARK: - Article Choice Exercise

struct ArticleChoiceExercise: View {
    let sentence: String          // "Ech gesinn ___ Mann."
    let sentenceEn: String
    let options: [String]         // exactly 4
    let selectedOption: String?
    let correctOption: String
    let isFeedbackVisible: Bool
    let isWrongAnswer: Bool
    let failureCount: Int
    let ruleHint: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Prompt
            VStack(spacing: 6) {
                Text("Choose the correct article")
                    .font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                // Render sentence with ___ shown as a green underlined blank
                articleSentenceView
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                Text(sentenceEn)
                    .font(.caption).foregroundColor(.secondary).italic()
            }

            // 2x2 grid of article options
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(options, id: \.self) { opt in
                    let isSelected  = selectedOption == opt
                    let isCorrect   = correctOption.lowercased() == opt.lowercased()
                    let revealColors = isFeedbackVisible && (failureCount >= 2 || !isWrongAnswer)
                    MCQOptionButton(
                        option: opt,
                        isSelected: isSelected,
                        isCorrect: isCorrect,
                        showFeedback: isFeedbackVisible,
                        revealColors: revealColors,
                        onTap: { if !isFeedbackVisible { onSelect(opt) } }
                    )
                }
            }

            // Rule hint shown after correct answer
            if isFeedbackVisible && !isWrongAnswer {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill").foregroundColor(.luxAmber)
                    Text(ruleHint).font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var articleSentenceView: some View {
        let parts = sentence.components(separatedBy: "___")
        if parts.count == 2 {
            return (Text(parts[0]).font(.title3)
                    + Text("___").font(.title3).fontWeight(.bold).foregroundColor(.accentColor).underline()
                    + Text(parts[1]).font(.title3))
        } else {
            return Text(sentence).font(.title3)
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

// MARK: - Lesson Progress Dots
struct LessonProgressBar: View {
    let progress: Float
    private static let totalDots = 10

    private var filledCount: Int {
        min(Self.totalDots, Int(progress * Float(Self.totalDots)))
    }

    // Fractional fill of the dot currently being worked on (0.0–1.0)
    private var activeFraction: Double {
        let raw = Double(progress) * Double(Self.totalDots)
        return raw - Double(Int(raw))
    }

    private var phaseColor: Color {
        if progress < 0.30 { return Color(red: 0.28, green: 0.52, blue: 1.0) }
        if progress < 0.70 { return .luxAmber }
        return .luxGreen
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.totalDots, id: \.self) { i in
                DotView(
                    state: dotState(for: i),
                    color: phaseColor
                )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: progress)
    }

    private enum DotState { case filled, active(Double), empty }

    private func dotState(for i: Int) -> DotState {
        if i < filledCount { return .filled }
        if i == filledCount && filledCount < Self.totalDots { return .active(activeFraction) }
        return .empty
    }

    private struct DotView: View {
        let state: DotState
        let color: Color

        var body: some View {
            ZStack {
                Circle().fill(Color(.systemGray5))
                Circle()
                    .fill(color)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
            .frame(width: 9, height: 9)
        }

        private var scale: Double {
            switch state {
            case .filled:          return 1.0
            case .active(let f):   return 0.35 + 0.65 * f
            case .empty:           return 0.0
            }
        }

        private var opacity: Double {
            switch state {
            case .filled:        return 1.0
            case .active(let f): return 0.3 + 0.7 * f
            case .empty:         return 0.0
            }
        }
    }
}

// MARK: - Pronunciation Practice Exercise

struct PronunciationExercise: View {
    let targetWord:    String
    let translation:   String
    let lodAudioUrl:   String?
    let isForSentence: Bool     // true = 12s limit, false = 5s limit
    let onSkip:        () -> Void
    let onSubmit:      (URL) -> Void

    @State private var phase: Phase = .listen
    @State private var recordingURL: URL? = nil
    @State private var playbackPlayer: AVAudioPlayer? = nil
    @State private var isPlayingBack = false

    private let service = PronunciationService.shared

    enum Phase { case listen, recording, review }

    private var maxDuration: Double { isForSentence ? 12 : 5 }

    var body: some View {
        VStack(spacing: 24) {

            // ── Instruction ──────────────────────────────────────────────────
            Text(phase == .review ? "Listen to yourself" : "Say this aloud in Luxembourgish")
                .font(.subheadline).fontWeight(.semibold).foregroundColor(.secondary)

            // ── Word card ────────────────────────────────────────────────────
            VStack(spacing: 8) {
                Text(targetWord)
                    .font(.system(size: targetWord.count > 10 ? 32 : 44, weight: .bold))
                    .foregroundColor(.luxGreen)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(translation)
                    .font(.title3).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color.luxGreen.opacity(0.06))
            .cornerRadius(16)

            // ── TTS reference (single speaker button, no duplicate icon) ─────
            Button {
                Task {
                    if let url = lodAudioUrl {
                        await TTSService.shared.speakUrl(url, identifier: targetWord)
                    } else {
                        await TTSService.shared.speak(targetWord)
                    }
                }
            } label: {
                let ttsActive = TTSService.shared.playState != .idle
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundColor(ttsActive ? .white : .secondary)
                    Text(ttsActive ? "Playing reference…" : "Hear reference")
                        .font(.caption)
                        .foregroundColor(ttsActive ? .white.opacity(0.9) : .secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(ttsActive ? Color.accentColor : Color(.systemGray6))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(TTSService.shared.playState != .idle || phase == .recording)

            // ── Amplitude bars ───────────────────────────────────────────────
            AmplitudeBarsView(levels: service.amplitudeLevels,
                              isActive: service.isRecording)
                .frame(height: 48)
                .opacity(phase == .recording ? 1 : 0.2)

            // ── Record button + countdown ring ───────────────────────────────
            ZStack {
                if phase == .recording {
                    Circle()
                        .trim(from: 0, to: CGFloat(1 - service.timeElapsed / maxDuration))
                        .stroke(Color.luxRed, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 80, height: 80)
                        .animation(.linear(duration: 1/16), value: service.timeElapsed)
                }

                Button {
                    handleRecordTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(phase == .recording ? Color.luxRed : Color.luxGreen)
                            .frame(width: 68, height: 68)
                        Image(systemName: phase == .recording ? "stop.fill" : "mic.fill")
                            .font(.title2).foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(phase == .review || TTSService.shared.playState != .idle)
                .opacity(phase == .review ? 0.35 : 1)
            }
            .frame(height: 90)

            // Hint when TTS is blocking the mic
            if TTSService.shared.playState != .idle && phase == .listen {
                Text("Wait for reference to finish…")
                    .font(.caption2).foregroundColor(.secondary)
            }

            // ── Review controls (Redo + Playback only — Check button is the standard bottom bar) ──
            if phase == .review, let url = recordingURL {
                VStack(spacing: 10) {
                    Text("Recording ready — tap Check below to submit")
                        .font(.caption).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        // Redo
                        Button {
                            service.recordingURL = nil   // clear so Check button disables
                            phase = .listen; recordingURL = nil
                        } label: {
                            Label("Redo", systemImage: "arrow.counterclockwise")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)

                        // Play back your recording
                        Button {
                            playBack(url: url)
                        } label: {
                            Label(isPlayingBack ? "Playing…" : "Play back",
                                  systemImage: isPlayingBack ? "pause.fill" : "play.fill")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPlayingBack)
                    }
                }
            }

            Spacer(minLength: 0)

            // ── Skip ─────────────────────────────────────────────────────────
            Button(action: onSkip) {
                Text("Skip pronunciation")
                    .font(.footnote).foregroundColor(.secondary)
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        // When the timer auto-stops, advance to review phase
        .onChange(of: service.autoStopFired) {
            guard service.autoStopFired, phase == .recording else { return }
            service.autoStopFired = false
            if let url = service.recordingURL {
                recordingURL = url
                phase = .review
            } else {
                phase = .listen
            }
        }
        // Stop recording if user navigates away
        .onDisappear {
            if service.isRecording { service.stopRecording() }
        }
    }

    // MARK: - Actions

    private func handleRecordTap() {
        switch phase {
        case .listen:
            phase = .recording
            Task {
                let ok = await service.startRecording(maxDuration: maxDuration)
                if !ok { phase = .listen }   // permission denied
            }
        case .recording:
            if let url = service.stopRecording() {
                recordingURL = url
                phase = .review
            } else {
                phase = .listen
            }
        case .review:
            break
        }
    }

    private func playBack(url: URL) {
        guard !isPlayingBack else { return }
        isPlayingBack = true
        Task {
            let player = try? AVAudioPlayer(contentsOf: url)
            playbackPlayer = player
            player?.play()
            // Wait for it to finish
            let duration = player?.duration ?? 2
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000) + 200_000_000)
            isPlayingBack = false
        }
    }
}

// MARK: - Amplitude bars

struct AmplitudeBarsView: View {
    let levels: [Float]
    let isActive: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? Color.luxGreen : Color(.systemGray4))
                    .frame(width: 4, height: max(4, CGFloat(level) * 44))
                    .animation(.easeOut(duration: 0.06), value: level)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pronunciation result card (shown between exercises)

struct PronunciationResultCard: View {
    let result: PronunciationResult
    let onDismiss: () -> Void

    var scoreColor: Color {
        switch result.score {
        case 80...: return .luxGreen
        case 50..<80: return .luxAmber
        default:     return .luxRed
        }
    }

    var scoreLabel: String {
        switch result.score {
        case 80...: return "Excellent!"
        case 50..<80: return "Good effort"
        default:     return "Keep practising"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(scoreColor)
                    Text("Pronunciation result")
                        .font(.headline)
                }

                // Score ring
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.15), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(result.score) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(result.score)%")
                            .font(.title.bold())
                            .foregroundColor(scoreColor)
                        Text(scoreLabel)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 110, height: 110)

                // What was heard
                VStack(spacing: 4) {
                    Text("You said")
                        .font(.caption).foregroundColor(.secondary)
                    Text(result.transcription.isEmpty ? "(nothing detected)" : result.transcription)
                        .font(.body.italic())
                        .foregroundColor(result.transcription.isEmpty ? .secondary : .primary)
                    Text("Target: \(result.targetWord)")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
            .padding(.horizontal, 24)

            Button(action: onDismiss) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(scoreColor)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4).ignoresSafeArea())
    }
}
