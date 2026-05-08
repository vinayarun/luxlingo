import SwiftUI

// MARK: - Home Screen (port of HomeScreen composable)
struct HomeScreen: View {
    let units: [CourseUnit]
    let xp: Int
    let streak: Int
    let onLessonSelected: (String, String) -> Void
    
    @State private var showingInfo = false

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
                Button(action: { showingInfo = true }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title3)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(streak)")
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.luxGreen)
                        Text("\(xp)")
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                }
            }
        }
        .sheet(isPresented: $showingInfo) {
            MenuSheet(units: units, xp: xp, streak: streak)
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
                VStack(spacing: 0) {
                    Text("\(lesson.practicedWords)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                    Text("/\(lesson.totalWords)")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Unit Card
struct UnitCard: View {
    let unit: CourseUnit
    let onLessonSelected: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(unit.title)
                .font(.title2)
                .fontWeight(.bold)

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

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    private let tabs: [(label: String, icon: String)] = [
        ("How to Use",   "hand.tap.fill"),
        ("How It Works", "info.circle.fill"),
        ("My Progress",  "chart.bar.fill"),
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

                // ── Swipeable content ──────────────────────────────────────
                TabView(selection: $selectedTab) {
                    HowToUseScreen().tag(0)
                    ZipfsLawInfoScreen().tag(1)
                    StatsScreen(units: units, xp: xp, streak: streak).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
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
