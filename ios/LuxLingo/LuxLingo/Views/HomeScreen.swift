import SwiftUI

// MARK: - Bonus Lesson Info (passed from ContentView/MainViewModel)
struct BonusLessonInfo: Identifiable {
    let id: String          // lessonId
    let titleEn: String
    let situationTag: String
    let sceneImage: String
    let unitIndex: Int
    let isUnlocked: Bool
}

// MARK: - Home Screen (port of HomeScreen composable)
struct HomeScreen: View {
    let units:             [CourseUnit]
    let xp:                Int
    let streak:            Int
    let todayXp:           Int
    let onLessonSelected:  (String, String) -> Void
    var reviewWordCount:   Int = 0
    var onReviewTapped:    (() -> Void)? = nil
    var getVocabForUnit:   ((CourseUnit) -> [VocabWord])? = nil
    var bonusLessons:      [BonusLessonInfo] = []

    /// First lesson that isn't yet completed — used by TodayCard's Continue button.
    private var nextIncompleteLesson: (unitId: String, lessonId: String, title: String)? {
        for unit in units {
            for lesson in unit.lessons where !lesson.isCompleted {
                return (unit.id, lesson.id, lesson.title)
            }
        }
        return nil
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {

                // ── Today card ─────────────────────────────────────────────
                TodayCard(
                    streak: streak,
                    todayXp: todayXp,
                    nextLessonTitle: nextIncompleteLesson?.title
                ) {
                    if let next = nextIncompleteLesson {
                        onLessonSelected(next.unitId, next.lessonId)
                    }
                }

                // Review card — shown when ≥ 5 words are in progress
                if reviewWordCount >= 5 {
                    ReviewCard(wordCount: reviewWordCount, onTap: { onReviewTapped?() })
                }

                ForEach(Array(units.enumerated()), id: \.element.id) { unitIdx, unit in
                    UnitCard(
                        unit: unit,
                        vocabLoader: getVocabForUnit.map { loader in { loader(unit) } },
                        bonusLesson: bonusLessons.first { $0.unitIndex == unitIdx },
                        onLessonSelected: onLessonSelected,
                        isActive: nextIncompleteLesson?.unitId == unit.id
                    )
                }
            }
            .padding(16)
        }
        .navigationTitle("LuxLingo")
    }
}

// MARK: - Today Card

struct TodayCard: View {
    let streak:          Int
    let todayXp:         Int
    let nextLessonTitle: String?
    let onContinue:      () -> Void

    @AppStorage("luxlingo_daily_goal") private var goal: Int = 20
    private var fraction: Double { min(1.0, Double(todayXp) / Double(goal)) }
    private var goalMet:  Bool   { todayXp >= goal }
    private var goalTimeLabel: String {
        switch goal {
        case 10: return "~5 min daily goal"
        case 40: return "~15 min daily goal"
        default:  return "~10 min daily goal"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Stats row ──────────────────────────────────────────────────
            HStack(alignment: .center) {
                // Streak pill
                HStack(spacing: 6) {
                    Image(systemName: streak > 0 ? "flame.fill" : "flame")
                        .foregroundColor(streak > 0 ? .orange : .secondary)
                        .font(.system(size: 18, weight: .semibold))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(streak > 0 ? "\(streak)" : "0")
                            .font(.luxNumeric(size: 20))
                            .foregroundColor(streak > 0 ? .primary : .secondary)
                        Text(streak > 0 ? "day streak" : "Start today!")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Daily XP pill
                HStack(spacing: 6) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(goalMet ? "Goal reached!" : "\(todayXp) / \(goal) XP")
                            .font(.luxNumeric(size: 15, weight: .semibold))
                            .foregroundColor(goalMet ? .luxGreen : .primary)
                        Text(goalTimeLabel).font(.caption2).foregroundColor(.secondary)
                    }
                    Image(systemName: goalMet ? "checkmark.circle.fill" : "star.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(goalMet ? .luxGreen : .luxAmber)
                }
            }

            // ── XP progress bar ────────────────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: goalMet
                                    ? [Color.luxGreen, Color(red: 0.20, green: 0.75, blue: 0.10)]
                                    : [Color.luxGreen, Color(red: 0.30, green: 0.85, blue: 0.10)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(fraction)), height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: fraction)
                }
            }
            .frame(height: 8)

            // ── Continue CTA ───────────────────────────────────────────────
            if let title = nextLessonTitle {
                Button(action: onContinue) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Continue").font(.caption.weight(.medium)).foregroundColor(.white.opacity(0.8))
                            Text(title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: [Color.luxGreen, Color(red: 0.28, green: 0.75, blue: 0.05)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.luxGreen.opacity(0.30), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
            } else {
                // All lessons done
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.luxAmber)
                        .font(.system(size: 18))
                    Text("All lessons complete — amazing!")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 12, y: 3)
    }
}

