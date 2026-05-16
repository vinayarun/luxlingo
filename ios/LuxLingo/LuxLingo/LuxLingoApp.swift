import SwiftUI
import SwiftData

@main
struct LuxLingoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            VocabularyEntity.self,
            SensesEntity.self,
            SentencesEntity.self,
            CurriculumEntity.self,
            UserProgressEntity.self,
            LessonStatusEntity.self,
            ArticleExerciseEntity.self
        ])
    }
}
