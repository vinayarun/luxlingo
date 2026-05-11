import SwiftUI

// MARK: - Exercise Screen (port of ExerciseScreen.kt)
struct ExerciseScreen: View {
    @Bindable var viewModel: ExerciseViewModel
    let onBack: () -> Void
    @State private var showReadingConjugation = false
    @State private var showGrammarGuide = false
    @State private var grammarGuideSection = GrammarGuideSection.conjugation

    // MARK: Character detection
    private static let characterMap: [(name: String, asset: String)] = [
        ("Marc",   "character_marc"),
        ("Anna",   "character_anna"),
        ("Lena",   "character_lena"),
        ("Paul",   "character_paul"),
        ("Bello",  "character_bello"),
        ("Claire", "character_claire"),
        ("Weiss",  "character_mr_weiss"),
    ]

    private static let maxCharacterAvatars = 3

    private var characterAvatarAssets: [String] {
        guard let text = viewModel.uiState.currentSentence?.textEn, !text.isEmpty else { return [] }
        let found = Self.characterMap.compactMap { name, asset -> (String, Int)? in
            guard let range = text.range(of: "\\b\(name)\\b", options: .regularExpression) else { return nil }
            return (asset, text.distance(from: text.startIndex, to: range.lowerBound))
        }
        return found.sorted { $0.1 < $1.1 }.prefix(Self.maxCharacterAvatars).map { $0.0 }
    }

    @State private var showCelebration = false

    var body: some View {
        Group {
            if showCelebration {
                CelebrationView {
                    showCelebration = false
                }
            } else if viewModel.uiState.isLessonFinished {
                LessonSummaryScreen(
                    masteredSenses: viewModel.uiState.masteredSenses,
                    sessionXP: viewModel.uiState.sessionXP,
                    onBackToMenu: onBack
                )
            } else {
                exerciseContent
            }
        }
        .onChange(of: viewModel.uiState.isLessonFinished) {
            if viewModel.uiState.isLessonFinished && !showCelebration {
                showCelebration = true
            }
        }
    }

