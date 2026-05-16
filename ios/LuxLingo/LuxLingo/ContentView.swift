import SwiftUI
import SwiftData

// MARK: - Navigation Routes
enum AppRoute: Hashable {
    case exercise(lessonId: String)
    case review
}

// MARK: - Content View
struct ContentView: View {
    @State private var navigationPath   = NavigationPath()
    @Environment(\.modelContext) private var modelContext

    @State private var repository:    ContentRepository?
    @State private var mainViewModel: MainViewModel?
    @StateObject private var userPreferences = UserPreferences()

    // Splash always plays for 2.5 s regardless of seed speed.
    // Seeding runs concurrently via .task; both must finish before home screen appears.
    @State private var splashDone = false

    var body: some View {
        Group {
            if !splashDone {
                // Always show the splash for the full 2.5 s
                SplashScreen { splashDone = true }
            } else if let vm = mainViewModel {
                NavigationStack(path: $navigationPath) {
                    HomeScreen(
                        units:  vm.units,
                        xp:     userPreferences.xp,
                        streak: userPreferences.streak,
                        onLessonSelected: { _, lessonId in
                            navigationPath.append(AppRoute.exercise(lessonId: lessonId))
                        },
                        reviewWordCount: vm.reviewWordCount,
                        onReviewTapped:  { navigationPath.append(AppRoute.review) },
                        getVocabForUnit: { unit in vm.vocabWords(for: unit) },
                        getAllVocab:      { vm.allVocabWords() },
                        bonusLessons:    vm.bonusLessonInfos
                    )
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
                        case .review:
                            if let repo = repository {
                                ExerciseScreenHost(
                                    lessonId: "review_session",
                                    repository: repo,
                                    onBack: {
                                        navigationPath.removeLast()
                                        mainViewModel?.loadUnits()
                                    },
                                    isReviewSession: true
                                )
                            }
                        }
                    }
                }
            } else {
                // Seeding still running after splash ends (first install only)
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.4)
                    Text("Almost ready…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            guard repository == nil else { return }
            let db   = DatabaseManager(modelContext: modelContext)
            let repo = ContentRepository(db: db)
            repository = repo
            await repo.seedIfNeeded()
            mainViewModel = MainViewModel(repository: repo)
        }
    }
}

// MARK: - Splash Screen
// Runs a 2.5 s Ken Burns animation over the aerial village scene.
// Tap anywhere to skip to a plain spinner (seeding continues in background).

struct SplashScreen: View {
    let onComplete: () -> Void

    @State private var showScene = true
    @State private var opacity:  Double  = 0
    @State private var xOffset:  CGFloat
    private let panEnd:          CGFloat

    private static let duration: Double = 2.5
    private static let fadeIn:   Double = 0.45
    private static let fadeOut:  Double = 0.45

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        let (start, end) = Self.randomSegment(imageAspect: 2.0)   // scene_village_aerial is 1024×512
        _xOffset = State(initialValue: start)
        panEnd   = end
    }

    // Divide the image into 3 equal horizontal segments, pick one at random,
    // then pan a short distance within that segment.
    private static func randomSegment(imageAspect: CGFloat) -> (CGFloat, CGFloat) {
        let screen   = UIScreen.main.bounds
        let scaled   = screen.height * imageAspect          // width when filling screen height
        let overflow = max(0, (scaled - screen.width) / 2)  // hidden pixels each side

        let safe      = overflow * 0.90                      // 10% margin from edge
        let positions: [CGFloat] = [safe, 0, -safe]          // left / centre / right
        let idx   = Int.random(in: 0..<positions.count)
        let start = positions[idx]

        let panRange = overflow * 0.28
        let rawEnd: CGFloat
        switch idx {
        case 0:  rawEnd = start - panRange
        case 2:  rawEnd = start + panRange
        default: rawEnd = start + (Bool.random() ? panRange : -panRange)
        }
        let end = min(safe, max(-safe, rawEnd))             // clamp within safe bounds
        return (start, end)
    }

    var body: some View {
        ZStack {
            if showScene, let img = UIImage(named: "scene_village_aerial") {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .offset(x: xOffset)
                    .ignoresSafeArea()
                    .clipped()
                Color.black.opacity(0.35).ignoresSafeArea()
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }

            VStack(spacing: 20) {
                Spacer()
                Text("LuxLingo")
                    .font(.largeTitle).fontWeight(.bold)
                    .foregroundColor(showScene ? .white : .primary)
                if !showScene {
                    ProgressView().tint(nil).scaleEffect(1.3)
                }
                Text("Preparing your village…")
                    .font(.subheadline)
                    .foregroundColor(showScene ? .white.opacity(0.85) : .secondary)
                Spacer()
            }
        }
        .opacity(opacity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.25)) { showScene = false }
        }
        .onAppear {
            withAnimation(.easeIn(duration: Self.fadeIn))        { opacity = 1 }
            withAnimation(.linear(duration: Self.duration))      { xOffset = panEnd }

            let fadeStart = Self.duration - Self.fadeOut
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeStart) {
                withAnimation(.easeOut(duration: Self.fadeOut))  { opacity = 0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration) {
                onComplete()
            }
        }
    }
}