// MARK: - Lesson Progress Ring

struct LessonProgressRing: View {
    let lesson: Lesson

    private var fraction: Double {
        guard lesson.totalWords > 0 else { return 0 }
        return Double(lesson.practicedWords) / Double(lesson.totalWords)
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 5)

            // Progress arc
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    lesson.isCompleted
                        ? LinearGradient(colors: [.luxGreen, Color(red: 0.28, green: 0.85, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.luxGreen.opacity(0.60), Color.luxGreen.opacity(0.40)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: fraction)

            if lesson.isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.luxGreen)
            } else if lesson.practicedWords > 0 {
                Text("\(lesson.practicedWords)/\(lesson.totalWords)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Bonus Lesson Card

struct BonusLessonCard: View {
    let bonus: BonusLessonInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: { if bonus.isUnlocked { onTap() } }) {
            HStack(spacing: 12) {
                ZStack {
                    if let img = UIImage(named: bonus.sceneImage) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 56)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.luxAmber.opacity(0.15))
                            .frame(width: 80, height: 56)
                    }
                    if !bonus.isUnlocked {
                        Color.black.opacity(0.45)
                            .cornerRadius(8)
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.luxAmber)
                        Text("Bonus")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.luxAmber)
                    }
                    Text("Bonus: \(bonus.titleEn)")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(bonus.isUnlocked ? .primary : .secondary)
                    if !bonus.isUnlocked {
                        Text("Complete 4 lessons to unlock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if bonus.isUnlocked {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(bonus.isUnlocked ? Color.luxAmber.opacity(0.08) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.luxAmber.opacity(bonus.isUnlocked ? 0.3 : 0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!bonus.isUnlocked)
    }
}

// MARK: - Unit Card
struct UnitCard: View {
    let unit:             CourseUnit
    var vocabLoader:      (() -> [VocabWord])? = nil
    var bonusLesson:      BonusLessonInfo? = nil
    let onLessonSelected: (String, String) -> Void
    var isActive:         Bool = false

    @State private var showOverview  = false
    @State private var loadedVocab:  [VocabWord] = []
    @State private var isExpanded:   Bool

    init(unit: CourseUnit,
         vocabLoader: (() -> [VocabWord])? = nil,
         bonusLesson: BonusLessonInfo? = nil,
         onLessonSelected: @escaping (String, String) -> Void,
         isActive: Bool = false) {
        self.unit             = unit
        self.vocabLoader      = vocabLoader
        self.bonusLesson      = bonusLesson
        self.onLessonSelected = onLessonSelected
        self.isActive         = isActive
        _isExpanded           = State(initialValue: isActive)
    }

    private var expandLabel: String {
        let completed = unit.lessons.filter { $0.isCompleted }.count
        let total     = unit.lessons.count
        if total == 0               { return "No lessons" }
        if completed == total       { return "All \(total) lessons complete" }
        if completed == 0           { return "\(total) lessons" }
        return "\(completed) of \(total) lessons complete"
    }

    private var encounteredCount: Int {
        unit.lessons.reduce(0) { $0 + $1.practicedWords }
    }

