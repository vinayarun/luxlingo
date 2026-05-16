import SwiftUI
import Charts

struct StatsScreen: View {
    let units:      [CourseUnit]
    let xp:         Int
    let streak:     Int
    var allVocab:   [VocabWord] = []   // all encountered words across all lessons

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
                if !allVocab.isEmpty { vocabularySection }
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

// MARK: - Vocabulary section (embedded in My Progress)

extension StatsScreen {
    var vocabularySection: some View {
        VocabularyListContent(title: "My Vocabulary", words: allVocab)
    }
}

// MARK: - Vocabulary Sheet (presented as a sheet from UnitCard)

struct VocabularySheet: View {
    let title:     String
    let sceneName: String?
    let words:     [VocabWord]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Scene banner header
                if let name = sceneName, let img = UIImage(named: name) {
                    ZStack(alignment: .bottomLeading) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .clipped()
                        LinearGradient(colors: [.clear, .black.opacity(0.55)],
                                       startPoint: .top, endPoint: .bottom)
                        Text(title)
                            .font(.title3).fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.bottom, 10)
                    }
                }
                VocabularyListContent(title: title, words: words)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Shared vocabulary list (used by both StatsScreen and VocabularySheet)

struct VocabularyListContent: View {
    let title: String
    let words: [VocabWord]
    @State private var filter: VocabFilter = .all

    enum VocabFilter: String, CaseIterable {
        case all = "All", inProgress = "In Progress", mastered = "Mastered"
    }

    private var filtered: [VocabWord] {
        switch filter {
        case .all:        return words
        case .inProgress: return words.filter { $0.mastery < 20 }
        case .mastered:   return words.filter { $0.mastery >= 20 }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(words.count) words encountered")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 6)

            Picker("Filter", selection: $filter) {
                ForEach(VocabFilter.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.bottom, 10)

            if filtered.isEmpty {
                Text(filter == .mastered ? "No mastered words yet." : "No words in progress.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(32)
            } else {
                // Use a plain list so it works both in a sheet and embedded in a ScrollView
                VStack(spacing: 0) {
                    ForEach(filtered) { word in
                        VocabWordRow(word: word)
                        if word.id != filtered.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                .padding(.horizontal, 16)
            }

            Spacer(minLength: 12)
        }
    }
}

struct VocabWordRow: View {
    let word: VocabWord

    private var masteryFraction: Double {
        Double(min(word.mastery, 20)) / 20.0
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Speaker / audio
            SpeakerButton(text: word.wordLu, audioUrl: word.lodAudioUrl)
                .font(.callout)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(word.wordLu)
                        .font(.subheadline).fontWeight(.semibold)
                    Text(word.primaryEn)
                        .font(.caption).foregroundColor(.secondary)
                }
                if !word.exampleLu.isEmpty {
                    Text(word.exampleLu)
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // Mastery ring
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: masteryFraction)
                    .stroke(word.mastery >= 20 ? Color.luxGreen : Color.accentColor,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if word.mastery >= 20 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.luxGreen)
                }
            }
            .frame(width: 28, height: 28)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
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
