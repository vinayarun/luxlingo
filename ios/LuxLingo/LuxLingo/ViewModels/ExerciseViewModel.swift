import Foundation
import SwiftData

// MARK: - Exercise UI State
struct ExerciseUiState {
    var lessonTitle: String = ""
    var currentSentence: SentencesEntity? = nil
    var targetWord: String = ""
    var displayedTargetWord: String = ""
    var targetTranslation: String = ""
    var promptText: String = ""
    var sentenceParts: [String] = []
    var sentenceWithBlank: String = ""
    var multipleChoiceOptions: [String] = []
    var currentExerciseType: ExerciseTypeNew = .reading
    var userInput: String = ""
    var feedback: AnswerFeedback = .none
    var progress: Float = 0
    var totalSentences: Int = 0
    var currentSentenceIndex: Int = 0
    var isLessonFinished: Bool = false
    var masteredSenses: [String] = []
    var shuffledTokens: [String] = []
    var matchingPairs: [MatchingItemModel] = []
    var isLoading: Bool = false
    var recentSentenceIds: [String] = []
    var failureCount: Int = 0
    var consecutiveSenseCount: Int = 0
    var lastSenseId: String = ""
    var lastExerciseType: ExerciseTypeNew = .reading
    var exampleSentenceLu: String = ""
    var exampleSentenceEn: String = ""
    var phase: String = "Introduction"
    var sessionXP: Int = 0
    var currentMastery: Int = 0
    var maxMastery: Int = 0
    var isFeedbackVisible: Bool = false
    var selectedOption: String? = nil
    var correctOption: String? = nil
    var masteryChange: Int = 0
    var promptSubtitle: String = ""
    var isJumbledCorrectOrder: Bool = false
    
    // Summary screen data
    var lessonNumber:    Int  = 0          // parsed from lessonId, used by LessonSummaryScreen
    var isReviewSession: Bool = false      // true when in review mode — shows ReviewSummaryScreen

    // Conjugation panel
    var paradigm: [String]? = nil          // present tense rows, e.g. ["ech kann", ...]
    var sentenceClozeIndex: Int = 0        // word index in example sentence to highlight
    var targetLodAudioUrl: String? = nil   // lod.lu AAC URL for the target word
    var nRuleFormInSentence: String? = nil // e.g. "de" when targetWord is "den" (n-rule drop)

    // N-Rule fields
    var nRuleSelection: String = ""
    var nRuleWordIndex: Int = 0
    var showNRuleHint: Bool = false

    // Conjugation Match / Paradigm Picker fields
    var conjugationOptions: [String] = []
    var paradigmPromptPronoun: String = ""
    var paradigmCorrectForm: String = ""
    var paradigmPickerOptions: [String] = []
    
    // Speed Run fields
    var timeRemaining: Float = 1.0
    var isSpeedRunProposedCorrect: Bool = false
    var speedRunCountdown: Int = 0   // 3,2,1 before the card appears; 0 = live

    // Tap-bleed protection: set when a new exercise loads, cleared after 350ms
    var exerciseLoadedAt: Date = .distantPast

    // Rapid Fire (end-of-lesson burst)
    var isRapidFire: Bool = false
    var rapidFireQueue: [String] = []
    var rapidFireCorrect: Int = 0
    var rapidFireTotal: Int = 0

    // Article Choice fields
    var articleOptions: [String] = []
    var correctArticle: String = ""
    var articleRuleHint: String = ""
    var articleSentence: String = ""
    var articleSentenceEn: String = ""

    // Pronunciation result waiting to be shown between exercises
    var pendingPronunciationResult: PronunciationResult? = nil

    // MCQ selected option alias (used by ArticleChoiceExercise)
    var selectedMCQOption: String? { selectedOption }
    var isWrongAnswer: Bool { feedback == .wrong }
}

// MARK: - Exercise ViewModel (port of ExerciseViewModel.kt — ~426 lines)
@MainActor
@Observable
final class ExerciseViewModel {
    var uiState = ExerciseUiState()

    /// True for 350ms after each exercise loads — blocks tap bleed-through.
    var isInteractionReady: Bool {
        Date().timeIntervalSince(uiState.exerciseLoadedAt) > 0.35
    }

    private let lessonId: String
    private let repository: ContentRepository

    // MARK: - Review mode
    private var isReviewMode = false
    private var reviewItems: [(senseId: String, lessonId: String)] = []

    /// Normal lesson init.
    init(lessonId: String, repository: ContentRepository) {
        self.lessonId   = lessonId
        self.repository = repository
        uiState.lessonNumber = Int(lessonId.replacingOccurrences(of: "lesson_", with: "")) ?? 0
        repository.markLessonStarted(lessonId: lessonId)
        loadNextExercise()
    }

    /// Review-session init — sets mode flags BEFORE loadNextExercise() runs.
    private init(reviewRepository: ContentRepository,
                 items: [(senseId: String, lessonId: String)]) {
        self.lessonId     = "review_session"
        self.repository   = reviewRepository
        self.isReviewMode = true
        self.reviewItems  = items
        uiState.lessonTitle    = "Review"
        uiState.totalSentences = items.count
        uiState.progress       = 0
        uiState.isReviewSession = true
        loadNextExercise()      // now isReviewMode == true when this runs
    }

    /// Public factory — use this instead of init for review sessions.
    static func forReview(repository: ContentRepository) -> ExerciseViewModel {
        let items = repository.buildReviewQueue(limit: 10)
        return ExerciseViewModel(reviewRepository: repository, items: items)
    }

    /// The words queued for this review session — used by the intro preview screen.
    var reviewWordPreviews: [VocabWord] {
        guard isReviewMode else { return [] }
        return reviewItems.compactMap { item in
            guard let sense = repository.getSense(senseId: item.senseId),
                  let vocab = repository.getVocabularyById(id: sense.surfaceId) else { return nil }
            return VocabWord(
                senseId:     item.senseId,
                wordLu:      vocab.wordText,
                primaryEn:   sense.translations,
                exampleLu:   "",
                exampleEn:   "",
                mastery:     repository.getSenseMastery(senseId: item.senseId),
                lodAudioUrl: vocab.lodAudioUrl
            )
        }
        .sorted { $0.mastery < $1.mastery }  // weakest first in the intro word list
    }

    // MARK: - Load Next Exercise