    static let sceneNames: [String] = [
        "scene_classroom",          // Unit 1
        "scene_cycling_path",       // Unit 2
        "scene_village_entry",      // Unit 3
        "scene_village_park",       // Unit 4
        "scene_village_river",      // Unit 5
        "scene_library",            // Unit 6
        "scene_kitchen_evening",    // Unit 7
        "scene_cafe_bakery",        // Unit 8
        "scene_garden_fence",       // Unit 9
        "scene_school_morning",     // Unit 10
        "scene_village_market",     // Unit 11
        "scene_doctors_office",     // Unit 12
        "scene_sports_hall",        // Unit 13
        "scene_train_station",      // Unit 14
        "scene_river_winter",       // Unit 15
        "scene_church_square",      // Unit 16
        "scene_school_playground",  // Unit 17
        "scene_bus_stop",           // Unit 18
        "scene_village_street",     // Unit 19
        "scene_river_swimming",     // Unit 20
        "scene_winter_street",      // Unit 21
    ]

    private var unitIndex: Int {
        Int(unit.id.replacingOccurrences(of: "module_", with: "")) ?? 1
    }

    private var sceneName: String {
        Self.sceneNames[(unitIndex - 1) % Self.sceneNames.count]
    }

    private var sceneImage: UIImage? { UIImage(named: sceneName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Scene banner — always tappable; opens unit overview sheet
            if let img = sceneImage {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()

                    // Deeper gradient for better text legibility
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.25), .black.opacity(0.68)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Text(unit.title)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)

                    // Word-count badge — top-right, only when words are encountered
                    if encounteredCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "text.book.closed.fill")
                            Text("\(encounteredCount)")
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if loadedVocab.isEmpty { loadedVocab = vocabLoader?() ?? [] }
                    showOverview = true
                }
                .sheet(isPresented: $showOverview) {
                    UnitOverviewSheet(
                        unit:           unit,
                        sceneName:      sceneName,
                        words:          loadedVocab,
                        onStartLesson:  onLessonSelected
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }

            // Expand/collapse row + lesson list
            VStack(alignment: .leading, spacing: 0) {
                if sceneImage == nil {
                    Text(unit.title)
                        .font(.title2).fontWeight(.bold)
                        .padding(.bottom, 8)
                }

                // Toggle row
                Button {
                    withAnimation(.luxSpring) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Text(expandLabel)
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2).foregroundColor(Color(.systemGray3))
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 10)

                if isExpanded {
                    Divider()

                    VStack(spacing: 0) {
                        ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { index, lesson in
                            Button {
                                LuxHaptic.selection()
                                onLessonSelected(unit.id, lesson.id)
                            } label: {
                                HStack(spacing: 14) {
                                    LessonProgressRing(lesson: lesson)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(lesson.title)
                                            .font(.callout.weight(.semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        let objectiveText = (!lesson.isCompleted && lesson.practicedWords == 0)
                                            ? "\(lesson.objective) · ~\(max(3, lesson.totalWords)) min"
                                            : lesson.objective
                                        Text(objectiveText)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1).truncationMode(.tail)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(Color(.systemGray3))
                                }
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < unit.lessons.count - 1 {
                                Divider().padding(.leading, 58)
                            }
                        }

                        if let bonus = bonusLesson {
                            Divider().padding(.leading, 0)
                            BonusLessonCard(bonus: bonus) {
                                onLessonSelected(unit.id, bonus.id)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.09), radius: 14, y: 4)
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let wordCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            LuxHaptic.selection()
            onTap()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.luxAmber.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.luxAmber)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Review")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(wordCount) words in progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(.systemGray3))
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.luxAmber.opacity(0.25), lineWidth: 1.5)
            )
            .shadow(color: Color.luxAmber.opacity(0.12), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Menu Sheet (hamburger modal)

struct MenuSheet: View {
    let units:    [CourseUnit]
    let xp:       Int
    let streak:   Int
    @Binding var selectedTab: Int

    @Environment(\.dismiss) private var dismiss

    private struct TabItem { let label: String; let icon: String }
    private let tabs: [TabItem] = [
        TabItem(label: "How to Use",   icon: "hand.tap.fill"),
        TabItem(label: "Our Method",   icon: "atom"),
        TabItem(label: "My Progress",  icon: "chart.bar.fill"),
        TabItem(label: "Grammar",      icon: "book.pages"),
        TabItem(label: "Characters",   icon: "person.3.fill"),
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ── Visible tab picker ─────────────────────────────────────
                HStack(spacing: 4) {
                    ForEach(tabs.indices, id: \.self) { i in
                        Button {
                            withAnimation(.luxSpring) { selectedTab = i }
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: tabs[i].icon)
                                    .font(.system(size: 15,
                                                  weight: selectedTab == i ? .semibold : .regular))
                                Text(tabs[i].label)
                                    .font(.caption2)
                                    .fontWeight(selectedTab == i ? .semibold : .regular)
                            }
                            .foregroundColor(selectedTab == i ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTab == i
                                          ? Color(.systemBackground)
                                          : Color.clear)
                                    .shadow(color: .black.opacity(selectedTab == i ? 0.07 : 0),
                                            radius: 3, y: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(5)
                .background(Color(.systemGray6))
                .cornerRadius(11)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                // ── Tab content ────────────────────────────────────────────
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.easeInOut(duration: 0.18), value: selectedTab)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                            .font(.title3)
                    }
                }
            }
        }
    }

    @ViewBuilder private var tabContent: some View {
        switch selectedTab {
        case 1: ZipfsLawInfoScreen()
        case 2: StatsScreen(units: units, xp: xp, streak: streak)
        case 3: LanguageGuideScreen()
        case 4: CharacterIntroScreen()
        default: HowToUseScreen()
        }
    }
}

// MARK: - Pronunciation Results Home Card

struct PronunciationResultsHomeCard: View {
    let results: [PronunciationResult]
    let onDismiss: () -> Void

