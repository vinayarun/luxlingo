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
    let onLessonSelected:  (String, String) -> Void
    var reviewWordCount:   Int = 0
    var onReviewTapped:    (() -> Void)? = nil
    var getVocabForUnit:   ((CourseUnit) -> [VocabWord])? = nil
    var getAllVocab:        (() -> [VocabWord])? = nil
    var bonusLessons:      [BonusLessonInfo] = []
    
    @State private var showingInfo = false
    @State private var menuSelectedTab = 0

    private var overallCoverage: Int {
        units.flatMap { $0.lessons }
            .filter { $0.isCompleted }
            .map { $0.coveragePercent }
            .max() ?? 0
    }

    private func formatXP(_ value: Int) -> String {
        if value >= 1_000_000 { return "\(value / 1_000_000)M" }
        if value >= 1_000    { return String(format: "%.1fk", Double(value) / 1_000) }
        return "\(value)"
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Review card — shown when ≥ 5 words are in progress
                if reviewWordCount >= 5 {
                    ReviewCard(wordCount: reviewWordCount, onTap: { onReviewTapped?() })
                }

                ForEach(Array(units.enumerated()), id: \.element.id) { unitIdx, unit in
                    UnitCard(
                        unit: unit,
                        vocabWords: getVocabForUnit?(unit) ?? [],
                        bonusLesson: bonusLessons.first { $0.unitIndex == unitIdx },
                        onLessonSelected: onLessonSelected
                    )
                }
            }
            .padding(16)
        }
        .navigationTitle("LuxLingo")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { menuSelectedTab = 0; showingInfo = true }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title3)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { menuSelectedTab = 2; showingInfo = true }) {
                    HStack(spacing: 10) {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill").foregroundColor(.orange)
                            Text("\(streak)")
                        }
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").foregroundColor(.luxAmber)
                            Text(formatXP(xp))
                        }
                        if overallCoverage > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.luxGreen)
                                Text("\(overallCoverage)%")
                            }
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                }
            }
        }
        .sheet(isPresented: $showingInfo) {
            MenuSheet(units: units, xp: xp, streak: streak,
                      allVocab: getAllVocab?() ?? [],
                      selectedTab: $menuSelectedTab)
        }
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
            // Background track
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 4)

            // Progress arc
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    lesson.isCompleted ? Color.luxGreen : Color.accentColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: fraction)

            if lesson.isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.luxGreen)
            } else {
                Text("\(lesson.practicedWords)/\(lesson.totalWords)")
                    .font(.system(size: 10, weight: .semibold))
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
    var vocabWords:       [VocabWord] = []
    var bonusLesson:      BonusLessonInfo? = nil
    let onLessonSelected: (String, String) -> Void

    @State private var showVocab = false

    // Scene images assigned to units in order; cycles for units beyond the list.
    // UIImage(named:) returns nil silently for any scenes not yet in the asset catalog.
    private static let sceneNames: [String] = [
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

    private var sceneImage: UIImage? {
        guard !Self.sceneNames.isEmpty else { return nil }
        let name = Self.sceneNames[(unitIndex - 1) % Self.sceneNames.count]
        return UIImage(named: name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Scene banner — only shown when the asset exists; tap to browse unit vocab
            if let img = sceneImage {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 130)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Text(unit.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    // Vocab hint badge (top-right) — visible only when words are encountered
                    if !vocabWords.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "text.book.closed.fill")
                            Text("\(vocabWords.count)")
                        }
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.black.opacity(0.35))
                        .cornerRadius(8)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                .onTapGesture { if !vocabWords.isEmpty { showVocab = true } }
                .sheet(isPresented: $showVocab) {
                    VocabularySheet(
                        title:     unit.title,
                        sceneName: Self.sceneNames[(unitIndex - 1) % Self.sceneNames.count],
                        words:     vocabWords
                    )
                }
            }

            // Lesson list
            VStack(alignment: .leading, spacing: 8) {
                if sceneImage == nil {
                    Text(unit.title)
                        .font(.title2)
                        .fontWeight(.bold)
                }

                ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { index, lesson in
                    Button {
                        onLessonSelected(unit.id, lesson.id)
                    } label: {
                        HStack(spacing: 16) {
                            LessonProgressRing(lesson: lesson)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(lesson.title)
                                    .font(.callout).fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text(lesson.objective)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }

                    if index < unit.lessons.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }

                // Bonus lesson card — shown at the bottom of each unit
                if let bonus = bonusLesson {
                    Divider()
                        .padding(.leading, 0)
                    BonusLessonCard(bonus: bonus) {
                        onLessonSelected(unit.id, bonus.id)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let wordCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.luxAmber.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.luxAmber)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Review")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(wordCount) words in progress across your lessons")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Menu Sheet (hamburger modal)

struct MenuSheet: View {
    let units:    [CourseUnit]
    let xp:       Int
    let streak:   Int
    var allVocab: [VocabWord] = []
    @Binding var selectedTab: Int

    @Environment(\.dismiss) private var dismiss

    private struct TabItem { let label: String; let icon: String }
    private let tabs: [TabItem] = [
        TabItem(label: "How to Use",     icon: "hand.tap.fill"),
        TabItem(label: "Our Method",     icon: "atom"),
        TabItem(label: "My Progress",    icon: "chart.bar.fill"),
        TabItem(label: "Grammar Tips", icon: "book.pages"),
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
        case 2: StatsScreen(units: units, xp: xp, streak: streak, allVocab: allVocab)
        case 3: LanguageGuideScreen()
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
