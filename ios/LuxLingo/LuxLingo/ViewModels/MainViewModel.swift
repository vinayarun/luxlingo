import Foundation
import SwiftData

// MARK: - Main ViewModel (port of MainViewModel.kt)
@MainActor
@Observable
final class MainViewModel {
    var units: [CourseUnit] = []
    var bonusLessonInfos: [BonusLessonInfo] = []
    private let repository: ContentRepository

    init(repository: ContentRepository) {
        self.repository = repository
        loadUnits()
    }

    func loadUnits() {
        let statuses = repository.getAllLessonStatuses()
        let rawUnits = repository.getUnits()

        var modules: [CourseUnit] = []
        var currentLessons: [Lesson] = []
        var currentUnitIndex = 1
        let batchSize = 7

        for (index, unit) in rawUnits.enumerated() {
            let status = statuses.first { $0.lessonId == unit.id }
            let coreSenses = repository.getLessonCoreSenses(lessonId: unit.id)
            let luxWords = coreSenses.compactMap { repository.getVocabularyById(id: $0.surfaceId)?.wordText }.prefix(3)
            // Show English translations in the subtitle so beginners know what they're learning
            let enWords = coreSenses.prefix(4).compactMap { repository.getSense(senseId: $0.senseId)?.translations }
            let objective = enWords.isEmpty
                ? "Master the core vocabulary"
                : enWords.joined(separator: " · ")

            let numberStr = unit.title.replacingOccurrences(of: "Lesson ", with: "")
            let lessonInt = Int(numberStr) ?? 1
            let descriptiveTitle = lessonTitle(number: lessonInt, luxWords: Array(luxWords))
            
            // Zipf cumulative coverage (for stats page — not shown in the lesson circle)
            let lessonNumber = Int(unit.title.replacingOccurrences(of: "Lesson ", with: "")) ?? 1
            let coverage = min(85, Int(25.0 * log10(Double(max(1, lessonNumber * 7)))))

            // Real practice progress — only shown for lessons the user has actually started
            let totalWords = coreSenses.count
            let practicedWords = status != nil ? coreSenses.filter {
                repository.getSenseMastery(senseId: $0.senseId) > 2
            }.count : 0

            let lesson = Lesson(
                id: unit.id,
                title: descriptiveTitle,
                objective: objective,
                exercises: [],
                isCompleted: status?.isCompleted ?? false,
                coveragePercent: coverage,
                totalWords: totalWords,
                practicedWords: practicedWords
            )
            
            currentLessons.append(lesson)
            
            if currentLessons.count == batchSize || index == rawUnits.count - 1 {
                let moduleTitle = getModuleTitle(for: currentUnitIndex)
                modules.append(CourseUnit(id: "module_\(currentUnitIndex)", title: moduleTitle, lessons: currentLessons))
                currentLessons = []
                currentUnitIndex += 1
            }
        }
        
        self.units = modules

        // Load bonus lessons
        let rawBonus = repository.getBonusLessons()
        self.bonusLessonInfos = rawBonus.map { entity in
            BonusLessonInfo(
                id: entity.lessonId,
                titleEn: entity.titleEn,
                situationTag: entity.situationTag ?? "",
                sceneImage: entity.themeTag ?? "",   // sceneImage stored in themeTag for bonus
                unitIndex: entity.unitIndex,
                isUnlocked: repository.isBonusLessonUnlocked(unitIndex: entity.unitIndex)
            )
        }

        print("[LuxLingo] MainViewModel: Mapped \(rawUnits.count) lessons into \(modules.count) thematic units, \(self.bonusLessonInfos.count) bonus lessons")
    }
    
    // MARK: - Vocabulary & Review

    func vocabWords(for unit: CourseUnit) -> [VocabWord] {
        repository.getEncounteredVocab(for: unit.lessons.map { $0.id })
    }

    func allVocabWords() -> [VocabWord] {
        repository.getEncounteredVocab(for: units.flatMap { $0.lessons.map { $0.id } })
    }

    var reviewWordCount: Int { repository.reviewableWordCount() }

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