    @ViewBuilder
    private var exerciseContent: some View {
        VStack(spacing: 0) {
            if viewModel.uiState.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        ExerciseHeader(
                            progress: viewModel.uiState.progress,
                            progressText: viewModel.uiState.currentExerciseType == .matching
                                ? "Match the pairs"
                                : "Mastery \(viewModel.uiState.currentMastery) / \(viewModel.uiState.maxMastery)",
                            phase: viewModel.uiState.phase,
                            sessionXP: viewModel.uiState.sessionXP,
                            masteryChange: viewModel.uiState.masteryChange,
                            isFeedbackVisible: viewModel.uiState.isFeedbackVisible
                        )

                        Spacer().frame(height: 32)

                        // Prompt Text
                        if viewModel.uiState.currentExerciseType != .matching {
                            VStack(spacing: 8) {
                                // Only show prompt if it's explicitly set and not just a fallback to textEn
                                if !viewModel.uiState.promptText.isEmpty {
                                    Text(viewModel.uiState.promptText)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                
                                if !viewModel.uiState.promptSubtitle.isEmpty {
                                    HStack(spacing: 6) {
                                        if viewModel.uiState.currentExerciseType == .zipfSpeedRun {
                                            Image(systemName: "bolt.fill")
                                                .foregroundColor(.luxAmber)
                                        } else if viewModel.uiState.currentExerciseType == .nRuleHunter {
                                            Image(systemName: "scope")
                                                .foregroundColor(.luxPurple)
                                        }
                                        
                                        Text(viewModel.uiState.promptSubtitle)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .bold()
                                    }
                                    .multilineTextAlignment(.center)
                                }
                            }
                        }

                        Spacer().frame(height: 8)

                        // Character avatars — shown for all named characters in the sentence
                        let exerciseType = viewModel.uiState.currentExerciseType
                        let avatars = characterAvatarAssets
                        if !avatars.isEmpty,
                           exerciseType != .matching,
                           exerciseType != .zipfSpeedRun {
                            HStack(spacing: 16) {
                                ForEach(avatars, id: \.self) { asset in
                                    CharacterAvatarView(assetName: asset)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                            .id("avatars_\(avatars.joined())")
                            .animation(.luxSpring, value: avatars.joined())
                        }

                        // Paradigm-mismatch hint — shown for all exercise types when the sentence
                        // uses a conjugated form of the lemma (e.g. "ass" when teaching "sinn")
                        let sentForm  = viewModel.uiState.targetWord
                        let lemmaForm = viewModel.uiState.displayedTargetWord
                        let exerciseTypeForHint = viewModel.uiState.currentExerciseType
                        if viewModel.uiState.paradigm != nil,
                           !sentForm.isEmpty, !lemmaForm.isEmpty,
                           sentForm.lowercased() != lemmaForm.lowercased(),
                           exerciseTypeForHint != .matching,
                           exerciseTypeForHint != .zipfSpeedRun,
                           exerciseTypeForHint != .reading,   // reading already shows the conjugation chip
                           exerciseTypeForHint != .flashcard {
                            HStack(spacing: 5) {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                Text("'\(sentForm)' is a conjugated form of '\(lemmaForm)'")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 2)
                        }

                        // Dynamic Exercise Content
                        exerciseBody
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity
                            ))
                            .id(viewModel.uiState.currentSentenceIndex)
                            .animation(.luxSpring, value: viewModel.uiState.currentSentenceIndex)

                    }
                    .padding(16)
                    .padding(.bottom, 100) // Space for the banner
                }

                Spacer()

                // Feedback Banner
                if viewModel.uiState.isFeedbackVisible {
                    feedbackBanner
                } else {
                    // Skip button
                    if viewModel.uiState.failureCount >= 3 {
                        let isMatching = viewModel.uiState.currentExerciseType == .matching
                        Button(isMatching ? "Skip" : "Skip / Reveal Answer") {
                            viewModel.onSkipExercise()
                        }
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    }

                    // Main action button
                    if viewModel.uiState.currentExerciseType != .zipfSpeedRun && viewModel.uiState.currentExerciseType != .matching {
                        Button(action: {
                            if viewModel.uiState.currentExerciseType == .reading {
                                viewModel.onReadingContinue()
                            } else if viewModel.uiState.currentExerciseType == .flashcard {
                                AudioFeedbackService.shared.playCorrect()
                                viewModel.onFlashcardContinue()
                            } else {
                                viewModel.checkAnswer()
                            }
                        }) {
                            Text(buttonLabel)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isCheckEnabled ? Color.luxGreen : Color(.systemGray4))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(!isCheckEnabled)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .animation(.luxSpring, value: viewModel.uiState.isFeedbackVisible)
        .onChange(of: viewModel.uiState.isFeedbackVisible) {
            guard viewModel.uiState.isFeedbackVisible else { return }
            switch viewModel.uiState.feedback {
            case .correct, .typo, .nRule:
                if viewModel.uiState.currentExerciseType == .reading {
                    AudioFeedbackService.shared.playReading()
                } else {
                    AudioFeedbackService.shared.playCorrect()
                }
            case .wrong:
                AudioFeedbackService.shared.playWrong()
            default:
                break
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
            }
        }
    }

    private var isCheckEnabled: Bool {
        if viewModel.uiState.isFeedbackVisible { return true }
        if viewModel.uiState.currentExerciseType == .reading { return true }
        if viewModel.uiState.currentExerciseType == .flashcard { return true }
        
        switch viewModel.uiState.currentExerciseType {
        case .nRuleHunter:
            return true  // always active — submitting blank (no n) is a valid answer
        case .jumbledLu, .jumbledEn:
            // Only enable check for jumbled if at least one token is selected
            return !viewModel.uiState.userInput.isEmpty && viewModel.uiState.feedback == .none
        default:
            return !viewModel.uiState.userInput.isEmpty && viewModel.uiState.feedback == .none
        }
    }

    private var buttonLabel: String {
        if viewModel.uiState.isFeedbackVisible { return "Continue" }
        switch viewModel.uiState.currentExerciseType {
        case .reading: return "Continue"
        case .flashcard: return "Got it!"
        default: return "Check"
        }
    }

    // MARK: - Exercise Body

    @ViewBuilder
    private var exerciseBody: some View {
        switch viewModel.uiState.currentExerciseType {
        case .flashcard:
            FlashcardExercise(
                targetWord: viewModel.uiState.displayedTargetWord,
                translation: viewModel.uiState.targetTranslation,
                exampleSentenceLu: viewModel.uiState.exampleSentenceLu,
                exampleSentenceEn: viewModel.uiState.exampleSentenceEn,
                sentenceTargetWord: viewModel.uiState.targetWord,
                paradigm: viewModel.uiState.paradigm,
                lodAudioUrl: viewModel.uiState.targetLodAudioUrl,
                nRuleForm: viewModel.uiState.nRuleFormInSentence
            )

        case .reading:
            VStack(spacing: 16) {
                // Word info strip
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        SpeakerButton(
                            text: viewModel.uiState.displayedTargetWord,
                            audioUrl: viewModel.uiState.targetLodAudioUrl
                        )
                        .frame(width: 34, height: 34)
                        .background(Color.luxGreen.opacity(0.08))
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.uiState.displayedTargetWord)
                                .font(.title3).fontWeight(.bold)
                                .foregroundColor(.luxGreen)
                            Text(viewModel.uiState.targetTranslation)
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    if viewModel.uiState.paradigm != nil || viewModel.uiState.nRuleFormInSentence != nil {
                        HStack(spacing: 8) {
                            if viewModel.uiState.paradigm != nil {
                                Button { showReadingConjugation = true } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.triangle.branch").font(.caption2)
                                        // Show the actual form used in this sentence, not just the
                                        // first non-lemma paradigm row (e.g. "sinn → ass" not "sinn → bass")
                                        let sentForm = viewModel.uiState.targetWord
                                        let lemma    = viewModel.uiState.displayedTargetWord
                                        let chipLabel = sentForm.lowercased() != lemma.lowercased()
                                            ? "\(lemma) → \(sentForm)"
                                            : "Conjugations"
                                        Text(chipLabel)
                                            .font(.caption).fontWeight(.semibold)
                                        Image(systemName: "chevron.right").font(.caption2)
                                    }
                                    .foregroundColor(.luxAmber)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color.luxAmber.opacity(0.12))
                                    .cornerRadius(8)
                                }.buttonStyle(.plain)
                            }
                            if let nForm = viewModel.uiState.nRuleFormInSentence {
                                Button {
                                    grammarGuideSection = .nRule
                                    showGrammarGuide = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "n.circle").font(.caption2)
                                        Text("\(viewModel.uiState.displayedTargetWord) → \(nForm)")
                                            .font(.caption).fontWeight(.semibold)
                                        Text("n-rule").font(.caption2).foregroundColor(.secondary)
                                        Image(systemName: "chevron.right").font(.caption2)
                                    }
                                    .foregroundColor(.luxPurple)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color.luxPurple.opacity(0.10))
                                    .cornerRadius(8)
                                }.buttonStyle(.plain)
                            }
                            // Contraction hint: shown when sentence uses a shortened form of the lemma
                            // that isn't a conjugation or n-rule (e.g. "a" = "an" before consonants)
                            let sentenceForm = viewModel.uiState.targetWord.lowercased()
                            let lemmaForm   = viewModel.uiState.displayedTargetWord.lowercased()
                            if sentenceForm != lemmaForm,
                               viewModel.uiState.paradigm == nil,
                               viewModel.uiState.nRuleFormInSentence == nil {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle").font(.caption2)
                                    Text("'\(viewModel.uiState.targetWord)' is how '\(viewModel.uiState.displayedTargetWord)' appears before consonants")
                                        .font(.caption).fontWeight(.semibold)
                                }
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.10))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color.luxGreen.opacity(0.06))
                .cornerRadius(12)
                .sheet(isPresented: $showReadingConjugation) {
                    if let p = viewModel.uiState.paradigm {
                        ConjugationPanel(
                            lemma: viewModel.uiState.displayedTargetWord,
                            translation: viewModel.uiState.targetTranslation,
                            rows: p
                        )
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                    }
                }
                .sheet(isPresented: $showGrammarGuide) {
                    NavigationView {
                        LanguageGuideScreen(scrollTo: grammarGuideSection)
                            .navigationTitle("Grammar Tips")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Back to Lesson") { showGrammarGuide = false }
                                        .fontWeight(.semibold)
                                }
                            }
                    }
                }

                TappableLuSentenceView(
                    text: viewModel.uiState.currentSentence?.textLu ?? "",
                    highlight: viewModel.uiState.targetWord,
                    highlightMeaning: viewModel.uiState.targetTranslation
                )
                .font(.title)

                SpeakerButton(text: viewModel.uiState.currentSentence?.textLu ?? "")
                    .font(.title3)
            }

        case .jumbledLu, .jumbledEn:
            JumbledWordRow(
                availableTokens: viewModel.uiState.shuffledTokens,
                selectedTokens: viewModel.uiState.userInput.split(separator: " ").map(String.init).filter { !$0.isEmpty },
                onTokenSelected: { token in
                    let current = viewModel.uiState.userInput.split(separator: " ").map(String.init).filter { !$0.isEmpty }
                    viewModel.onInputChanged((current + [token]).joined(separator: " "))
                },
                onTokenRemoved: { token in
                    var current = viewModel.uiState.userInput.split(separator: " ").map(String.init)
                    if let idx = current.firstIndex(of: token) { current.remove(at: idx) }
                    viewModel.onInputChanged(current.joined(separator: " "))
                }
            )

        case .multipleChoice:
            VStack(spacing: 12) {
                // Sentence card — visually distinct from options
                Text(viewModel.uiState.sentenceWithBlank)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                Spacer().frame(height: 8)

                ForEach(viewModel.uiState.multipleChoiceOptions, id: \.self) { option in
                    let isSelected = viewModel.uiState.selectedOption == option
                    let isCorrect = viewModel.uiState.correctOption == option
                    let showFeedback = viewModel.uiState.isFeedbackVisible
                    // Only reveal correct/wrong colors when we're also revealing the answer (2nd+ failure or correct)
                    let revealColors = showFeedback && (viewModel.uiState.failureCount >= 2 || !isWrongAnswer)

                    Button {
                        if !showFeedback {
                            viewModel.onInputChanged(option)
                            viewModel.uiState.selectedOption = option
                        }
                    } label: {
                        HStack {
                            Text(option)
                                .font(.headline)
                            Spacer()
                            if revealColors && isCorrect {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            } else if revealColors && isSelected && !isCorrect {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
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
                    .animation(.luxQuick, value: isSelected)
                }
            }

        case .conjugationMatch:
            ConjugationMatchExercise(
                sentence: viewModel.uiState.currentSentence?.textLu ?? "",
                highlightedForm: viewModel.uiState.targetWord,
                options: viewModel.uiState.conjugationOptions,
                selectedOption: viewModel.uiState.selectedOption,
                correctOption: viewModel.uiState.correctOption,
                isFeedbackVisible: viewModel.uiState.isFeedbackVisible,
                isWrongAnswer: isWrongAnswer,
                failureCount: viewModel.uiState.failureCount,
                onSelect: { option in
                    viewModel.onInputChanged(option)
                    viewModel.uiState.selectedOption = option
                }
            )

        case .paradigmPicker:
            ParadigmPickerExercise(
                lemma: viewModel.uiState.displayedTargetWord,
                translation: viewModel.uiState.targetTranslation,
                pronoun: viewModel.uiState.paradigmPromptPronoun,
                options: viewModel.uiState.paradigmPickerOptions,
                paradigmRows: viewModel.uiState.paradigm ?? [],
                selectedOption: viewModel.uiState.selectedOption,
                correctOption: viewModel.uiState.paradigmCorrectForm,
                isFeedbackVisible: viewModel.uiState.isFeedbackVisible,
                isWrongAnswer: isWrongAnswer,
                failureCount: viewModel.uiState.failureCount,
                onSelect: { option in
                    viewModel.onInputChanged(option)
                    viewModel.uiState.selectedOption = option
                }
            )

        case .matching:
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Match the pairs")
                        .font(.title2).fontWeight(.bold)
                    Text("Tap a word, then tap its translation")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                MatchingExerciseView(
                    pairs: viewModel.uiState.matchingPairs,
                    onComplete: {
                        AudioFeedbackService.shared.playMatchingComplete()
                        viewModel.onInputChanged("DONE")
                        viewModel.checkAnswer()
                    },
                    onWrongMatch: {
                        viewModel.onMatchingWrongPair()
                    }
                )
            }

        case .cloze:
            ClozeSentenceInput(
                parts: viewModel.uiState.sentenceParts,
                userInput: Binding(
                    get: { viewModel.uiState.userInput },
                    set: { viewModel.onInputChanged($0) }
                ),
                feedback: viewModel.uiState.feedback,
                onDone: { viewModel.checkAnswer() }
            )
            
        case .nRuleHunter:
            VStack(spacing: 16) {
                NRuleHunterView(
                    sentence: viewModel.uiState.currentSentence?.textLu ?? "",
                    targetWordIndex: viewModel.uiState.nRuleWordIndex,
                    currentSelection: Binding(
                        get: { viewModel.uiState.nRuleSelection },
                        set: { viewModel.onNRuleToggle(to: $0) }
                    ),
                    showHint: viewModel.uiState.showNRuleHint,
                    onToggle: { viewModel.onNRuleToggle(to: $0) }
                )
                
                if !viewModel.uiState.showNRuleHint && !viewModel.uiState.isFeedbackVisible {
                    Button(action: { viewModel.onShowNRuleHint() }) {
                        Label("Need a hint?", systemImage: "lightbulb")
                            .font(.subheadline)
                            .foregroundColor(.luxAmber)
                            .padding(.vertical, 8)
                    }
                }
            }
            
        case .zipfSpeedRun:
            if viewModel.uiState.speedRunCountdown > 0 {
                SpeedRunCountdownView(
                    count: viewModel.uiState.speedRunCountdown,
                    isRapidFire: viewModel.uiState.isRapidFire
                )
            } else {
                ZipfsSpeedRunView(
                    word: viewModel.uiState.targetWord,
                    translation: viewModel.uiState.targetTranslation,
                    isCorrect: viewModel.uiState.isSpeedRunProposedCorrect,
                    timeRemaining: viewModel.uiState.timeRemaining,
                    onSwipe: { viewModel.onSpeedRunSwipe(correct: $0) }
                )
            }
        }
    }

    private var isWrongAnswer: Bool {
        viewModel.uiState.feedback == .wrong
    }
    
    private var correctAnswerText: String {
        guard let sentence = viewModel.uiState.currentSentence else { return viewModel.uiState.targetWord }
        switch viewModel.uiState.currentExerciseType {
        case .jumbledLu:
            return sentence.textLu
        case .jumbledEn:
            return sentence.textEn
        case .conjugationMatch:
            return viewModel.uiState.displayedTargetWord
        case .paradigmPicker:
            return viewModel.uiState.paradigmCorrectForm
        default:
            let words = sentence.textLu.split(separator: " ").map(String.init)
            let safeIdx = min(max(sentence.clozeIndex, 0), words.count - 1)
            return safeIdx < words.count ? words[safeIdx] : viewModel.uiState.targetWord
        }
    }

    private var feedbackBanner: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isWrongAnswer ? "Not quite!" : "Great job!")
                        .font(.title2)
                        .fontWeight(.bold)

                    if isWrongAnswer {
                        if viewModel.uiState.failureCount >= 2 {
                            Text("Correct answer: \(correctAnswerText)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        } else {
                            Text("Try again!")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Text(FeedbackColors.message(for: viewModel.uiState.feedback))
                            .font(.subheadline)
                    }
                    
                    // Show EN translation for context — but not for jumbled/matching/speedrun exercises
                    let exerciseType = viewModel.uiState.currentExerciseType
                    let isJumbled = exerciseType == .jumbledEn || exerciseType == .jumbledLu
                    if let sentence = viewModel.uiState.currentSentence,
                       exerciseType != .matching, exerciseType != .zipfSpeedRun, !isJumbled {
                        Text(sentence.textEn)
                            .font(.caption)
                            .opacity(0.85)
                            .padding(.top, 2)
                    }
                }
                Spacer()
                Image(systemName: isWrongAnswer ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 44))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .foregroundColor(.white)

            Button(action: {
                viewModel.onContinueAfterFeedback()
            }) {
                let label = isWrongAnswer && viewModel.uiState.failureCount < 2 ? "Try again" : "Continue"
                Text(label)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .foregroundColor(isWrongAnswer ? .luxRed : .luxGreen)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(isWrongAnswer ? Color.luxRed : Color.luxGreen)
        .cornerRadius(32, corners: [.topLeft, .topRight])
        .shadow(radius: 10)
        .transition(.move(edge: .bottom))
    }
}

