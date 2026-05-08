import Foundation

// MARK: - Seed Data (parsed from initial_seed.json)

struct InitialSeedData: Codable {
    let version: Double
    let vocabulary: [SeedVocab]
    let senses: [SeedSense]
    let sentences: [SeedSentence]
    let curriculum: [SeedLesson]
}

struct SeedVocab: Codable {
    let surfaceId: String
    let lemmaId: String
    let wordLu: String
    let audioRef: String
    let lodAudioUrl: String?

    enum CodingKeys: String, CodingKey {
        case surfaceId = "surface_id"
        case lemmaId = "lemma_id"
        case wordLu = "word_lu"
        case audioRef = "audio_ref"
        case lodAudioUrl = "lod_audio_url"
    }
}

struct SeedParadigm: Codable {
    let present: [String]
}

struct SeedSense: Codable {
    let senseId: String
    let surfaceId: String
    let primaryEn: String
    let pos: String
    let isGoldenKey: Bool?
    let isPicturable: Bool?
    let paradigm: SeedParadigm?

    enum CodingKeys: String, CodingKey {
        case senseId = "sense_id"
        case surfaceId = "surface_id"
        case primaryEn = "primary_en"
        case pos
        case isGoldenKey = "is_golden_key"
        case isPicturable = "is_picturable"
        case paradigm
    }
}

struct SeedSentence: Codable {
    let sentenceId: String
    let textLu: String
    let textEn: String
    let senseIds: [String]
    let clozeIndex: Int
    let difficulty: String
    let nRuleWordIndex: Int?
    let nRuleForm: String?
    let exactForm: Bool?
    let clozeConfidence: String?

    enum CodingKeys: String, CodingKey {
        case sentenceId = "sentence_id"
        case textLu = "text_lu"
        case textEn = "text_en"
        case senseIds = "sense_ids"
        case clozeIndex = "cloze_index"
        case difficulty
        case nRuleWordIndex = "n_rule_word_index"
        case nRuleForm = "n_rule_form"
        case exactForm = "exact_form"
        case clozeConfidence = "cloze_confidence"
    }
}

struct SeedLesson: Codable {
    let lessonId: String
    let titleEn: String
    let coreSenses: [String]
    let secondarySenses: [String]?

    enum CodingKeys: String, CodingKey {
        case lessonId = "lesson_id"
        case titleEn = "title_en"
        case coreSenses = "core_senses"
        case secondarySenses = "secondary_senses"
    }
}
