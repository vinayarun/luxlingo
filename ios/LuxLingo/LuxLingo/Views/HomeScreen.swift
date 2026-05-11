import SwiftUI

// MARK: - Home Screen (port of HomeScreen composable)
struct HomeScreen: View {
    let units: [CourseUnit]
    let xp: Int
    let streak: Int
    let onLessonSelected: (String, String) -> Void
    
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
                ForEach(units) { unit in
                    UnitCard(unit: unit, onLessonSelected: onLessonSelected)
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
            MenuSheet(units: units, xp: xp, streak: streak, selectedTab: $menuSelectedTab)
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

// MARK: - Unit Card
struct UnitCard: View {
    let unit: CourseUnit
    let onLessonSelected: (String, String) -> Void

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

            // Scene banner — only shown when the asset exists
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
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
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
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Menu Sheet (hamburger modal)

struct MenuSheet: View {
    let units: [CourseUnit]
    let xp: Int
    let streak: Int
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
                Group {
                    switch selectedTab {
                    case 1: ZipfsLawInfoScreen()
                    case 2: StatsScreen(units: units, xp: xp, streak: streak)
                    case 3: LanguageGuideScreen()
                    default: HowToUseScreen()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.18), value: selectedTab)
            }
            .navigationTitle(tabs[selectedTab].label)
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
}
