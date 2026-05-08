import SwiftUI
import SwiftData

// MARK: - Navigation Routes
enum AppRoute: Hashable {
    case exercise(lessonId: String)
}

// MARK: - Content View (replaces AppNavHost)
struct ContentView: View {
    @State private var navigationPath = NavigationPath()
    @Environment(\.modelContext) private var modelContext

    @State private var repository: ContentRepository?
    @State private var mainViewModel: MainViewModel?
    @StateObject private var userPreferences = UserPreferences()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let vm = mainViewModel {
                    HomeScreen(
                        units: vm.units,
                        xp: userPreferences.xp,
                        streak: userPreferences.streak,
                        onLessonSelected: { _, lessonId in
                            navigationPath.append(AppRoute.exercise(lessonId: lessonId))
                        }
                    )
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .exercise(let lessonId):
                    if let repo = repository {
                        ExerciseScreenHost(
                            lessonId: lessonId,
                            repository: repo,
                            onBack: {
                                navigationPath.removeLast()
                                mainViewModel?.loadUnits()
                            },
                            onLessonComplete: { sessionXP in
                                userPreferences.addXp(sessionXP)
                                userPreferences.updateStreak()
                            }
                        )
                    }
                }
            }
        }
        .onAppear {
            if repository == nil {
                let db = DatabaseManager(modelContext: modelContext)
                let repo = ContentRepository(db: db)
                repository = repo
                mainViewModel = MainViewModel(repository: repo)
            }
        }
    }
}

// MARK: - Exercise Screen Host
// Prevents the ViewModel from being recreated on every NavigationStack re-render
struct ExerciseScreenHost: View {
    let lessonId: String
    let repository: ContentRepository
    let onBack: () -> Void
    var onLessonComplete: ((Int) -> Void)? = nil

    @State private var viewModel: ExerciseViewModel?
    @State private var didFireCompletion = false

    var body: some View {
        Group {
            if let vm = viewModel {
                ExerciseScreen(
                    viewModel: vm,
                    onBack: {
                        // Fire completion callback once when the lesson is finished
                        if vm.uiState.isLessonFinished && !didFireCompletion {
                            didFireCompletion = true
                            onLessonComplete?(vm.uiState.sessionXP)
                        }
                        onBack()
                    }
                )
            } else {
                ProgressView()
                    .onAppear {
                        if viewModel == nil {
                            viewModel = ExerciseViewModel(lessonId: lessonId, repository: repository)
                        }
                    }
            }
        }
    }
}