    func loadNextExercise() {
        stopCountdown()
        stopSpeedRunTimer()

        if isReviewMode { loadNextReviewExercise(); return }

        // Rapid fire: serve from the pre-built queue
        if uiState.isRapidFire {
            if uiState.rapidFireQueue.isEmpty {
                uiState.isRapidFire = false
                finishLesson()
            } else {
                loadRapidFireExercise()
            }
            return
        }

        // All senses mastered → kick off the rapid fire round instead of going straight to summary
        if repository.areAllCoreSensesMastered(lessonId: lessonId) {
            let coreSenses = repository.getLessonCoreSenses(lessonId: lessonId)
            let queue = Array(coreSenses.map { $0.senseId }.shuffled().prefix(8))
            uiState.rapidFireQueue = queue
            uiState.rapidFireTotal = queue.count
            uiState.rapidFireCorrect = 0
            uiState.isRapidFire = true
            loadRapidFireExercise()
            return
        }

        uiState.isLoading = true
        uiState.failureCount = 0
        uiState.isFeedbackVisible = false
        uiState.userInput = ""
        uiState.selectedOption = nil
        uiState.correctOption = nil
        uiState.masteryChange = 0
        uiState.shuffledTokens = []
        uiState.matchingPairs = []
        uiState.promptSubtitle = ""
        uiState.articleOptions = []
        uiState.correctArticle = ""
        uiState.articleRuleHint = ""
        uiState.articleSentence = ""
        uiState.articleSentenceEn = ""

        let coreSenses = repository.getLessonCoreSenses(lessonId: lessonId)
        if coreSenses.isEmpty {
            finishLesson()
            return
        }

        // 1. Phase Detection
        let unintroducedSenses = coreSenses.filter { sense in
            repository.getSenseMastery(senseId: sense.senseId) < 1
        }
        let isIntroPhase = !unintroducedSenses.isEmpty

        // 2. Sense Selection
        let lastSenseId = uiState.lastSenseId
        let consecutiveCount = uiState.consecutiveSenseCount

        let targetSense: SensesEntity
        if isIntroPhase {
            // Introduce some variety in introduction phase (cycle through first 3 unintroduced)
            let queue = unintroducedSenses.prefix(3).shuffled()
            targetSense = queue.first ?? coreSenses.randomElement()!
        } else if consecutiveCount >= 3 {
            // Force a switch if we're hitting the same word too much
            let others = coreSenses.filter { $0.senseId != lastSenseId }
            let unmasteredOthers = others.filter { repository.getSenseMastery(senseId: $0.senseId) < 20 }
            targetSense = unmasteredOthers.randomElement() ?? others.min(by: { repository.getSenseMastery(senseId: $0.senseId) < repository.getSenseMastery(senseId: $1.senseId) }) ?? coreSenses.randomElement()!
        } else {
            // Priortize unmastered senses across the board
            let unmastered = coreSenses.filter { repository.getSenseMastery(senseId: $0.senseId) < 20 }
            targetSense = unmastered.randomElement() ?? coreSenses.randomElement()!
        }


        // 3. Fetch Sentence
        let recentIds = uiState.recentSentenceIds
        guard let sentence = repository.getSentenceForLesson(lessonId: lessonId, excludeSentenceIds: recentIds, targetSenseId: targetSense.senseId) else {
            if repository.areAllCoreSensesMastered(lessonId: lessonId) {
                finishLesson()
            } else {
                loadNextExercise()
            }
            return
        }

        let senseId = targetSense.senseId
        let mastery = repository.getSenseMastery(senseId: senseId)
        let senseData = repository.getSense(senseId: senseId)
        let translation = senseData?.translations ?? ""

        // Get canonical word text
        let vocab = repository.getVocabularyById(id: targetSense.surfaceId)
        let targetWord = vocab?.wordText ?? ""

        // 4. Determine Exercise Type based on mastery
        var type: ExerciseTypeNew
        switch mastery {
        case ..<1:   type = .flashcard
        case ..<6:   type = .reading
        case ..<10:  type = .multipleChoice
        case ..<15:  type = (Int.random(in: 0...1) == 0 && uiState.lastExerciseType != .matching) ? .matching : .jumbledEn
        case ..<20:  type = .jumbledLu
        default:     type = .cloze
        }
        
        // 4a. Check for innovative type overrides
        if mastery >= 8 && mastery <= 18 {
            if findNRuleCandidate(in: sentence.textLu) != nil {
                // 30% chance to give n-rule if possible
                if Float.random(in: 0...1) < 0.3 { type = .nRuleHunter }
            }
        }
        
        if mastery >= 12 && mastery <= 25 {
            // 20% chance for speed run in range
            if Float.random(in: 0...1) < 0.2 { type = .zipfSpeedRun }
        }

        // Listening Comprehension: hear the word, choose its English meaning (no LU text shown)
        if mastery >= 4 && mastery <= 15 {
            if Float.random(in: 0...1) < 0.22 { type = .listeningComprehension }
        }

        // Audio Dictation: hear the word, type it in Luxembourgish (harder — no text clues)
        if mastery >= 8 && mastery <= 22 {
            if Float.random(in: 0...1) < 0.18 { type = .audioDictation }
        }

        // Conjugation Match: when the sentence uses a conjugated form that differs from the lemma
        // and the sense has paradigm data — teaches irregular/suppletive verb recognition
        if mastery >= 8 && mastery <= 22, senseData?.paradigm != nil {
            let sentWords = sentence.textLu.split(separator: " ").map { String($0) }
            let cIdx = min(max(sentence.clozeIndex, 0), sentWords.count - 1)
            let sentForm = cIdx < sentWords.count
                ? sentWords[cIdx].lowercased().trimmingCharacters(in: .punctuationCharacters) : ""
            if !sentForm.isEmpty && sentForm != targetWord.lowercased() {
                if Float.random(in: 0...1) < 0.25 { type = .conjugationMatch }
            }
        }

        // Paradigm Picker: given the infinitive, choose the right form for a specific pronoun
        if mastery >= 12 && mastery <= 25, senseData?.paradigm != nil {
            if Float.random(in: 0...1) < 0.2 { type = .paradigmPicker }
        }

        // Article Choice: pick the correct Luxembourgish article for a noun sentence
        // Only for SUBST (noun) senses with mastery > 3
        let isNounSense = senseData?.tags.uppercased().hasPrefix("SUBST") ?? false
        if isNounSense && mastery > 3 {
            if Float.random(in: 0...1) < 0.15 {
                if repository.getArticleExercise(for: senseId) != nil {
                    type = .articleChoice
                }
            }
        }

        // Pronunciation Practice: once per lesson per word, mastery > 5, ~12% chance
        // Skipped in review mode and rapid-fire. The exercise handles its own skip/submit flow.
        if !isReviewMode && mastery > 5 && !isIntroPhase {
            if Float.random(in: 0...1) < 0.12 {
                let alreadyPractised = uiState.masteredSenses.contains(senseId + "_pron")
                if !alreadyPractised {
                    type = .pronunciationPractice
                }
            }
        }

        // 4b. Phase Detection (Update)
        let phaseName: String
        if isIntroPhase {
            phaseName = "Introduction"
        } else {
            switch type {
            case .flashcard, .reading: phaseName = "Introduction"
            case .multipleChoice, .matching, .articleChoice: phaseName = "Reinforcement"
            case .pronunciationPractice: phaseName = "Speaking"
            default: phaseName = "Challenge"
            }
        }

        // 5. Jumbled Tokens
        let tokens: [String]
        switch type {
        case .jumbledLu:
            var baseTokens = cleanAndShuffleTokens(sentence.textLu)
            if baseTokens.count < 5 {
                let distractors = repository.getRandomDistractorsLu(target: targetWord, count: 2)
                    .filter { word in
                        // Heuristic: Avoid common English words in LU distractor pool
                        !["is", "the", "a", "and", "in", "to", "for", "with", "on", "he", "she", "it", "we", "they"].contains(word.lowercased())
                    }
                baseTokens = (baseTokens + distractors).shuffled()
            }
            tokens = baseTokens
        case .jumbledEn:
            var baseTokens = cleanAndShuffleTokens(sentence.textEn)
            let sentenceWordsEn = Set(baseTokens.map { $0.lowercased() })
            let distractorsEn = repository.getRandomDistractorsEn(target: translation, count: 3)
                .filter { word in
                    let w = word.lowercased()
                    // Exclude words already in the sentence and common LB words leaked into EN pool
                    return !sentenceWordsEn.contains(w)
                        && !["an", "ech", "du", "hien", "si", "et", "mir", "dir", "fir", "mat"].contains(w)
                }
                .prefix(2)
            baseTokens = (baseTokens + distractorsEn).shuffled()
            tokens = baseTokens
        default:
            tokens = []
        }

        let prompt: String
        var subtitle = ""
        switch type {
        case .jumbledEn: 
            prompt = sentence.textLu
            subtitle = "Translate to English"
        case .jumbledLu: 
            prompt = sentence.textEn
            subtitle = "Translate to Luxembourgish"
        case .multipleChoice: 
            prompt = sentence.textEn
            subtitle = "Pick the correct word"
        case .cloze: 
            prompt = sentence.textEn
            subtitle = "Type the missing word"
        case .reading: 
            prompt = "" // Sentence is already shown in the body via HighlightedText
            subtitle = "Read this aloud"
        case .flashcard: 
            prompt = "" // Translation is already shown on the card
            subtitle = "New word!"
        case .nRuleHunter:
            prompt = ""
            subtitle = "Keep or Drop the 'n'?"
        case .zipfSpeedRun:
            prompt = ""
            subtitle = "Swift Recall!"
        case .matching:
            prompt = "Match the pairs"
            subtitle = "Tap corresponding words"
        case .conjugationMatch:
            prompt = sentence.textLu
            subtitle = "Which verb is this a form of?"
        case .paradigmPicker:
            prompt = targetWord
            subtitle = "Complete the conjugation"
        case .listeningComprehension:
            prompt = ""
            subtitle = "Listen and choose the meaning"
        case .audioDictation:
            prompt = ""
            subtitle = "Listen and write the word"
        case .articleChoice:
            prompt = "Choose the correct article"
            subtitle = ""
        default:
            prompt = sentence.textEn
            subtitle = ""
        }

        // Update History Buffer
        let newRecentIds = Array((recentIds + [sentence.sentenceId]).suffix(8))
        let nextIndex = uiState.currentSentenceIndex + 1

        // Progress calculation (cap each sense at 20 for progress)
        let currentM = coreSenses.reduce(0) { $0 + min(repository.getSenseMastery(senseId: $1.senseId), 20) }
        let maxM = coreSenses.count * 20
        let progressVal = maxM > 0 ? min(max(Float(currentM) / Float(maxM), 0), 1) : 0

        // MCQ-specific (currently always LU options for LU sentence)
        var sentenceWithBlank = ""
        var mcqOptions: [String] = []
        if type == .multipleChoice {
            let words = sentence.textLu.split(separator: " ").map { String($0) }
            let safeIndex = min(max(sentence.clozeIndex, 0), words.count - 1)
            let targetInSentence = safeIndex < words.count ? words[safeIndex] : ""
            sentenceWithBlank = words.enumerated().map { i, w in i == safeIndex ? "______" : w }.joined(separator: " ")

            // Strip trailing punctuation from the answer so it matches the displayed option exactly.
            // Preserve the sentence's capitalisation (e.g. "An" at position 0, "sinn" mid-sentence).
            let punctSet = CharacterSet(charactersIn: ".,!?;:'\"()")
            let answerOption = targetInSentence.trimmingCharacters(in: punctSet)
            let answerIsCapitalised = answerOption.first?.isUppercase ?? false

            // POS-matched distractors; then match capitalisation to the answer option.
            let rawDistractors = repository.getSmartDistractorsLu(target: answerOption, senseId: senseId, count: 3)
            let distractors = rawDistractors.map { word -> String in
                answerIsCapitalised
                    ? word.prefix(1).uppercased() + word.dropFirst()
                    : word.prefix(1).lowercased() + word.dropFirst()
            }

            mcqOptions = (distractors + [answerOption]).shuffled()
        }

        // Listening Comprehension options: correct EN translation + 2 distractor EN translations
        if type == .listeningComprehension {
            let distractors = repository.getRandomDistractorsEn(target: translation, count: 2)
            mcqOptions = (distractors + [translation]).shuffled()
        }

        // Conjugation Match options: correct lemma + 3 distractor lemmas
        var conjugationOptions: [String] = []
        if type == .conjugationMatch {
            let distractors = repository.getRandomDistractorsLu(target: targetWord, count: 3)
            conjugationOptions = (distractors + [targetWord]).shuffled()
        }

        // Paradigm Picker: pick a random pronoun row, blank the verb form, build 4 options
        var paradigmPromptPronoun = ""
        var paradigmCorrectForm = ""
        var paradigmPickerOptions: [String] = []
        if type == .paradigmPicker,
           let paradigmJson = senseData?.paradigm,
           let data = paradigmJson.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(SeedParadigm.self, from: data),
           parsed.present.count >= 3 {
            let rows = parsed.present
            let pickedIdx = Int.random(in: 0..<rows.count)
            let row = rows[pickedIdx]
            let parts = row.split(separator: " ", maxSplits: 1)
            paradigmPromptPronoun = String(parts.first ?? Substring(row))
            // Strip reflexive pronouns like "(mech)", "(sech)" from the verb form
            let rawForm = parts.count > 1 ? String(parts[1]) : row
            paradigmCorrectForm = rawForm
                .components(separatedBy: " ")
                .filter { !$0.hasPrefix("(") }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
            // Options: unique verb forms with reflexive pronouns stripped
            let allForms = rows.compactMap { r -> String? in
                let p = r.split(separator: " ", maxSplits: 1)
                guard p.count > 1 else { return nil }
                return String(p[1])
                    .components(separatedBy: " ")
                    .filter { !$0.hasPrefix("(") }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
            }
            let unique = Array(Set(allForms))
            let distractors = unique.filter { $0 != paradigmCorrectForm }.shuffled().prefix(3)
            paradigmPickerOptions = (Array(distractors) + [paradigmCorrectForm]).shuffled()
            // Fall back to MC if not enough distinct forms
            if paradigmPickerOptions.count < 2 { type = .multipleChoice }
        }

        // Article Choice: load exercise data
        var articleOptions: [String] = []
        var correctArticle: String = ""
        var articleRuleHint: String = ""
        var articleSentence: String = ""
        var articleSentenceEn: String = ""
        if type == .articleChoice {
            if let artEx = repository.getArticleExercise(for: senseId),
               let parsedOptions = try? JSONDecoder().decode([String].self, from: Data(artEx.options.utf8)) {
                articleOptions = parsedOptions.shuffled()
                correctArticle = artEx.correct
                articleRuleHint = artEx.ruleHint
                articleSentence = artEx.textLu
                articleSentenceEn = artEx.textEn
            } else {
                // No article exercise found — fall back to multiple choice
                type = .multipleChoice
            }
        }

        // Extract paradigm from sense (stored as JSON string)
        let decoder = JSONDecoder()
        if let paradigmJson = senseData?.paradigm,
           let data = paradigmJson.data(using: .utf8),
           let parsed = try? decoder.decode(SeedParadigm.self, from: data) {
            uiState.paradigm = parsed.present
            print("[LuxLingo] Flashcard paradigm loaded for \(senseId): \(parsed.present.first ?? "?")")
        } else {
            uiState.paradigm = nil
        }
        print("[LuxLingo] Flashcard: type=\(type), word=\(targetWord), lodAudio=\(vocab?.lodAudioUrl ?? "none"), paradigm=\(uiState.paradigm != nil)")
        uiState.sentenceClozeIndex = sentence.clozeIndex
        uiState.targetLodAudioUrl = vocab?.lodAudioUrl

        // N-rule chip: only show when the annotated form is the TARGET WORD with its trailing -n
        // dropped (e.g. iergendeen→iergendee). Suppress when the annotation refers to an article
        // or another word (e.g. n_rule_form='de' on a sentence with "De Paul…").
        uiState.nRuleFormInSentence = nRuleFormForTarget(sentence.nRuleForm, target: targetWord)

        uiState.currentSentence = sentence
        uiState.promptText = prompt
        uiState.targetWord = targetWord
        uiState.targetTranslation = translation
        uiState.sentenceParts = splitSentence(sentence.textLu, index: sentence.clozeIndex)
        uiState.lastExerciseType = uiState.currentExerciseType
        uiState.currentExerciseType = type
        uiState.sentenceWithBlank = sentenceWithBlank
        uiState.multipleChoiceOptions = mcqOptions
        uiState.shuffledTokens = tokens
        uiState.conjugationOptions = conjugationOptions
        uiState.paradigmPromptPronoun = paradigmPromptPronoun
        uiState.paradigmCorrectForm = paradigmCorrectForm
        uiState.paradigmPickerOptions = paradigmPickerOptions
        uiState.articleOptions = articleOptions
        uiState.correctArticle = correctArticle
        uiState.articleRuleHint = articleRuleHint
        uiState.articleSentence = articleSentence
        uiState.articleSentenceEn = articleSentenceEn
        uiState.currentSentenceIndex = nextIndex
        uiState.progress = progressVal
        uiState.currentMastery = currentM
        uiState.maxMastery = maxM
        uiState.isLoading = false
        uiState.recentSentenceIds = newRecentIds
        uiState.lastSenseId = senseId
        uiState.consecutiveSenseCount = (senseId == lastSenseId) ? consecutiveCount + 1 : 1
        uiState.exampleSentenceLu = sentence.textLu
        uiState.exampleSentenceEn = sentence.textEn
        uiState.phase = phaseName
        uiState.promptSubtitle = subtitle
        
        // Conjugation: use cloze_index from seed (annotated by annotate_sentences.py).
        // The word at cloze_index is the actual form used in the sentence.
        let lessonNum = Int(lessonId.components(separatedBy: "_").last ?? "") ?? 999
        let displayedTarget = targetWord
        if type == .flashcard || type == .reading {
            let words = sentence.textLu.split(separator: " ").map { String($0) }
            let safeIdx = min(max(sentence.clozeIndex, 0), words.count - 1)
            let actualForm = words[safeIdx].trimmingCharacters(in: .punctuationCharacters)
            // Only show conjugated/n-rule form in later lessons — in early lessons keep it as the lemma
            if actualForm.lowercased() != targetWord.lowercased() && lessonNum > 2 {
                uiState.targetWord = actualForm
            }
        }
        uiState.displayedTargetWord = displayedTarget

        // Suppress paradigm chip when the sentence uses the lemma unchanged
        if uiState.targetWord.lowercased() == targetWord.lowercased() {
            uiState.paradigm = nil
        }

        // Suppress all grammar hints for introductory lessons
        if lessonNum <= 2 {
            uiState.paradigm = nil
            uiState.nRuleFormInSentence = nil
        }

        // Finalize N-Rule Setup
        if type == .nRuleHunter {
            if let idx = findNRuleCandidate(in: sentence.textLu) {
                uiState.nRuleWordIndex = idx
                // Start with a random state to force the user to evaluate the rule
                uiState.nRuleSelection = ""
                uiState.showNRuleHint = false
                uiState.userInput = ""
            }
        }
        
        // Finalize Speed Run Setup
        if type == .zipfSpeedRun {
            uiState.isSpeedRunProposedCorrect = Bool.random()
            if !uiState.isSpeedRunProposedCorrect {
                let distractors = repository.getRandomDistractorsEn(target: translation, count: 1)
                uiState.targetTranslation = distractors.first ?? "something else"
            }
            startCountdown()
        }
        
        // Finalize Matching Setup
        if type == .matching {
            uiState.matchingPairs = repository.getMatchingPairs(lessonId: lessonId)
        }
        
        if uiState.failureCount > 0 {
            uiState.promptSubtitle = "Try again! " + uiState.promptSubtitle
        }

        // Stamp load time — isInteractionReady becomes true 350ms later (tap bleed-through guard)
        uiState.exerciseLoadedAt = Date()
    }