    private var averageScore: Int {
        guard !results.isEmpty else { return 0 }
        return results.map(\.score).reduce(0, +) / results.count
    }

    private var scoreColor: Color {
        switch averageScore {
        case 80...: return .luxGreen
        case 50..<80: return .luxAmber
        default:     return .luxRed
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(scoreColor.opacity(0.12)).frame(width: 52, height: 52)
                Image(systemName: "mic.fill")
                    .font(.title2).foregroundColor(scoreColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Pronunciation results ready")
                    .font(.callout.weight(.semibold))
                Text("\(results.count) word\(results.count == 1 ? "" : "s") scored · avg \(averageScore)%")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(scoreColor.opacity(0.07))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(scoreColor.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Unit Overview Sheet

struct UnitOverviewSheet: View {
    let unit:          CourseUnit
    let sceneName:     String
    let words:         [VocabWord]
    let onStartLesson: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var vocabFilter: VocabFilter = .all

    enum VocabFilter: String, CaseIterable {
        case all = "All", inProgress = "In Progress", mastered = "Mastered"
    }

    // MARK: Computed

    private var unitNumber: Int {
        Int(unit.id.replacingOccurrences(of: "module_", with: "")) ?? 1
    }
    private var completedCount: Int { unit.lessons.filter { $0.isCompleted }.count }
    private var nextLesson: Lesson? { unit.lessons.first { !$0.isCompleted } }

    private var filteredWords: [VocabWord] {
        switch vocabFilter {
        case .all:        return words
        case .inProgress: return words.filter { $0.mastery > 0 && $0.mastery < 20 }
        case .mastered:   return words.filter { $0.mastery >= 20 }
        }
    }

    // Detect which story characters appear in practiced sentences for this unit.
    private var detectedCharacters: [(name: String, asset: String)] {
        let allText = words.flatMap { [$0.exampleLu, $0.exampleEn] }.joined(separator: " ")
        let cast: [(String, String)] = [
            ("Marc",   "character_marc"),
            ("Anna",   "character_anna"),
            ("Paul",   "character_paul"),
            ("Lena",   "character_lena"),
            ("Claire", "character_claire"),
            ("Natali", "character_natali"),
            ("Weiss",  "character_mr_weiss"),
            ("Bello",  "character_bello"),
        ]
        return cast.filter { name, _ in
            allText.range(of: "\\b\(name)\\b", options: .regularExpression) != nil
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            sceneHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    lessonsSection
                    let chars = detectedCharacters
                    if !chars.isEmpty {
                        Divider().padding(.horizontal, 20)
                        charactersSection(chars)
                    }
                    Divider().padding(.horizontal, 20)
                    ctaSection
                    Divider().padding(.horizontal, 20)
                    vocabularySection
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: Scene header

    private var sceneHeader: some View {
        ZStack(alignment: .bottom) {
            if let img = UIImage(named: sceneName) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.luxGreen.opacity(0.15))
                    .frame(height: 200)
            }
            LinearGradient(
                colors: [.clear, .black.opacity(0.70)],
                startPoint: .center, endPoint: .bottom
            )
            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Unit \(unitNumber)")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.white.opacity(0.18))
                        .cornerRadius(6)
                    Text(unit.title)
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(completedCount)/\(unit.lessons.count)")
                        .font(.title3).fontWeight(.bold).foregroundColor(.white)
                    Text("lessons done")
                        .font(.caption2).foregroundColor(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white, Color.black.opacity(0.45))
            }
            .padding(12)
        }
    }

    // MARK: Lessons section

    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Lessons")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { idx, lesson in
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onStartLesson(unit.id, lesson.id)
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(lesson.isCompleted
                                      ? Color.luxGreen
                                      : lesson.practicedWords > 0
                                          ? Color.luxAmber.opacity(0.18)
                                          : Color(.systemGray5))
                                .frame(width: 34, height: 34)
                            if lesson.isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.caption).fontWeight(.bold)
                                    .foregroundColor(.white)
                            } else if lesson.practicedWords > 0 {
                                Image(systemName: "arrow.right")
                                    .font(.caption2).fontWeight(.semibold)
                                    .foregroundColor(.luxAmber)
                            } else {
                                Text("\(idx + 1)")
                                    .font(.caption2).fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lesson.title)
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(
                                lesson.isCompleted      ? "Completed"
                                : lesson.practicedWords > 0 ? "\(lesson.practicedWords) words in progress"
                                : lesson.objective
                            )
                            .font(.caption)
                            .foregroundColor(lesson.isCompleted ? .luxGreen : .secondary)
                            .lineLimit(1)
                        }
                        Spacer()
                        if !lesson.isCompleted {
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if idx < unit.lessons.count - 1 {
                    Divider().padding(.leading, 68)
                }
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: Characters section

    private func charactersSection(_ chars: [(name: String, asset: String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Characters in this unit")
                .font(.headline)
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(chars, id: \.name) { name, asset in
                        VStack(spacing: 6) {
                            Group {
                                if let img = UIImage(named: asset) {
                                    Image(uiImage: img)
                                        .resizable().scaledToFill()
                                } else {
                                    Color(.systemGray4)
                                }
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.systemGray5), lineWidth: 1))
                            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)

                            Text(name == "Weiss" ? "Här Weiss" : name)
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: CTA

    private var ctaSection: some View {
        Group {
            if completedCount == unit.lessons.count && !unit.lessons.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3).foregroundColor(.luxGreen)
                    Text("Unit complete — keep practising below")
                        .font(.subheadline).foregroundColor(.luxGreen)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.luxGreen.opacity(0.08))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else if let lesson = nextLesson {
                let inProgress = lesson.practicedWords > 0
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onStartLesson(unit.id, lesson.id)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: inProgress ? "arrow.right.circle.fill" : "play.circle.fill")
                        Text(inProgress ? "Continue: \(lesson.title)" : "Start: \(lesson.title)")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(inProgress ? Color.luxAmber : Color.luxGreen)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: Vocabulary section

    private var vocabularySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(words.isEmpty ? "Vocabulary" : "\(words.count) words in this unit")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            if words.isEmpty {
                Text("Start your first lesson to see vocabulary here.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(.horizontal, 20).padding(.vertical, 8)
            } else {
                Picker("Filter", selection: $vocabFilter) {
                    ForEach(VocabFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                if filteredWords.isEmpty {
                    Text(vocabFilter == .mastered ? "No mastered words yet." : "No words in progress yet.")
                        .font(.subheadline).foregroundColor(.secondary)
                        .padding(.horizontal, 20).padding(.vertical, 24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(filteredWords) { word in
                            VocabWordRow(word: word)
                            if word.id != filteredWords.last?.id {
                                Divider().padding(.leading, 58)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}