// MARK: - Exercise Header
struct ExerciseHeader: View {
    let progress: Float
    let progressText: String
    let phase: String        // retained for call-site compatibility; communicated visually by gradient colour
    let sessionXP: Int
    let masteryChange: Int
    let isFeedbackVisible: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 0) {
                Text(progressText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if masteryChange != 0 && isFeedbackVisible {
                    Text(masteryChange > 0 ? "  +\(masteryChange)" : "  \(masteryChange)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(masteryChange > 0 ? .luxGreen : .red)
                }

                Spacer(minLength: 8)

                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.luxAmber)
                    Text("\(sessionXP)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.luxAmber.opacity(0.12))
                .cornerRadius(20)
            }

            LessonProgressBar(progress: progress)
        }
    }
}

// MARK: - Cloze Sentence Input
struct ClozeSentenceInput: View {
    let parts: [String]
    @Binding var userInput: String
    let feedback: AnswerFeedback
    let onDone: () -> Void

    private var feedbackColor: Color {
        FeedbackColors.text(for: feedback)
    }

    var body: some View {
        HStack(alignment: .center) {
            if let before = parts.first, !before.isEmpty {
                Text(before + " ")
                    .font(.title3)
            }

            VStack(spacing: 2) {
                TextField("type here", text: $userInput)
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 80)
                    .fixedSize(horizontal: true, vertical: false)
                    .onSubmit { onDone() }
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)

                Rectangle()
                    .fill(feedbackColor)
                    .frame(height: 3)
                    .animation(.luxQuick, value: feedback)
            }
            .frame(minWidth: 50)

