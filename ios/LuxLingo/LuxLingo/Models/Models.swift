import Foundation

// MARK: - Course Structure (used by HomeScreen)

struct CourseUnit: Identifiable {
    let id: String
    let title: String
    var lessons: [Lesson]
}

struct Lesson: Identifiable {
    let id: String
    let title: String
    let objective: String
    let exercises: [Exercise]
    var isCompleted: Bool = false
    var coveragePercent: Int = 0   // Zipf cumulative coverage — used by stats page
    var totalWords: Int = 0        // core senses in this lesson
    var practicedWords: Int = 0    // senses with mastery > 0
}

struct Exercise: Identifiable, Codable {
    let id: String
    let type: ExerciseType
    let prompt: String
    let correctAnswer: String
    let options: [String]?
    let hint: String?
    let audioText: String?
    let clozeIndex: Int?
    let targetTranslation: String?

    enum CodingKeys: String, CodingKey {
        case id, type, prompt, options, hint
        case correctAnswer = "correct_answer"
        case audioText = "audio_text"
        case clozeIndex = "cloze_index"
        case targetTranslation = "target_translation"
    }
}

// MARK: - Vocabulary Word (for vocabulary browser and review mode)

struct VocabWord: Identifiable {
    var id: String { senseId }
    let senseId:    String
    let wordLu:     String   // Luxembourgish word
    let primaryEn:  String   // English meaning
    let exampleLu:  String   // one example sentence LU
    let exampleEn:  String   // one example sentence EN
    let mastery:    Int      // 0-20
    let lodAudioUrl: String?
}

// MARK: - Matching Item

struct MatchingItemModel: Identifiable {
    let id: String
    let nativeText: String
    let translatedText: String
}

// MARK: - Legacy Word Model (unit_X.json support)

struct Word: Codable {
    let rank: Int
    let word: String
    let translation: String
    let exampleLb: String
    let exampleEn: String
    let id: String
    let unitRank: Int

    enum CodingKeys: String, CodingKey {
        case rank, word, translation, id
        case exampleLb = "example_lb"
        case exampleEn = "example_en"
        case unitRank = "unit_rank"
    }
}

struct UnitMetadata: Codable {
    let unitNumber: Int?
    let title: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case unitNumber = "unit_number"
        case title, description
    }
}

struct UnitData: Codable {
    let unitMetadata: UnitMetadata?
    let words: [Word]?

    enum CodingKeys: String, CodingKey {
        case unitMetadata = "unit_metadata"
        case words
    }
}
