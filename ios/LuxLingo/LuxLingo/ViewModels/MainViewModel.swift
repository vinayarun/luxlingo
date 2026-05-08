import Foundation
import SwiftData

// MARK: - Main ViewModel (port of MainViewModel.kt)
@MainActor
@Observable
final class MainViewModel {
    var units: [CourseUnit] = []
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
            let objective = luxWords.isEmpty 
                ? "Master the core vocabulary" 
                : "Learn: \(luxWords.joined(separator: ", "))"

            var descriptiveTitle = unit.title
            if !luxWords.isEmpty {
                let numberStr = unit.title.replacingOccurrences(of: "Lesson ", with: "")
                let keyWord = luxWords.first?.capitalized ?? ""
                descriptiveTitle = "Essentials \(numberStr): The '\(keyWord)' Lesson"
            }
            
            // Zipf cumulative coverage (for stats page — not shown in the lesson circle)
            let lessonNumber = Int(unit.title.replacingOccurrences(of: "Lesson ", with: "")) ?? 1
            let coverage = min(85, Int(25.0 * log10(Double(max(1, lessonNumber * 7)))))

            // Real practice progress — only shown for lessons the user has actually started
            let totalWords = coreSenses.count
            let practicedWords = status != nil ? coreSenses.filter {
                repository.getSenseMastery(senseId: $0.senseId) > 0
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

        print("[LuxLingo] MainViewModel: Mapped \(rawUnits.count) lessons into \(modules.count) thematic units")
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