// MARK: - Exercise Screen Host
// Prevents the ViewModel from being recreated on every NavigationStack re-render.
// Pan values are plain `let` properties computed at init time so SwiftUI cannot
// cache or overwrite them between lesson navigations.

struct ExerciseScreenHost: View {
    let lessonId:         String
    let repository:       ContentRepository
    let onBack:           () -> Void
    var onLessonComplete: ((Int) -> Void)? = nil

    // Segment (0=left, 1=centre, 2=right) and pan direction picked once per lesson.
    // Pixel offsets are computed inside LessonIntroOverlay from its actual frame size,
    // so there is no mismatch between what we computed here and what the view renders.
    private let introSegment:    Int
    private let introPanForward: Bool

    @State private var viewModel:             ExerciseViewModel?
    @State private var didFireCompletion    = false
    @State private var showIntro            = true
    @State private var showingReviewIntro   = true   // only relevant when isReviewSession

    private static let sceneNames: [String] = [
        "scene_classroom",    "scene_cycling_path",  "scene_village_entry", "scene_village_park",
        "scene_village_river","scene_library",        "scene_kitchen_evening","scene_cafe_bakery",
        "scene_garden_fence", "scene_school_morning", "scene_village_market","scene_doctors_office",
        "scene_sports_hall",  "scene_train_station",  "scene_river_winter",  "scene_church_square",
        "scene_school_playground","scene_bus_stop",   "scene_village_street","scene_river_swimming",
        "scene_winter_street",
    ]

    var isReviewSession: Bool = false

    init(
        lessonId: String,
        repository: ContentRepository,
        onBack: @escaping () -> Void,
        onLessonComplete: ((Int) -> Void)? = nil,
        isReviewSession: Bool = false
    ) {
        self.lessonId         = lessonId
        self.repository       = repository
        self.onBack           = onBack
        self.onLessonComplete = onLessonComplete
        self.isReviewSession  = isReviewSession
        _viewModel            = State(initialValue: nil)
        _didFireCompletion    = State(initialValue: false)
        _showIntro            = State(initialValue: !isReviewSession) // no intro animation for review
        introSegment          = Int.random(in: 0..<3)
        introPanForward       = Bool.random()
    }

    private var introSceneName: String {
        let num = Int(lessonId.replacingOccurrences(of: "lesson_", with: "")) ?? 1
        return Self.sceneNames[((num - 1) / 7) % Self.sceneNames.count]
    }

