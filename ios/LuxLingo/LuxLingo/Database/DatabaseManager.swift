import Foundation
import SwiftData

// MARK: - Database Manager (replaces Room DAOs)
@MainActor
final class DatabaseManager {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Vocabulary DAO

    func insertVocabulary(_ entity: VocabularyEntity) {
        // Upsert: delete existing then insert
        let surfaceId = entity.surfaceId
        let descriptor = FetchDescriptor<VocabularyEntity>(
            predicate: #Predicate { $0.surfaceId == surfaceId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.lemmaId = entity.lemmaId
            existing.wordText = entity.wordText
            existing.audioRef = entity.audioRef
        } else {
            modelContext.insert(entity)
        }
    }

    func getVocabularyById(_ surfaceId: String) -> VocabularyEntity? {
        let descriptor = FetchDescriptor<VocabularyEntity>(
            predicate: #Predicate { $0.surfaceId == surfaceId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Senses DAO

    func insertSense(_ entity: SensesEntity) {
        let senseId = entity.senseId
        let descriptor = FetchDescriptor<SensesEntity>(
            predicate: #Predicate { $0.senseId == senseId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.surfaceId = entity.surfaceId
            existing.translations = entity.translations
            existing.tags = entity.tags
            existing.isGoldenKey = entity.isGoldenKey
            existing.isPicturable = entity.isPicturable
        } else {
            modelContext.insert(entity)
        }
    }

    func getSense(_ senseId: String) -> SensesEntity? {
        let descriptor = FetchDescriptor<SensesEntity>(
            predicate: #Predicate { $0.senseId == senseId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func getAllSenses() -> [SensesEntity] {
        let descriptor = FetchDescriptor<SensesEntity>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Sentences DAO

    func insertSentence(_ entity: SentencesEntity) {
        let sentenceId = entity.sentenceId
        let descriptor = FetchDescriptor<SentencesEntity>(
            predicate: #Predicate { $0.sentenceId == sentenceId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.textLu = entity.textLu
            existing.textEn = entity.textEn
            existing.senseIds = entity.senseIds
            existing.clozeIndex = entity.clozeIndex
            existing.nRuleWordIndex = entity.nRuleWordIndex
            existing.nRuleForm = entity.nRuleForm
            existing.exactForm = entity.exactForm
        } else {
            modelContext.insert(entity)
        }
    }

    func getSentencesContainingSense(_ senseId: String) -> [SentencesEntity] {
        // SwiftData doesn't support LIKE queries directly, so we fetch all and filter
        let descriptor = FetchDescriptor<SentencesEntity>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { sentence in
            sentence.senseIds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.contains(senseId)
        }
    }

    // MARK: - Curriculum DAO

    func insertCurriculum(_ entity: CurriculumEntity) {
        let lessonId = entity.lessonId
        let descriptor = FetchDescriptor<CurriculumEntity>(
            predicate: #Predicate { $0.lessonId == lessonId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.titleEn = entity.titleEn
            existing.coreSenses = entity.coreSenses
            existing.secondarySenses = entity.secondarySenses
            existing.orderIndex = entity.orderIndex
        } else {
            modelContext.insert(entity)
        }
    }

    func getCurriculum(_ lessonId: String) -> CurriculumEntity? {
        let descriptor = FetchDescriptor<CurriculumEntity>(
            predicate: #Predicate { $0.lessonId == lessonId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func getAllCurriculum() -> [CurriculumEntity] {
        let descriptor = FetchDescriptor<CurriculumEntity>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - User Progress DAO

    func insertUserProgress(_ entity: UserProgressEntity) {
        let compositeKey = entity.compositeKey
        let descriptor = FetchDescriptor<UserProgressEntity>(
            predicate: #Predicate { $0.compositeKey == compositeKey }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.exposure = entity.exposure
            existing.mastery = entity.mastery
            existing.clozeExposure = entity.clozeExposure
            existing.lastError = entity.lastError
            existing.fsrsData = entity.fsrsData
        } else {
            modelContext.insert(entity)
        }
    }

    func getUserProgress(senseId: String) -> UserProgressEntity? {
        let descriptor = FetchDescriptor<UserProgressEntity>(
            predicate: #Predicate { $0.senseId == senseId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func getMastery(senseId: String) -> Int {
        return getUserProgress(senseId: senseId)?.mastery ?? 0
    }

    // MARK: - Lesson Status DAO

    func insertLessonStatus(_ entity: LessonStatusEntity) {
        let lessonId = entity.lessonId
        let descriptor = FetchDescriptor<LessonStatusEntity>(
            predicate: #Predicate { $0.lessonId == lessonId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.titleEn = entity.titleEn
            existing.isCompleted = entity.isCompleted
            existing.mastery = entity.mastery
            existing.completionPercentage = entity.completionPercentage
            existing.orderIndex = entity.orderIndex
        } else {
            modelContext.insert(entity)
        }
    }

    func getLessonStatus(_ lessonId: String) -> LessonStatusEntity? {
        let descriptor = FetchDescriptor<LessonStatusEntity>(
            predicate: #Predicate { $0.lessonId == lessonId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func getAllLessonStatuses() -> [LessonStatusEntity] {
        let descriptor = FetchDescriptor<LessonStatusEntity>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Save

    func save() {
        try? modelContext.save()
    }
}
