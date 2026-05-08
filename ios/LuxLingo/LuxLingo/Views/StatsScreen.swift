import SwiftUI
import Charts

struct StatsScreen: View {
    let units: [CourseUnit]
    let xp: Int
    let streak: Int

    private var allLessons: [Lesson] { units.flatMap { $0.lessons } }
    private var totalWords: Int     { allLessons.reduce(0) { $0 + $1.totalWords } }
    private var practicedWords: Int { allLessons.reduce(0) { $0 + $1.practicedWords } }
    private var completedLessons: Int { allLessons.filter { $0.isCompleted }.count }
    private var totalLessons: Int   { allLessons.count }

    private struct CurvePoint: Identifiable {
        let id: Int          // lesson number (1-based)
        let coverage: Double
        let isPracticed: Bool
    }

    private var curveData: [CurvePoint] {
        allLessons.enumerated().map { idx, lesson in
            CurvePoint(
                id: idx + 1,
                coverage: Double(lesson.coveragePercent),
                isPracticed: lesson.isCompleted
            )
        }
    }

    private var currentPosition: CurvePoint? {
        curveData.last { $0.isPracticed }
    }

    // Lessons up to and including the current position (achieved segment)
    private var achievedCurve: [CurvePoint] {
        guard let pos = currentPosition else { return [] }
        return curveData.filter { $0.id <= pos.id }
    }

    // Lessons from current position onward (potential segment — always includes full remainder)
    private var potentialCurve: [CurvePoint] {
        guard let pos = currentPosition else { return curveData }
        return curveData.filter { $0.id >= pos.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                chartSection
                if let pos = currentPosition { coverageCallout(pos) }
                statsGrid
            }
            .padding(16)
        }
    }

    // MARK: - Zipf chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vocabulary Coverage")
                .font(.headline)
            Text("Cumulative % of everyday Luxembourgish text your words cover")
                .font(.caption)
                .foregroundColor(.secondary)

            Chart {
                // ── Potential (future) segment — full curve in muted gray ──
                ForEach(potentialCurve) { pt in
                    AreaMark(
                        x: .value("Lesson", pt.id),
                        y: .value("Coverage", pt.coverage)
                    )
                    .foregroundStyle(Color(.systemGray4).opacity(0.25))
                    .interpolationMethod(.monotone)
                }
                ForEach(potentialCurve) { pt in
                    LineMark(
                        x: .value("Lesson", pt.id),
                        y: .value("Coverage", pt.coverage)
                    )
                    .foregroundStyle(Color(.systemGray3))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .interpolationMethod(.monotone)
                }

                // ── Achieved segment — green fill up to current lesson ──
                ForEach(achievedCurve) { pt in
                    AreaMark(
                        x: .value("Lesson", pt.id),
                        y: .value("Coverage", pt.coverage)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.luxGreen.opacity(0.35), Color.luxGreen.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)
                }
                ForEach(achievedCurve) { pt in
                    LineMark(
                        x: .value("Lesson", pt.id),
                        y: .value("Coverage", pt.coverage)
                    )
                    .foregroundStyle(Color.luxGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
                }

                // ── 80% threshold ──
                RuleMark(y: .value("Threshold", 80))
                    .foregroundStyle(Color.luxAmber.opacity(0.9))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Everyday conversation")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.luxAmber)
                            .padding(.trailing, 4)
                    }

                // ── "You" dot at the boundary ──
                if let pos = currentPosition {
                    PointMark(
                        x: .value("Lesson", pos.id),
                        y: .value("Coverage", pos.coverage)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(140)

                    PointMark(
                        x: .value("Lesson", pos.id),
                        y: .value("Coverage", pos.coverage)
                    )
                    .foregroundStyle(Color.luxGreen)
                    .symbolSize(55)
                    .annotation(position: .top) {
                        Text("You")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.luxGreen)
                    }
                }
            }
            .chartYScale(domain: 0...85)
            .chartYAxis {
                AxisMarks(values: [0, 20, 40, 60, 80]) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        if let v = val.as(Int.self) {
                            Text("\(v)%").font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: Double(max(1, totalLessons / 6)))) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        if let v = val.as(Int.self) {
                            Text("L\(v)").font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 220)
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Coverage callout

    private func coverageCallout(_ pos: CurvePoint) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundColor(.luxGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your words cover \(Int(pos.coverage))% of everyday Luxembourgish text")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Based on Zipf's Law frequency analysis · Lesson \(pos.id) of \(totalLessons)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.luxGreen.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Progress")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    label: "Words Practiced",
                    value: "\(practicedWords) / \(totalWords)",
                    icon: "text.book.closed.fill",
                    color: .luxGreen
                )
                StatCard(
                    label: "Lessons Completed",
                    value: "\(completedLessons) / \(totalLessons)",
                    icon: "checkmark.seal.fill",
                    color: .accentColor
                )
                StatCard(
                    label: "XP Earned",
                    value: "\(xp)",
                    icon: "star.fill",
                    color: .luxAmber
                )
                StatCard(
                    label: "Day Streak",
                    value: "\(streak)",
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