            if parts.count > 1, !parts[1].isEmpty {
                Text(" " + parts[1])
                    .font(.title3)
            }
        }
    }
}

// MARK: - Helpers for UI Shapes
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Character Avatar

private struct CharacterAvatarView: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(.systemGray5), lineWidth: 1))
            .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
    }
}

// MARK: - Celebration (confetti burst before lesson summary)

private struct ConfettiParticle {
    let startX: CGFloat      // 0–1 fraction of screen width
    let delay: Double        // seconds before this particle starts
    let speed: Double        // pixels/sec base speed
    let rotSpeed: Double     // radians/sec
    let startRot: Double     // initial rotation (radians)
    let swayFreq: Double     // horizontal sway frequency
    let swayPhase: Double    // horizontal sway phase offset
    let w: CGFloat           // width
    let h: CGFloat           // height
    let color: Color
}

struct CelebrationView: View {
    let onComplete: () -> Void

    @State private var particles: [ConfettiParticle] = []
    @State private var startDate: Date = .now
    @State private var iconScale: CGFloat = 0.01
    @State private var textOpacity: Double = 0

    private let palette: [Color] = [
        .luxGreen, .luxAmber,
        Color(red: 0.28, green: 0.52, blue: 1.0),
        .orange, .pink, .purple,
        Color(red: 1.0, green: 0.2, blue: 0.3), .cyan,
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).opacity(0.93).ignoresSafeArea()

