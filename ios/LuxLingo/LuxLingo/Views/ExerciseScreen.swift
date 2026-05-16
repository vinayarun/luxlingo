import SwiftUI

// MARK: - Exercise Screen (port of ExerciseScreen.kt)
struct ExerciseScreen: View {
    @Bindable var viewModel: ExerciseViewModel
    var introVisible: Bool = false   // true while the lesson Ken Burns overlay is playing
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
    @State private var showingPronunciationResult = false
    @State private var showScoringBanner = false
    @State private var showingFeedback = false
    private let pronService = PronunciationService.shared

    var body: some View {
        Group {
            if showCelebration {
                CelebrationView {
                    showCelebration = false
                }
            } else if viewModel.uiState.isLessonFinished {
                LessonSummaryScreen(
                    masteredSenses:  viewModel.uiState.masteredSenses,
                    sessionXP:       viewModel.uiState.sessionXP,
                    lessonNumber:    viewModel.uiState.lessonNumber,
                    isReviewSession: viewModel.uiState.isReviewSession,
                    onBackToMenu:    onBack
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
        contentBody
            .sheet(isPresented: $showingFeedback) {
                FeedbackSheet(
                    lessonId:     viewModel.uiState.lessonNumber > 0
                                  ? "lesson_\(viewModel.uiState.lessonNumber)" : "review",
                    exerciseType: viewModel.uiState.currentExerciseType.rawValue,
                    sentenceLu:   viewModel.uiState.currentSentence?.textLu ?? "",
                    targetWord:   viewModel.uiState.displayedTargetWord
                )
                .presentationDetents([.medium, .large])
            }
            .overlay {
                if showingPronunciationResult,
                   let result = viewModel.uiState.pendingPronunciationResult {
                    PronunciationResultCard(result: result) {
                        showingPronunciationResult = false
                        viewModel.uiState.pendingPronunciationResult = nil
                        viewModel.onContinueAfterFeedback()
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showingPronunciationResult)
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
    }

    @ViewBuilder
    private var contentBody: some View {
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
                            isFeedbackVisible: viewModel.uiState.isFeedbackVisible,
                            onFeedback: { showingFeedback = true }
                        )

                        Spacer().frame(height: 32)

                        // Prompt Text — hidden for pronunciation (that view manages its own header)
                        let isPronunciation = viewModel.uiState.currentExerciseType == .pronunciationPractice
                        if viewModel.uiState.currentExerciseType != .matching && !isPronunciation {
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

                        // Character avatars or vocab image thumbnail
                        let exerciseType = viewModel.uiState.currentExerciseType
                        let avatars = characterAvatarAssets
                        let vocabImg = (exerciseType == .flashcard || exerciseType == .reading)
                            ? UIImage(named: vocabAssetName(for: viewModel.uiState.displayedTargetWord))
                            : nil
                        if let img = vocabImg, exerciseType == .reading {
                            // Reading exercise: show small vocab image thumbnail instead of avatar
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 90)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                        } else if !avatars.isEmpty,
                           vocabImg == nil,
                           exerciseType != .matching,
                           exerciseType != .zipfSpeedRun,
                           exerciseType != .listeningComprehension,
                           exerciseType != .audioDictation {
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

                        // Mismatch hint — sentence uses a different form/synonym of the taught word
                        // (e.g. "ass" for "sinn", or "Buedzëmmer" for "Bad")
                        let sentForm  = viewModel.uiState.targetWord
                        let lemmaForm = viewModel.uiState.displayedTargetWord
                        let exerciseTypeForHint = viewModel.uiState.currentExerciseType
                        if !sentForm.isEmpty, !lemmaForm.isEmpty,
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

                        // "Checking pronunciation" banner — fades out after 4s
                        if showScoringBanner {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform.badge.clock")
                                    .foregroundColor(.accentColor)
                                Text("Checking pronunciation in background…")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.08))
                            .cornerRadius(10)
                            .transition(.opacity)
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
                    // Skip button — audio dictation shows after 1 failure (keyboard issues
                    // on device could strand the user); all other types after 3 failures.
                    let skipThreshold = viewModel.uiState.currentExerciseType == .audioDictation ? 1 : 3
                    if viewModel.uiState.failureCount >= skipThreshold {
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
                            } else if viewModel.uiState.currentExerciseType == .pronunciationPractice,
                                      let url = pronService.recordingURL {
                                // Submit recording async, show immediate "submitted" feedback
                                pronService.submitForScoring(
                                    audioURL:   url,
                                    targetWord: viewModel.uiState.displayedTargetWord,
                                    senseId:    viewModel.uiState.lastSenseId
                                )
                                pronService.recordingURL = nil
                                showScoringBanner = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                    showScoringBanner = false
                                }
                                viewModel.onPronunciationSubmitted()
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
        // Pronunciation: only enable after a recording has been made
        if viewModel.uiState.currentExerciseType == .pronunciationPractice {
            return pronService.recordingURL != nil
        }
        switch viewModel.uiState.currentExerciseType {
        case .nRuleHunter:
            return true
        case .jumbledLu, .jumbledEn:
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
        case .pronunciationPractice: return pronService.recordingURL != nil ? "Check" : "Record first"
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

                    if (viewModel.uiState.paradigm != nil || viewModel.uiState.nRuleFormInSentence != nil),
                       viewModel.uiState.currentExerciseType != .listeningComprehension,
                       viewModel.uiState.currentExerciseType != .audioDictation {
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
                            rows: p,
                            sentenceForm: viewModel.uiState.targetWord
                        )
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                    }
                }

                // conjugationMatch shows its own sentence with the verb underlined — skip here
                if viewModel.uiState.currentExerciseType != .conjugationMatch {
                    TappableLuSentenceView(
                        text: viewModel.uiState.currentSentence?.textLu ?? "",
                        highlight: viewModel.uiState.targetWord,
                        highlightMeaning: viewModel.uiState.targetTranslation
                    )
                    .font(.title)

                    SpeakerButton(text: viewModel.uiState.currentSentence?.textLu ?? "")
                        .font(.title3)
                }
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

        case .audioDictation:
            AudioDictationExercise(
                word:         viewModel.uiState.displayedTargetWord,
                audioUrl:     viewModel.uiState.targetLodAudioUrl,
                introVisible: introVisible,
                userInput:    Binding(
                    get: { viewModel.uiState.userInput },
                    set: { viewModel.onInputChanged($0) }
                ),
                feedback:     viewModel.uiState.feedback
            )

        case .pronunciationPractice:
            // Submit is handled by the standard Check button in the bottom action bar.
            // Skip goes straight to next exercise without recording.
            PronunciationExercise(
                targetWord:    viewModel.uiState.displayedTargetWord,
                translation:   viewModel.uiState.targetTranslation,
                lodAudioUrl:   viewModel.uiState.targetLodAudioUrl,
                isForSentence: false,
                onSkip: { viewModel.loadNextExercise() },
                onSubmit: { _ in }   // unused — Check button handles submission
            )

        case .listeningComprehension:
            ListeningComprehensionExercise(
                word:              viewModel.uiState.displayedTargetWord,
                audioUrl:          viewModel.uiState.targetLodAudioUrl,
                introVisible:      introVisible,
                options:           viewModel.uiState.multipleChoiceOptions,
                selectedOption:    viewModel.uiState.selectedOption,
                correctOption:     viewModel.uiState.correctOption,
                isFeedbackVisible: viewModel.uiState.isFeedbackVisible,
                isWrongAnswer:     isWrongAnswer,
                failureCount:      viewModel.uiState.failureCount,
                onSelect: { option in
                    viewModel.onInputChanged(option)
                    viewModel.uiState.selectedOption = option
                }
            )

        case .conjugationMatch:
            VStack(spacing: 12) {
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
                grammarTipsLink
            }

        case .paradigmPicker:
            VStack(spacing: 12) {
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
                grammarTipsLink
            }

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

        case .articleChoice:
            ArticleChoiceExercise(
                sentence:          viewModel.uiState.articleSentence,
                sentenceEn:        viewModel.uiState.articleSentenceEn,
                options:           viewModel.uiState.articleOptions,
                selectedOption:    viewModel.uiState.selectedMCQOption,
                correctOption:     viewModel.uiState.correctArticle,
                isFeedbackVisible: viewModel.uiState.isFeedbackVisible,
                isWrongAnswer:     isWrongAnswer,
                failureCount:      viewModel.uiState.failureCount,
                ruleHint:          viewModel.uiState.articleRuleHint,
                onSelect:          { viewModel.selectMCQOption($0) }
            )
        }
    }

    /// Small "Open Grammar Tips" link shown under conjugation exercises
    private var grammarTipsLink: some View {
        Button {
            grammarGuideSection = .conjugation
            showGrammarGuide    = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "book.pages")
                Text("Open conjugation guide")
            }
            .font(.caption)
            .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
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
        case .listeningComprehension:
            return viewModel.uiState.targetTranslation
        case .audioDictation:
            return viewModel.uiState.displayedTargetWord
        case .articleChoice:
            return viewModel.uiState.correctArticle
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
                    let isPronunciation = viewModel.uiState.currentExerciseType == .pronunciationPractice
                    Text(isPronunciation ? "Recording submitted!" : (isWrongAnswer ? "Not quite!" : "Great job!"))
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
                    } else if viewModel.uiState.currentExerciseType == .pronunciationPractice {
                        Text("Result coming shortly — continue your lesson.")
                            .font(.subheadline)
                    } else if viewModel.uiState.feedback == .typo
                               && viewModel.uiState.currentExerciseType == .audioDictation {
                        Text("Close! Correct spelling: \(correctAnswerText)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text(FeedbackColors.message(for: viewModel.uiState.feedback))
                            .font(.subheadline)
                    }
                    
                    // Show EN translation only for exercises where sentence context adds value
                    let exerciseType = viewModel.uiState.currentExerciseType
                    let sentenceContextTypes: Set<ExerciseTypeNew> = [.cloze, .multipleChoice, .reading, .nRuleHunter]
                    if sentenceContextTypes.contains(exerciseType),
                       let sentence = viewModel.uiState.currentSentence {
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
                let isRetry = isWrongAnswer && viewModel.uiState.failureCount < 2
                if !isRetry, let result = pronService.newResultAvailable {
                    // Show pronunciation result before advancing
                    pronService.newResultAvailable = nil
                    showingPronunciationResult = true
                    // Store it temporarily so the overlay can display it
                    viewModel.uiState.pendingPronunciationResult = result
                } else {
                    viewModel.onContinueAfterFeedback()
                }
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
    let phase: String
    let sessionXP: Int
    let masteryChange: Int
    let isFeedbackVisible: Bool
    var onFeedback: (() -> Void)? = nil

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

                if let onFeedback {
                    Button(action: onFeedback) {
                        Image(systemName: "exclamationmark.bubble")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 6)
                }
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

    private var feedbackColor: Color { FeedbackColors.text(for: feedback) }

    var body: some View {
        VStack(spacing: 14) {
            // Full sentence with blank — wraps naturally, no one-line constraint
            let before = parts.first ?? ""
            let after  = parts.count > 1 ? parts[1] : ""
            let blanked = (before.isEmpty ? "" : before + " ")
                        + "______"
                        + (after.isEmpty ? "" : " " + after)

            Text(blanked)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)

            // Input field sits below — clearly associated with the blank above
            VStack(spacing: 2) {
                TextField("type the missing word", text: $userInput)
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .onSubmit { onDone() }
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 24)

                Rectangle()
                    .fill(feedbackColor)
                    .frame(height: 3)
                    .padding(.horizontal, 24)
                    .animation(.luxQuick, value: feedback)
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

private enum ParticleShape { case rect, circle, star, ribbon }

private struct ConfettiParticle {
    let shape:     ParticleShape
    let originX:   CGFloat    // 0–1 fraction; burst from center or top
    let originY:   CGFloat    // 0–1 fraction
    let angle:     Double     // initial launch angle (radians from up)
    let burst:     Double     // outward burst speed (burst phase)
    let fall:      Double     // downward gravity speed after burst
    let delay:     Double
    let rotSpeed:  Double
    let startRot:  Double
    let swayFreq:  Double
    let swayAmp:   Double
    let swayPhase: Double
    let size:      CGFloat
    let color:     Color
}

struct CelebrationView: View {
    let onComplete: () -> Void

    @State private var particles: [ConfettiParticle] = []
    @State private var startDate: Date = .now
    @State private var badgeScale: CGFloat = 0.01
    @State private var badgeOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.01
    @State private var ringOpacity: Double = 0.8
    @State private var xpOpacity: Double = 0
    @State private var xpOffset: CGFloat = 20

    private let palette: [Color] = [
        .luxGreen, Color(red: 0.13, green: 0.83, blue: 0.56),
        .luxAmber, Color(red: 1.0, green: 0.75, blue: 0.0),
        Color(red: 0.28, green: 0.55, blue: 1.0),
        .pink, Color(red: 1.0, green: 0.3, blue: 0.5),
        .cyan, .purple, .orange,
    ]

    var body: some View {
        ZStack {
            // Deep background — dark to let particles pop
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.08, blue: 0.18),
                         Color(red: 0.06, green: 0.14, blue: 0.28)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Particles (Canvas for 60fps performance)
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 1.0/60.0)) { tl in
                    let t = tl.date.timeIntervalSince(startDate)
                    Canvas { ctx, size in
                        let cx = size.width  * 0.5
                        let cy = size.height * 0.38

                        for p in particles {
                            let pt = max(0, t - p.delay)
                            guard pt > 0 else { continue }

                            // Burst phase (0–0.4s): fly outward from origin
                            // Fall phase: gravity + sway
                            let burstPhase = min(pt, 0.4)
                            let fallPhase  = max(0, pt - 0.4)

                            let bx = CGFloat(sin(p.angle) * p.burst * burstPhase)
                            let by = CGFloat(-cos(p.angle) * p.burst * burstPhase)
                            let fx = CGFloat(sin(p.swayFreq * fallPhase + p.swayPhase) * p.swayAmp)
                            let fy = CGFloat(p.fall * fallPhase + 0.5 * 320 * fallPhase * fallPhase)

                            let x = cx + p.originX * size.width * 0.15 + bx + fx
                            let y = cy + p.originY * size.height * 0.08 + by + fy

                            guard y < size.height + 80 else { continue }

                            let fade = max(0.0, min(1.0,
                                1.0 - max(0, (y - size.height * 0.72) / (size.height * 0.28))))
                            let rot = p.startRot + pt * p.rotSpeed

                            ctx.opacity = fade
                            let tf = CGAffineTransform(translationX: x, y: y)
                                .rotated(by: rot)

                            switch p.shape {
                            case .rect:
                                let r = Path(CGRect(x: -p.size/2, y: -p.size*1.6/2,
                                                    width: p.size, height: p.size * 1.6))
                                ctx.fill(r.applying(tf), with: .color(p.color))
                            case .circle:
                                let c = Path(ellipseIn: CGRect(x: -p.size/2, y: -p.size/2,
                                                               width: p.size, height: p.size))
                                ctx.fill(c.applying(tf), with: .color(p.color))
                            case .star:
                                ctx.fill(starPath(size: p.size).applying(tf), with: .color(p.color))
                            case .ribbon:
                                // Thin long rectangle (ribbon)
                                let rib = Path(CGRect(x: -p.size*0.3/2, y: -p.size/2,
                                                      width: p.size*0.3, height: p.size))
                                ctx.fill(rib.applying(tf), with: .color(p.color))
                            }
                        }
                    }
                }
                .ignoresSafeArea()
            }

            // Badge + ring
            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    // Expanding ring
                    Circle()
                        .stroke(Color.luxGreen.opacity(0.4), lineWidth: 3)
                        .frame(width: 160, height: 160)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Checkmark badge
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [Color.luxGreen,
                                                        Color(red: 0.05, green: 0.65, blue: 0.35)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 110, height: 110)
                            .shadow(color: Color.luxGreen.opacity(0.5), radius: 24, y: 8)

                        Image(systemName: "checkmark")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(badgeScale)
                    .opacity(badgeOpacity)
                }

                Spacer().frame(height: 28)

                Text("Lesson Complete!")
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .opacity(badgeOpacity)

                Spacer().frame(height: 10)

                Text("Well done — keep it up!")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(xpOpacity)
                    .offset(y: xpOffset)

                Spacer()
            }
        }
        .onAppear {
            startDate = .now
            buildParticles()

            // Badge bounce in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.48)) {
                badgeScale   = 1.0
                badgeOpacity = 1.0
            }
            // Expanding ring pulse
            withAnimation(.easeOut(duration: 0.7)) {
                ringScale   = 1.6
                ringOpacity = 0
            }
            // Sub-text fades up
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                xpOpacity = 1
                xpOffset  = 0
            }
            // Auto-advance after 2.2s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { onComplete() }
        }
    }

    private func buildParticles() {
        let shapes: [ParticleShape] = [.rect, .rect, .circle, .star, .ribbon, .rect]
        particles = (0..<110).map { _ in
            // Mix: burst from center (60%) + rain from top (40%)
            let fromCenter = Double.random(in: 0...1) < 0.65
            return ConfettiParticle(
                shape:     shapes.randomElement()!,
                originX:   fromCenter ? CGFloat.random(in: -0.3...0.3) : CGFloat.random(in: -2.5...2.5),
                originY:   fromCenter ? CGFloat.random(in: -0.1...0.1) : CGFloat.random(in: -1.5 ... -0.2),
                angle:     fromCenter ? Double.random(in: -.pi ... .pi) : Double.random(in: -0.6...0.6),
                burst:     fromCenter ? Double.random(in: 280...600) : Double.random(in: 0...60),
                fall:      fromCenter ? Double.random(in: 60...180)  : Double.random(in: 100...260),
                delay:     Double.random(in: 0...0.55),
                rotSpeed:  Double.random(in: -8...8),
                startRot:  Double.random(in: 0...(2 * .pi)),
                swayFreq:  Double.random(in: 1.2...3.5),
                swayAmp:   Double.random(in: 8...24),
                swayPhase: Double.random(in: 0...(2 * .pi)),
                size:      CGFloat.random(in: 6...15),
                color:     palette.randomElement()!
            )
        }
    }

    private func starPath(size: CGFloat) -> Path {
        var path = Path()
        let r = size / 2, ri = r * 0.42, n = 5
        for i in 0..<(n * 2) {
            let a = Double(i) * .pi / Double(n) - .pi / 2
            let radius = i.isMultiple(of: 2) ? r : ri
            let pt = CGPoint(x: CGFloat(cos(a)) * radius, y: CGFloat(sin(a)) * radius)
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()
        return path
    }
}