    // MARK: - User Input

    func onInputChanged(_ newInput: String) {
        uiState.userInput = newInput
        uiState.feedback = .none
    }

    func onOptionSelected(_ option: String) {
        if uiState.isFeedbackVisible { return } // Prevent double submission
        uiState.selectedOption = option
        onInputChanged(option)
        checkAnswer()
    }

    func selectMCQOption(_ option: String) {
        if uiState.isFeedbackVisible { return }
        uiState.selectedOption = option
        onInputChanged(option)
        checkAnswer()
    }

    func onNRuleToggle(to value: String) {
        uiState.nRuleSelection = value
        onInputChanged(value)
    }
    
    func onShowNRuleHint() {
        uiState.showNRuleHint = true
    }
    
    // MARK: - Eifeler Regel Logic
    
    private func shouldDropN(word: String, nextWord: String?) -> Bool {
        let normalizedWord = word.lowercased().replacingOccurrences(of: "[.,?!:;\"()]", with: "", options: .regularExpression)
        
        // 1. Check if the word is a candidate for dropping -n
        // Regular words ending in -en, plus specific irregulars
        let isCandidate = normalizedWord.hasSuffix("en") || ["hunn", "sinn", "keen", "ee", "mengem", "dengem", "sengem", "engem"].contains(normalizedWord)
        
        if !isCandidate { return false }
        
        // 2. If it's the end of the sentence/phrase, keep the -n
        guard let next = nextWord?.lowercased().replacingOccurrences(of: "[.,?!:;\"()]", with: "", options: .regularExpression), !next.isEmpty else {
            return false // Keep -n
        }
        
        // 3. Check the first letter of the next word
        let firstChar = String(next.prefix(1))
        
        // "D'Hunn am Nascht" rule: Keep -n if next word starts with d, h, n, t, z or a vowel
        let keepChars = ["d", "h", "n", "t", "z", "a", "e", "i", "o", "u"]
        if keepChars.contains(firstChar) {
            return false // Keep -n
        }
        
        // Before other consonants, drop the -n
        return true
    }
    
