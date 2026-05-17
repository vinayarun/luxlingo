import Foundation
import SwiftData

// MARK: - Main ViewModel (port of MainViewModel.kt)
@MainActor
@Observable
final class MainViewModel {
    var units: [CourseUnit] = []
    var bonusLessonInfos: [BonusLessonInfo] = []
    var cachedAllVocab: [VocabWord] = []
    var cachedReviewWordCount: Int = 0
    private let repository: ContentRepository

    init(repository: ContentRepository) {
        self.repository = repository
        // Defer to the next event loop tick so the splash animation gets its
        // first render before any DB work starts.
        Task { @MainActor [weak self] in self?.loadUnits() }
    }

    func loadUnits() {
        // ── 5 bulk DB queries — everything else is pure in-memory ─────────────
        let allCurriculum = repository.getAllCurriculumRaw()   // all lessons incl. bonus
        let allSenses     = repository.getAllSensesMap()        // senseId  → SensesEntity
        let allVocab      = repository.getAllVocabMap()         // surfaceId → VocabularyEntity
        let allProgress   = repository.getAllProgressMap()      // senseId  → mastery Int
        let allStatuses   = repository.getAllLessonStatuses()   // lessonId → LessonStatusEntity

        let statusMap = Dictionary(uniqueKeysWithValues: allStatuses.map { ($0.lessonId, $0) })

        // Build lessonId → [SensesEntity] entirely in memory (no per-lesson queries)
        let curriculumSensesMap: [String: [SensesEntity]] = Dictionary(
            uniqueKeysWithValues: allCurriculum.map { curr in
                let ids = curr.coreSenses.split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                return (curr.lessonId, ids.compactMap { allSenses[$0] })
            }
        )

        // ── Build course modules (core lessons only) ───────────────────────────
        let coreCurriculum = allCurriculum.filter { $0.lessonType == "core" }
        var modules: [CourseUnit] = []
        var currentLessons: [Lesson] = []
        var currentUnitIndex = 1
        let batchSize = 7

        for (index, curr) in coreCurriculum.enumerated() {
            let coreSenses = curriculumSensesMap[curr.lessonId] ?? []
            let status     = statusMap[curr.lessonId]

            let luxWords = coreSenses.prefix(3).compactMap { allVocab[$0.surfaceId]?.wordText }
            let enWords  = coreSenses.prefix(4).compactMap { allSenses[$0.senseId]?.translations }
            let objective = enWords.isEmpty ? "Master the core vocabulary" : enWords.joined(separator: " · ")

            let lessonNumber = Int(curr.titleEn.replacingOccurrences(of: "Lesson ", with: "")) ?? 1
            let coverage     = min(85, Int(25.0 * log10(Double(max(1, lessonNumber * 7)))))
            let practicedWords = status?.hasStarted == true
                ? coreSenses.filter { (allProgress[$0.senseId] ?? 0) > 2 }.count : 0

            currentLessons.append(Lesson(
                id: curr.lessonId,
                title: lessonTitle(number: lessonNumber, luxWords: Array(luxWords)),
                objective: objective,
                exercises: [],
                isCompleted: status?.isCompleted ?? false,
                coveragePercent: coverage,
                totalWords: coreSenses.count,
                practicedWords: practicedWords
            ))

            if currentLessons.count == batchSize || index == coreCurriculum.count - 1 {
                modules.append(CourseUnit(id: "module_\(currentUnitIndex)",
                                          title: getModuleTitle(for: currentUnitIndex),
                                          lessons: currentLessons))
                currentLessons = []
                currentUnitIndex += 1
            }
        }
        self.units = modules

        // ── Bonus lessons ──────────────────────────────────────────────────────
        let bonusCurriculum = allCurriculum.filter { $0.lessonType == "bonus" }
        self.bonusLessonInfos = bonusCurriculum.map { entity in
            BonusLessonInfo(
                id: entity.lessonId,
                titleEn: entity.titleEn,
                situationTag: entity.situationTag ?? "",
                sceneImage: entity.themeTag ?? "",
                unitIndex: entity.unitIndex,
                isUnlocked: repository.isBonusLessonUnlocked(unitIndex: entity.unitIndex)
            )
        }

        // ── Vocab cache — built entirely in memory, no sentence queries ────────
        var vocabResult: [VocabWord] = []
        var seen = Set<String>()
        for curr in coreCurriculum {
            for sense in curriculumSensesMap[curr.lessonId] ?? [] {
                guard !seen.contains(sense.senseId) else { continue }
                seen.insert(sense.senseId)
                let mastery = allProgress[sense.senseId] ?? 0
                guard mastery > 0, let vocab = allVocab[sense.surfaceId] else { continue }
                vocabResult.append(VocabWord(
                    senseId:     sense.senseId,
                    wordLu:      vocab.wordText,
                    primaryEn:   sense.translations,
                    exampleLu:   "",   // sentence lookup removed — avoids selection algorithm
                    exampleEn:   "",
                    mastery:     mastery,
                    lodAudioUrl: vocab.lodAudioUrl
                ))
            }
        }
        self.cachedAllVocab = vocabResult.sorted {
            $0.wordLu.localizedCaseInsensitiveCompare($1.wordLu) == .orderedAscending
        }
        self.cachedReviewWordCount = allProgress.values.filter { $0 > 0 }.count

        print("[LuxLingo] loadUnits: \(coreCurriculum.count) lessons → \(modules.count) units (5 DB queries)")
    }
    