    var body: some View {
        ZStack {
            if isReviewSession && showingReviewIntro {
                // Review intro — show word list before exercises begin
                if let vm = viewModel {
                    ReviewIntroScreen(words: vm.reviewWordPreviews) {
                        showingReviewIntro = false
                    }
                } else {
                    // Still loading the review queue
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Building your review…")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .onAppear {
                        if viewModel == nil {
                            viewModel = ExerciseViewModel.forReview(repository: repository)
                        }
                    }
                }
            } else if let vm = viewModel {
                ExerciseScreen(
                    viewModel:    vm,
                    introVisible: showIntro,
                    onBack: {
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

            if showIntro {
                LessonIntroOverlay(
                    sceneName:    introSceneName,
                    segmentIndex: introSegment,
                    panForward:   introPanForward,
                    onDone:       { showIntro = false }
                )
            }
        }
    }
}

// MARK: - Lesson Intro Overlay (Ken Burns fade-in pan)
// Segment index and pan direction are chosen by the parent at init time (fresh per lesson).
// Pixel offsets are computed here from GeometryReader's actual frame — no overshoot
// from size mismatch. Because opacity starts at 0, positioning xOffset before the
// fade-in begins is invisible.

struct LessonIntroOverlay: View {
    let sceneName:    String
    let segmentIndex: Int    // 0 = left third, 1 = centre, 2 = right third
    let panForward:   Bool   // for centre segment: true = pan right in frame
    let onDone:       () -> Void

    @State private var opacity: Double  = 0
    @State private var xOffset: CGFloat = 0
    @State private var panEnd:  CGFloat = 0

    private static let totalDuration: Double = 2.5
    private static let fadeIn:        Double = 0.4
    private static let fadeOut:       Double = 0.45

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let img = UIImage(named: sceneName) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .offset(x: xOffset)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Color(.systemBackground)
                }
                Color.black.opacity(0.22)
            }
            .opacity(opacity)
            .onAppear {
                // Compute overflow from the real rendered frame — eliminates overshoot
                let img      = UIImage(named: sceneName)
                let nat      = img?.size ?? CGSize(width: 1024, height: 512)
                let scale    = max(geo.size.height / nat.height, geo.size.width / nat.width)
                let overflow = max(0, (nat.width * scale - geo.size.width) / 2)

                // 90% of overflow keeps the image safely away from its own edges
                let safe     = overflow * 0.90
                let positions: [CGFloat] = [safe, 0, -safe]   // left / centre / right
                let start    = positions[min(segmentIndex, 2)]

                // Pan within the segment; clamped to stay within safe bounds
                let panRange = overflow * 0.28
                let rawEnd: CGFloat
                switch segmentIndex {
                case 0:  rawEnd = start - panRange                          // left → slide right
                case 2:  rawEnd = start + panRange                          // right → slide left
                default: rawEnd = start + (panForward ? panRange : -panRange)
                }
                let end = min(safe, max(-safe, rawEnd))

                // Phase 1: position without animation (opacity is 0, invisible)
                xOffset = start
                panEnd  = end

                // Phase 2: after one render cycle start animations
                DispatchQueue.main.async {
                    withAnimation(.easeIn(duration: Self.fadeIn))        { opacity = 1 }
                    withAnimation(.linear(duration: Self.totalDuration)) { xOffset = panEnd }

                    let fadeStart = Self.totalDuration - Self.fadeOut
                    DispatchQueue.main.asyncAfter(deadline: .now() + fadeStart) {
                        withAnimation(.easeOut(duration: Self.fadeOut)) { opacity = 0 }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + Self.totalDuration) {
                        onDone()
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Review Intro Screen
// Shown before review exercises start — gives the learner a moment to see
// which words are in this session before diving into practice.

struct ReviewIntroScreen: View {
    let words:   [VocabWord]
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // Header
            VStack(spacing: 6) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.luxAmber)
                    .padding(.top, 24)
                Text("Review Session")
                    .font(.title2).fontWeight(.bold)
                Text("\(words.count) words from your lessons")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)

            Divider()

            // Word list — LU word left, EN meaning right
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(words) { word in
                        HStack(spacing: 12) {
                            SpeakerButton(text: word.wordLu, audioUrl: word.lodAudioUrl)
                                .font(.callout)
                                .frame(width: 28, height: 28)
                                .background(Color.accentColor.opacity(0.08))
                                .clipShape(Circle())

                            Text(word.wordLu)
                                .font(.subheadline).fontWeight(.semibold)
                                .frame(width: 110, alignment: .leading)

                            Text(word.primaryEn)
                                .font(.subheadline).foregroundColor(.secondary)
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            // Mastery dot
                            Circle()
                                .fill(word.mastery >= 20 ? Color.luxGreen : Color.accentColor)
                                .opacity(0.7)
                                .frame(width: 8, height: 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)

                        if word.id != words.last?.id {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
            }

            Divider()

            // Start button
            Button(action: onStart) {
                Text("Start Practice")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.luxAmber)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(16)
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}