    func onSpeedRunSwipe(correct: Bool) {
        stopSpeedRunTimer()
        uiState.userInput = correct ? "TRUE" : "FALSE"
        checkAnswer()
    }

    func onReadingContinue() {
        uiState.feedback = .correct
        uiState.sessionXP += 5
        uiState.isFeedbackVisible = true // Show banner with EN translation
        recordResult(.reading)
        // loadNextExercise() happens when user taps "Continue" in the banner
    }

    func onFlashcardContinue() {
        uiState.feedback = .correct
        uiState.sessionXP += 5
        recordResult(.reading)
        loadNextExercise()
    }

    /// Called when the user submits a pronunciation recording.
    /// Shows the green feedback banner immediately ("submitted ✓"), then Continue loads next exercise.
    func onPronunciationSubmitted() {
        uiState.feedback      = .correct
        uiState.masteryChange = 0          // score applied when LuxASR result arrives
        uiState.isFeedbackVisible = true
        uiState.sessionXP    += 5
        AudioFeedbackService.shared.playCorrect()
        // Mark the sense so it won't be selected again this session
        uiState.masteredSenses.append(uiState.lastSenseId + "_pron")
    }
    
    func onContinueAfterFeedback() {
        guard isInteractionReady else { return }
        if uiState.feedback != .wrong {
            loadNextExercise()
        } else {
            // Reset input for retry if wrong, or just move on if failure count high
            if uiState.failureCount >= 2 {
                loadNextExercise()
            } else {
                uiState.isFeedbackVisible = false
                uiState.feedback = .none
                uiState.userInput = ""
                if uiState.currentExerciseType == .nRuleHunter {
                    uiState.nRuleSelection = ""
                }
            }
        }
    }

