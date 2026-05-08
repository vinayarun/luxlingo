import Foundation
import SwiftData

// MARK: - Vocabulary (Surface Layer)
@Model
final class VocabularyEntity {
    @Attribute(.unique) var surfaceId: String
    var lemmaId: String
    var wordText: String
    var components: String?
    var phonetic: String?
    var audioRef: String?
    var lodAudioUrl: String?

    init(surfaceId: String, lemmaId: String, wordText: String, components: String? = nil, phonetic: String? = nil, audioRef: String? = nil, lodAudioUrl: String? = nil) {
        self.surfaceId = surfaceId
        self.lemmaId = lemmaId
        self.wordText = wordText
        self.components = components
        self.phonetic = phonetic
        self.audioRef = audioRef
        self.lodAudioUrl = lodAudioUrl
    }
}

// MARK: - Senses (Semantic Layer)
@Model
final class SensesEntity {
    @Attribute(.unique) var senseId: String
    var surfaceId: String
    var translations: String
    var altEn: String?
    var tags: String
    var isGoldenKey: Bool
    var isPicturable: Bool
    var falseFriend: String?
    var paradigm: String?  // JSON: {"present": ["ech kann", "du kanns", ...]}

    init(senseId: String, surfaceId: String, translations: String, altEn: String? = nil, tags: String, isGoldenKey: Bool, isPicturable: Bool, falseFriend: String? = nil, paradigm: String? = nil) {
        self.senseId = senseId
        self.surfaceId = surfaceId
        self.translations = translations
        self.altEn = altEn
        self.tags = tags
        self.isGoldenKey = isGoldenKey
        self.isPicturable = isPicturable
        self.falseFriend = falseFriend
        self.paradigm = paradigm
    }
}

// MARK: - Sentences (Context Layer)
@Model
final class SentencesEntity {
    @Attribute(.unique) var sentenceId: String
    var textLu: String
    var textEn: String
    var senseIds: String   // Comma-separated sense IDs
    var clozeIndex: Int
    var lexCoverage: Double
    var synDensity: Double
    var isHandcrafted: Bool
    var difficulty: String
    var nRuleWordIndex: Int?   // index of word where n-rule is applied (nil = no n-rule)
    var nRuleForm: String?     // the form as it appears in sentence (n already dropped)
    var exactForm: Bool = true // true = target word appears unchanged (no conjugation, no n-rule)

    init(sentenceId: String, textLu: String, textEn: String, senseIds: String, clozeIndex: Int, lexCoverage: Double, synDensity: Double, isHandcrafted: Bool, difficulty: String = "simple", nRuleWordIndex: Int? = nil, nRuleForm: String? = nil, exactForm: Bool = true) {
        self.sentenceId = sentenceId
        self.textLu = textLu
        self.textEn = textEn
        self.senseIds = senseIds
        self.clozeIndex = clozeIndex
        self.lexCoverage = lexCoverage
        self.synDensity = synDensity
        self.isHandcrafted = isHandcrafted
        self.difficulty = difficulty
        self.nRuleWordIndex = nRuleWordIndex
        self.nRuleForm = nRuleForm
        self.exactForm = exactForm
    }
}

// MARK: - Curriculum (Path Layer)
@Model
final class CurriculumEntity {
    @Attribute(.unique) var lessonId: String
    var titleEn: String
    var coreSenses: String     // Comma-separated sense IDs
    var secondarySenses: String?
    var prereqs: String?
    var themeTag: String?
    var orderIndex: Int

    init(lessonId: String, titleEn: String, coreSenses: String, secondarySenses: String? = nil, prereqs: String? = nil, themeTag: String? = nil, orderIndex: Int = 0) {
        self.lessonId = lessonId
        self.titleEn = titleEn
        self.coreSenses = coreSenses
        self.secondarySenses = secondarySenses
        self.prereqs = prereqs
        self.themeTag = themeTag
        self.orderIndex = orderIndex
    }
}

// MARK: - User Progress (Learning Layer)
@Model
final class UserProgressEntity {
    // Composite key simulated via unique constraint on combined string
    @Attribute(.unique) var compositeKey: String  // "userId|senseId|surfaceId"
    var userId: String
    var senseId: String
    var surfaceId: String
    var exposure: Int
    var mastery: Int
    var clozeExposure: Int
    var lastError: String?
    var fsrsData: String?

    init(userId: String, senseId: String, surfaceId: String, exposure: Int, mastery: Int, clozeExposure: Int = 0, lastError: String? = nil, fsrsData: String? = nil) {
        self.compositeKey = "\(userId)|\(senseId)|\(surfaceId)"
        self.userId = userId
        self.senseId = senseId
        self.surfaceId = surfaceId
        self.exposure = exposure
        self.mastery = mastery
        self.clozeExposure = clozeExposure
        self.lastError = lastError
        self.fsrsData = fsrsData
    }
}

// MARK: - Lesson Status
@Model
final class LessonStatusEntity {
    @Attribute(.unique) var lessonId: String
    var titleEn: String
    var isCompleted: Bool
    var mastery: Int
    var completionPercentage: Double
    var orderIndex: Int

    init(lessonId: String, titleEn: String = "", isCompleted: Bool = false, mastery: Int = 0, completionPercentage: Double = 0.0, orderIndex: Int = 0) {
        self.lessonId = lessonId
        self.titleEn = titleEn
        self.isCompleted = isCompleted
        self.mastery = mastery
        self.completionPercentage = completionPercentage
        self.orderIndex = orderIndex
    }
}