    // MARK: - Vocabulary & Review

    func vocabWords(for unit: CourseUnit) -> [VocabWord] {
        repository.getEncounteredVocab(for: unit.lessons.map { $0.id })
    }

    func allVocabWords() -> [VocabWord] { cachedAllVocab }

    var reviewWordCount: Int { cachedReviewWordCount }

    private func lessonTitle(number: Int, luxWords: [String]) -> String {
        // Fixed thematic names for the first 20 lessons (most studied)
        let named: [Int: String] = [
            1:  "Lesson 1 — I, Be & Have",
            2:  "Lesson 2 — And, For & In",
            3:  "Lesson 3 — This, That & On",
            4:  "Lesson 4 — Not, With & When",
            5:  "Lesson 5 — People & Names",
            6:  "Lesson 6 — Time & Place",
            7:  "Lesson 7 — Questions & Answers",
            8:  "Lesson 8 — Actions & Doing",
            9:  "Lesson 9 — Home & Family",
            10: "Lesson 10 — Numbers & Quantity",
            11: "Lesson 11 — Food & Drink",
            12: "Lesson 12 — Moving Around",
            13: "Lesson 13 — Describing Things",
            14: "Lesson 14 — Feelings & Moods",
            15: "Lesson 15 — Nature & Weather",
            16: "Lesson 16 — School & Work",
            17: "Lesson 17 — Shopping & Money",
            18: "Lesson 18 — Prepositions",
            19: "Lesson 19 — Joining Ideas",
            20: "Lesson 20 — Times of Day",
            21: "Lesson 21 — Before, Now & Again",
            22: "Lesson 22 — Here, There & Everywhere",
            23: "Lesson 23 — Together & Alone",
            24: "Lesson 24 — Maybe & Perhaps",
            25: "Lesson 25 — Often & Finally",
            26: "Lesson 26 — Around the House",
            27: "Lesson 27 — Getting Around",
            28: "Lesson 28 — Nature & Landscape",
            29: "Lesson 29 — Weather & Family",
            30: "Lesson 30 — People & Emotions",
            31: "Lesson 31 — Body & Mind",
            32: "Lesson 32 — Body & Health",
            33: "Lesson 33 — Food & Drink Basics",
            34: "Lesson 34 — Fruit & Sweetness",
            35: "Lesson 35 — Meals & Hunger",
            36: "Lesson 36 — School & Class",
            37: "Lesson 37 — Reading & Numbers",
            38: "Lesson 38 — Counting Higher",
            39: "Lesson 39 — More Colours",
            40: "Lesson 40 — Energy & Nature",
            41: "Lesson 41 — Animals",
            42: "Lesson 42 — Clothes & Style",
            43: "Lesson 43 — Art, Music & Play",
            44: "Lesson 44 — Light & Fire",
            45: "Lesson 45 — Shapes & Forms",
            46: "Lesson 46 — Senses & Dimensions",
            47: "Lesson 47 — Goals & Mistakes",
            48: "Lesson 48 — Peace & Freedom",
            49: "Lesson 49 — Culture & Science",
            50: "Lesson 50 — Society & Citizenship",
            51: "Lesson 51 — Help & the Future",
            52: "Lesson 52 — Degree & Certainty",
            53: "Lesson 53 — New & Next",
            54: "Lesson 54 — Directions",
            55: "Lesson 55 — Places & Emphasis",
            56: "Lesson 56 — Intensity Words",
            57: "Lesson 57 — Still & Already",
            58: "Lesson 58 — Time Words",
            59: "Lesson 59 — Right Now",
            60: "Lesson 60 — Core Prepositions",
            61: "Lesson 61 — Spatial Prepositions",
            62: "Lesson 62 — Time Connectors",
            63: "Lesson 63 — Also & Even",
            64: "Lesson 64 — Certainty & Doubt",
            65: "Lesson 65 — Verbs & Pronouns",
            66: "Lesson 66 — Object Pronouns",
            67: "Lesson 67 — Possessives & This",
            68: "Lesson 68 — Who & What",
            69: "Lesson 69 — Quantity & Emphasis",
            70: "Lesson 70 — Confidence Words",
        ]
        if let fixed = named[number] { return fixed }
        // For lessons beyond the named map use the first Luxembourgish word as a light hint
        let hint = luxWords.first.map { " · \($0)" } ?? ""
        return "Lesson \(number)\(hint)"
    }

    private func getModuleTitle(for index: Int) -> String {
        switch index {
        case 1: return "Unit 1: The Bare Essentials"
        case 2: return "Unit 2: Moving Through the World"
        case 3: return "Unit 3: People & Places"
        case 4: return "Unit 4: Descriptive Language"
        case 5: return "Unit 5: The Physical World"
        case 6: return "Unit 6: Thoughts & Concepts"
        case 7: return "Unit 7: Time & Anchors"
        case 8: return "Unit 8: Expressing Details"
        case 9: return "Unit 9: Connecting Ideas"
        case 10: return "Unit 10: Deeper Meanings"
        default: return "Unit \(index): Expanded Vocabulary"
        }
    }
}