    func onSkipExercise() {
        loadNextExercise()
    }

    func onMatchingWrongPair() {
        uiState.failureCount += 1
    }

    // MARK: - Check Answer

    func checkAnswer() {
        let type = uiState.currentExerciseType

        // Matching auto-advances silently after a short delay — no feedback banner.
        // The guard ensures the timer is a no-op if the user already tapped Continue.
        if type == .matching {
            uiState.feedback = .correct
            recordResult(.matching)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, self.uiState.currentExerciseType == .matching else { return }
                self.loadNextExercise()
            }
            return
        }

        uiState.isFeedbackVisible = true

        guard let sentence = uiState.currentSentence else { return }
        let userInput = normalizeText(uiState.userInput)

        let comparisonTargetRaw: String
        switch type {
        case .jumbledLu:
            comparisonTargetRaw = sentence.textLu
        case .jumbledEn:
            comparisonTargetRaw = sentence.textEn
        case .cloze, .multipleChoice:
            let words = sentence.textLu.split(separator: " ").map { String($0) }
            let safeIndex = min(max(sentence.clozeIndex, 0), words.count - 1)
            comparisonTargetRaw = safeIndex < words.count ? words[safeIndex] : ""
        case .conjugationMatch:
            comparisonTargetRaw = uiState.displayedTargetWord
        case .paradigmPicker:
            comparisonTargetRaw = uiState.paradigmCorrectForm
        case .listeningComprehension:
            comparisonTargetRaw = uiState.targetTranslation
        case .audioDictation:
            comparisonTargetRaw = uiState.displayedTargetWord
        case .articleChoice:
            comparisonTargetRaw = uiState.correctArticle
        case .nRuleHunter:
            let sentencesWords = sentence.textLu.split(separator: " ").map { String($0) }
            let word = sentencesWords[uiState.nRuleWordIndex]
            let nextWord = (uiState.nRuleWordIndex + 1 < sentencesWords.count) ? sentencesWords[uiState.nRuleWordIndex + 1] : nil
            
            let mustDrop = shouldDropN(word: word, nextWord: nextWord)
            comparisonTargetRaw = mustDrop ? "" : "n"
        case .zipfSpeedRun:
            comparisonTargetRaw = uiState.isSpeedRunProposedCorrect ? "TRUE" : "FALSE"
        default:
            comparisonTargetRaw = uiState.targetWord
        }

        let comparisonTarget = normalizeText(comparisonTargetRaw)

        let feedback: AnswerFeedback
        let result: ExerciseResult

