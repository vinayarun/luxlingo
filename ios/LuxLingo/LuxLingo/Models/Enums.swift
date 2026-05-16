import Foundation

// MARK: - Exercise Type (New Engine - mastery-based progression)
enum ExerciseTypeNew: String, Codable {
    case reading = "READING"
    case multipleChoice = "MULTIPLE_CHOICE"
    case jumbledEn = "JUMBLED_EN"
    case jumbledLu = "JUMBLED_LU"
    case cloze = "CLOZE"
    case matching = "MATCHING"
    case flashcard = "FLASHCARD"
    case nRuleHunter = "N_RULE_HUNTER"
    case zipfSpeedRun = "ZIPF_SPEED_RUN"
    case conjugationMatch = "CONJUGATION_MATCH"
    case paradigmPicker = "PARADIGM_PICKER"
    case listeningComprehension = "LISTENING_COMPREHENSION"
    case audioDictation = "AUDIO_DICTATION"
    case articleChoice = "ARTICLE_CHOICE"
    case pronunciationPractice = "PRONUNCIATION_PRACTICE"
}

// MARK: - Exercise Type (Legacy - JSON-based lessons)
enum ExerciseType: String, Codable {
    case mcq
    case match
    case reorder
    case fill
    case translate
    case listen
    case speak
    case flashcard
}

// MARK: - Answer Feedback
enum AnswerFeedback: Equatable {
    case none
    case correct
    case wrong
    case typo
    case nRule
}

// MARK: - Exercise Result (for mastery weighting)
enum ExerciseResult {
    case reading
    case multipleChoice
    case jumbledLu
    case jumbledEn
    case cloze
    case matching
    case nRuleHunter
    case zipfSpeedRun
    case conjugationMatch
    case paradigmPicker
    case listeningComprehension
    case audioDictation
    case articleChoice
    case pronunciationPractice
    case error
}