            // Confetti
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                    let elapsed = tl.date.timeIntervalSince(startDate)
                    Canvas { ctx, size in
                        for p in particles {
                            let t = max(0, elapsed - p.delay)
                            let x = p.startX * size.width
                                  + CGFloat(sin(t * p.swayFreq + p.swayPhase) * 20)
                            let y = -50 + CGFloat(t * p.speed + 0.5 * 200 * t * t)
                            guard y < size.height + 60 else { continue }
                            let rot = p.startRot + t * p.rotSpeed
                            // Fade out in the bottom 30% of the screen
                            let fade = max(0, min(1, 1 - (y - size.height * 0.7) / (size.height * 0.3)))
                            var rect = Path(CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h))
                            ctx.fill(
                                rect.applying(
                                    CGAffineTransform(rotationAngle: rot)
                                        .concatenating(CGAffineTransform(translationX: x, y: y))
                                ),
                                with: .color(p.color.opacity(fade))
                            )
                        }
                    }
                }
                .ignoresSafeArea()
            }

            // Central "well done" message
            VStack(spacing: 14) {
                Text("🎉")
                    .font(.system(size: 86))
                    .scaleEffect(iconScale)
                    .animation(.spring(response: 0.5, dampingFraction: 0.52), value: iconScale)

                Text("Lesson Complete!")
                    .font(.title2).fontWeight(.bold)
                    .opacity(textOpacity)
                    .animation(.easeIn(duration: 0.25).delay(0.15), value: textOpacity)
            }
        }
        .onAppear {
            startDate = .now
            particles = (0..<75).map { _ in
                ConfettiParticle(
                    startX:    CGFloat.random(in: 0.02...0.98),
                    delay:     Double.random(in: 0...0.45),
                    speed:     Double.random(in: 130...300),
                    rotSpeed:  Double.random(in: -5...5),
                    startRot:  Double.random(in: 0...(2 * .pi)),
                    swayFreq:  Double.random(in: 1.0...3.5),
                    swayPhase: Double.random(in: 0...(2 * .pi)),
                    w:         CGFloat.random(in: 6...14),
                    h:         CGFloat.random(in: 9...20),
                    color:     palette.randomElement()!
                )
            }
            iconScale   = 1
            textOpacity = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { onComplete() }
        }
    }
}