        switch type {
        case .jumbledLu, .jumbledEn:
            if userInput == comparisonTarget {
                feedback = .correct; result = .cloze
            } else {
                feedback = .wrong; result = .error
            }
        case .multipleChoice:
            if userInput == comparisonTarget {
                feedback = .correct; result = .multipleChoice
            } else {
                feedback = .wrong; result = .error
            }
        case .conjugationMatch:
            if userInput == comparisonTarget {
                feedback = .correct; result = .conjugationMatch
            } else {
                feedback = .wrong; result = .error
            }
        case .paradigmPicker:
            if userInput == comparisonTarget {
                feedback = .correct; result = .paradigmPicker
            } else {
                feedback = .wrong; result = .error
            }
        case .listeningComprehension:
            if userInput == comparisonTarget {
                feedback = .correct; result = .listeningComprehension
            } else {
                feedback = .wrong; result = .error
            }
        case .articleChoice:
            if userInput == comparisonTarget {
                feedback = .correct; result = .articleChoice
            } else {
                feedback = .wrong; result = .error
            }
        case .pronunciationPractice:
            // Pronunciation exercises are submitted async — score arrives via PronunciationService.
            // Mark as "practised" so it won't repeat for this sense this session.
            uiState.masteredSenses.append(uiState.lastSenseId + "_pron")
            feedback = .correct; result = .pronunciationPractice
        case .audioDictation:
            let dist = levenshtein(userInput, comparisonTarget)
            if dist == 0 {
                feedback = .correct; result = .audioDictation
            } else if dist <= 2 {
                // Accept minor spelling errors but flag them — Luxembourgish orthography is tricky
                feedback = .typo; result = .audioDictation
            } else {
                feedback = .wrong; result = .error
            }
        case .nRuleHunter:
            if userInput == comparisonTarget {
                feedback = .correct; result = .cloze
            } else {
                feedback = .wrong; result = .error
            }
        default:
            let distance = levenshtein(userInput, comparisonTarget)
            let trimmedUser = userInput.hasSuffix("n") ? String(userInput.dropLast()) : userInput
            let trimmedTarget = comparisonTarget.hasSuffix("n") ? String(comparisonTarget.dropLast()) : comparisonTarget
            let isNRule = distance == 1 && trimmedUser == trimmedTarget

            if distance == 0 {
                feedback = .correct; result = .cloze
            } else if isNRule {
                feedback = .nRule; result = .cloze
            } else if distance == 1 {
                feedback = .typo; result = .cloze
            } else {
                feedback = .wrong; result = .error
            }
        }

        uiState.feedback = feedback
        uiState.isFeedbackVisible = true
        // For MC, strip punctuation so correctOption matches the displayed option string exactly.
        let punctSet = CharacterSet(charactersIn: ".,!?;:'\"()")
        uiState.correctOption = (type == .multipleChoice)
            ? comparisonTargetRaw.trimmingCharacters(in: punctSet)
            : comparisonTargetRaw
        uiState.failureCount = (feedback == .wrong) ? uiState.failureCount + 1 : 0

        // Map to correct result type
        let resultType: ExerciseResult
        if result == .error {
            resultType = .error
        } else {
            switch type {
            case .multipleChoice:      resultType = .multipleChoice
            case .jumbledLu:           resultType = .jumbledLu
            case .jumbledEn:           resultType = .jumbledEn
            case .conjugationMatch:         resultType = .conjugationMatch
            case .paradigmPicker:           resultType = .paradigmPicker
            case .listeningComprehension:   resultType = .listeningComprehension
            case .audioDictation:           resultType = .audioDictation
            case .articleChoice:            resultType = .articleChoice
            default:                   resultType = result
            }
        }

        recordResult(resultType)

        // Calculate and set mastery change and XP
        let mChange: Int
        let xpGained: Int
        
        if feedback == .wrong {
            mChange = -2
            xpGained = 1
        } else {
            switch type {
            case .multipleChoice, .articleChoice:
                mChange = 4
                xpGained = 10
            case .jumbledLu, .jumbledEn: 
                mChange = 8
                xpGained = 15
            case .nRuleHunter:
                mChange = 6
                xpGained = 12
            case .conjugationMatch:
                mChange = 5
                xpGained = 12
            case .paradigmPicker:
                mChange = 6
                xpGained = 13
            case .listeningComprehension:
                mChange = 4
                xpGained = 10
            case .audioDictation:
                mChange = 6
                xpGained = 14
            case .zipfSpeedRun:
                mChange = 5
                xpGained = 8
            case .cloze: 
                mChange = 10
                xpGained = (feedback == .correct) ? 25 : 10
            default: 
                mChange = 1
                xpGained = 5
            }
        }
        uiState.masteryChange = mChange
        uiState.sessionXP += xpGained

        // Rapid fire: count correct, then auto-advance after a brief flash
        if uiState.isRapidFire && type == .zipfSpeedRun {
            if feedback == .correct { uiState.rapidFireCorrect += 1 }
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard let self, self.uiState.isFeedbackVisible else { return }
                self.onContinueAfterFeedback()
            }
        }
    }

    // MARK: - Finish Lesson

    private func finishLesson() {
        if isReviewMode {
            // Review session complete — don't mark any lesson as complete
            uiState.isLessonFinished = true
            uiState.masteredSenses   = []
            uiState.isLoading        = false
            return
        }
        repository.completeLesson(lessonId: lessonId)
        let coreSenses = repository.getLessonCoreSenses(lessonId: lessonId)
        let masteredLabels = coreSenses.map { sense -> String in
            let vocab  = repository.getVocabularyById(id: sense.surfaceId)
            let luWord = vocab?.wordText ?? "?"
            return "\(luWord) → \(sense.translations)"
        }
        uiState.isLessonFinished = true
        uiState.masteredSenses   = masteredLabels
        uiState.isLoading        = false
    }

    // MARK: - Review session exercise loader

    private func loadNextReviewExercise() {
        uiState.failureCount       = 0
        uiState.isFeedbackVisible  = false
        uiState.userInput          = ""
        uiState.selectedOption     = nil
        uiState.correctOption      = nil
        uiState.masteryChange      = 0
        uiState.shuffledTokens     = []
        uiState.matchingPairs      = []
        uiState.paradigm           = nil
        uiState.nRuleFormInSentence = nil
        uiState.conjugationOptions = []
        uiState.paradigmPickerOptions = []

        guard let item = reviewItems.first else { finishLesson(); return }
        reviewItems.removeFirst()

        let done = uiState.totalSentences - reviewItems.count
        uiState.progress             = Float(done) / Float(max(uiState.totalSentences, 1))
        uiState.currentSentenceIndex += 1
        uiState.phase                = "Review"

        guard let senseData = repository.getSense(senseId: item.senseId),
              let vocab     = repository.getVocabularyById(id: senseData.surfaceId) else {
            loadNextReviewExercise(); return
        }

        let mastery     = repository.getSenseMastery(senseId: item.senseId)
        let targetWord  = vocab.wordText
        let translation = senseData.translations

        guard let sentence = repository.getSentenceForLesson(
            lessonId: item.lessonId,
            excludeSentenceIds: uiState.recentSentenceIds,
            targetSenseId: item.senseId
        ) else { loadNextReviewExercise(); return }

        // Exercise types for review: no flashcard/reading (user has seen these).
        // Lean toward harder types; keep listening/dictation overrides.
        var type: ExerciseTypeNew
        switch mastery {
        case ..<6:  type = .multipleChoice
        case ..<12: type = Bool.random() ? .jumbledEn : .multipleChoice
        case ..<20: type = Bool.random() ? .cloze     : .jumbledLu
        default:    type = .cloze
        }
        if mastery >= 4  && Float.random(in: 0...1) < 0.22 { type = .listeningComprehension }
        if mastery >= 8  && Float.random(in: 0...1) < 0.15 { type = .audioDictation }

        // Jumbled tokens
        var tokens = [String]()
        if type == .jumbledLu {
            tokens = cleanAndShuffleTokens(sentence.textLu)
            if tokens.count < 5 {
                tokens = (tokens + repository.getRandomDistractorsLu(target: targetWord, count: 2)).shuffled()
            }
        } else if type == .jumbledEn {
            let base = cleanAndShuffleTokens(sentence.textEn)
            let extras = repository.getRandomDistractorsEn(target: translation, count: 3)
                .filter { !Set(base.map { $0.lowercased() }).contains($0.lowercased()) }.prefix(2)
            tokens = (base + extras).shuffled()
        }

        // MCQ options
        var mcqOptions      = [String]()
        var sentenceBlank   = ""
        if type == .multipleChoice {
            let words     = sentence.textLu.split(separator: " ").map(String.init)
            let safeIdx   = min(max(sentence.clozeIndex, 0), words.count - 1)
            let punctSet  = CharacterSet(charactersIn: ".,!?;:'\"()")
            let answer    = (safeIdx < words.count ? words[safeIdx] : "").trimmingCharacters(in: punctSet)
            sentenceBlank = words.enumerated().map { i, w in i == safeIdx ? "______" : w }.joined(separator: " ")
            let isCap     = answer.first?.isUppercase ?? false
            let raw       = repository.getSmartDistractorsLu(target: answer, senseId: item.senseId, count: 3)
            let dists     = raw.map { isCap ? $0.prefix(1).uppercased() + $0.dropFirst()
                                            : $0.prefix(1).lowercased() + $0.dropFirst() }
            mcqOptions    = (dists + [answer]).shuffled()
        } else if type == .listeningComprehension {
            mcqOptions = (repository.getRandomDistractorsEn(target: translation, count: 2) + [translation]).shuffled()
        }

        // Prompt text
        let prompt: String; let subtitle: String
        switch type {
        case .jumbledEn:              prompt = sentence.textLu;  subtitle = "Translate to English"
        case .jumbledLu:              prompt = sentence.textEn;  subtitle = "Translate to Luxembourgish"
        case .multipleChoice:         prompt = sentence.textEn;  subtitle = "Pick the correct word"
        case .cloze:                  prompt = sentence.textEn;  subtitle = "Type the missing word"
        case .listeningComprehension: prompt = "";               subtitle = "Listen and choose the meaning"
        case .audioDictation:         prompt = "";               subtitle = "Listen and write the word"
        default:                      prompt = sentence.textEn;  subtitle = ""
        }

        // Paradigm
        if let json  = senseData.paradigm,
           let data  = json.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(SeedParadigm.self, from: data) {
            uiState.paradigm = parsed.present
        }

        let newRecent = Array((uiState.recentSentenceIds + [sentence.sentenceId]).suffix(8))

        uiState.recentSentenceIds    = newRecent
        uiState.lastSenseId          = item.senseId
        uiState.consecutiveSenseCount = 1
        uiState.lastExerciseType     = uiState.currentExerciseType
        uiState.currentExerciseType  = type
        uiState.currentSentence      = sentence
        uiState.promptText           = prompt
        uiState.promptSubtitle       = subtitle
        uiState.targetWord           = targetWord
        uiState.displayedTargetWord  = targetWord
        uiState.targetTranslation    = translation
        uiState.sentenceParts        = splitSentence(sentence.textLu, index: sentence.clozeIndex)
        uiState.sentenceWithBlank    = sentenceBlank
        uiState.multipleChoiceOptions = mcqOptions
        uiState.shuffledTokens       = tokens
        uiState.sentenceClozeIndex   = sentence.clozeIndex
        uiState.targetLodAudioUrl    = vocab.lodAudioUrl
        uiState.nRuleFormInSentence  = nRuleFormForTarget(sentence.nRuleForm, target: targetWord)
        uiState.exampleSentenceLu    = sentence.textLu
        uiState.exampleSentenceEn    = sentence.textEn
        uiState.currentMastery       = mastery
        uiState.maxMastery           = 20
        uiState.isLoading            = false
        uiState.exerciseLoadedAt     = Date()
    }

    // MARK: - Record Result (mastery weighting)

    private func recordResult(_ result: ExerciseResult) {
        func getWeight(_ res: ExerciseResult) -> Int {
            switch res {
            case .reading: return 1
            case .matching: return 3
            case .multipleChoice: return 4
            case .jumbledLu, .jumbledEn: return 8
            case .cloze: return 10
            case .nRuleHunter: return 6
            case .zipfSpeedRun: return 5
            case .conjugationMatch: return 5
            case .paradigmPicker: return 6
            case .listeningComprehension: return 4
            case .audioDictation: return 6
            case .articleChoice: return 4
            case .pronunciationPractice: return 5  // awarded on submit, not on score arrival
            case .error: return -2
            }
        }

        if uiState.currentExerciseType == .matching {
            for item in uiState.matchingPairs {
                repository.recordExerciseResult(senseId: item.id, weight: getWeight(.matching))
            }
            return
        }

        guard let sentence = uiState.currentSentence else { return }
        let isCloze = result == .cloze

        if result == .error {
            if let senseId = repository.getSenseIdForCloze(sentence: sentence) {
                repository.recordExerciseResult(senseId: senseId, weight: getWeight(result), isCloze: false)
            }
        } else {
            let lessonCoreSenseIds = Set(repository.getLessonCoreSenses(lessonId: lessonId).map { $0.senseId })
            let sentenceSenseIds = Set(sentence.senseIds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            let targetSenseId = repository.getSenseIdForCloze(sentence: sentence)

            if let targetId = targetSenseId {
                repository.recordExerciseResult(senseId: targetId, weight: getWeight(result), isCloze: isCloze)
            }

            let secondarySenses = sentenceSenseIds.intersection(lessonCoreSenseIds).subtracting([targetSenseId ?? ""])
            for senseId in secondarySenses {
                let mastery = repository.getSenseMastery(senseId: senseId)
                let secondaryWeight = (uiState.currentExerciseType == .multipleChoice || uiState.currentExerciseType == .cloze) ? 2 : 1

                if mastery == 0 {
                    for _ in 0..<3 {
                        repository.recordExerciseResult(senseId: senseId, weight: secondaryWeight, isCloze: false)
                    }
                } else {
                    repository.recordExerciseResult(senseId: senseId, weight: secondaryWeight, isCloze: false)
                }
            }

            let fillerSenses = sentenceSenseIds.subtracting(lessonCoreSenseIds)
            for senseId in fillerSenses {
                repository.recordExerciseResult(senseId: senseId, weight: getWeight(.reading), isCloze: false)
            }
        }
    }

    // MARK: - Innovations Logic
    
    private func findNRuleCandidate(in sentence: String) -> Int? {
        let words = sentence.split(separator: " ").map(String.init)
        if words.count < 2 { return nil }
        
        // Potential candidates: words where Eifeler Regel *could* apply (ending in -n or -en)
        let candidates = words.indices.filter { i in
            if i >= words.count - 1 { return false }
            let word = words[i].lowercased().replacingOccurrences(of: "[.,?!:;\"()]", with: "", options: .regularExpression)
            return word.hasSuffix("n") || ["hunn", "sinn", "keen", "ee", "mengem", "dengem", "sengem", "engem"].contains(word)
        }
        
        return candidates.randomElement()
    }

    // MARK: - Rapid Fire

    private func loadRapidFireExercise() {
        guard !uiState.rapidFireQueue.isEmpty else {
            uiState.isRapidFire = false
            finishLesson()
            return
        }
        let senseId = uiState.rapidFireQueue.removeFirst()

        uiState.isLoading = true
        uiState.failureCount = 0
        uiState.isFeedbackVisible = false
        uiState.userInput = ""
        uiState.selectedOption = nil
        uiState.correctOption = nil
        uiState.masteryChange = 0
        uiState.shuffledTokens = []
        uiState.matchingPairs = []

        guard let senseData = repository.getSense(senseId: senseId),
              let vocab = repository.getVocabularyById(id: senseData.surfaceId) else {
            loadRapidFireExercise()
            return
        }

        let translation = senseData.translations
        uiState.isSpeedRunProposedCorrect = Bool.random()
        if uiState.isSpeedRunProposedCorrect {
            uiState.targetTranslation = translation
        } else {
            let distractors = repository.getRandomDistractorsEn(target: translation, count: 1)
            uiState.targetTranslation = distractors.first ?? "something else"
        }

        let done = uiState.rapidFireTotal - uiState.rapidFireQueue.count
        uiState.currentExerciseType = .zipfSpeedRun
        uiState.targetWord = vocab.wordText
        uiState.displayedTargetWord = vocab.wordText
        uiState.currentSentenceIndex += 1
        uiState.promptText = "Rapid Fire!"
        uiState.promptSubtitle = "\(done) / \(uiState.rapidFireTotal)"
        uiState.isLoading = false

        // Countdown only before the first card; subsequent words jump straight in
        if done == 1 {
            startCountdown()
        } else {
            startSpeedRunTimer()
        }
    }

    private var speedRunTimer: Timer?
    private var countdownTimer: Timer?

    private func startCountdown() {
        stopCountdown()
        uiState.speedRunCountdown = 3
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.uiState.speedRunCountdown > 1 {
                    self.uiState.speedRunCountdown -= 1
                } else {
                    self.stopCountdown()
                    self.startSpeedRunTimer()
                }
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        uiState.speedRunCountdown = 0
    }

    private func startSpeedRunTimer() {
        speedRunTimer?.invalidate()
        uiState.timeRemaining = 1.0
        // Use a background timer but update UI on MainActor
        speedRunTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.uiState.timeRemaining -= 0.025 // 2 seconds total
                if self.uiState.timeRemaining <= 0 {
                    self.stopSpeedRunTimer()
                    self.uiState.userInput = "TIMEOUT"
                    self.checkAnswer()
                }
            }
        }
    }

    private func stopSpeedRunTimer() {
        speedRunTimer?.invalidate()
        speedRunTimer = nil
    }

    // MARK: - Helpers

    private func splitSentence(_ sentence: String, index: Int) -> [String] {
        if sentence.isEmpty { return ["", ""] }
        let words = sentence.split(separator: " ").map { String($0) }
        let safeIndex = min(max(index, 0), words.count - 1)
        let before = words.prefix(safeIndex).joined(separator: " ")
        let after = words.dropFirst(safeIndex + 1).joined(separator: " ")
        return [before, after]
    }

    private func cleanAndShuffleTokens(_ text: String) -> [String] {
        return text.split(separator: " ")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,?!:;\"()")) }
            .filter { !$0.isEmpty }
            .shuffled()
    }

    private func normalizeText(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[.,?!:;\"()]", with: "", options: .regularExpression)
    }

    private func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        let len0 = lhsChars.count + 1
        let len1 = rhsChars.count + 1
        var cost = Array(0..<len0)
        var newCost = Array(repeating: 0, count: len0)

        for i in 1..<len1 {
            newCost[0] = i
            for j in 1..<len0 {
                let match = (lhsChars[j - 1] == rhsChars[i - 1]) ? 0 : 1
                newCost[j] = min(newCost[j - 1] + 1, min(cost[j] + 1, cost[j - 1] + match))
            }
            swap(&cost, &newCost)
        }
        return cost[len0 - 1]
    }
}

/// Returns `form` only when it is the target word with its trailing -n removed
/// (the classic Luxembourgish n-rule drop). Suppresses annotations for articles
/// or unrelated words (e.g. n_rule_form='de' from an "De Paul…" sentence
/// where the teaching target is "Fenster" or "Bad").
private func nRuleFormForTarget(_ form: String?, target: String) -> String? {
    guard let form, !form.isEmpty else { return nil }
    let t = target.lowercased()
    let f = form.lowercased()
    guard t.hasSuffix("n"), String(t.dropLast()) == f else { return nil }
    return form
}
