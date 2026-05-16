import SwiftUI
import Charts

// MARK: - Lesson / Review Summary Router

struct LessonSummaryScreen: View {
    let masteredSenses:  [String]
    var sessionXP:       Int  = 0
    var lessonNumber:    Int  = 0
    var isReviewSession: Bool = false
    let onBackToMenu:    () -> Void

    var body: some View {
        if isReviewSession {
            ReviewSummaryScreen(
                wordCount:    masteredSenses.count,
                sessionXP:    sessionXP,
                onBackToMenu: onBackToMenu
            )
        } else {
            LessonCompleteScreen(
                masteredSenses: masteredSenses,
                sessionXP:      sessionXP,
                lessonNumber:   lessonNumber,
                onBackToMenu:   onBackToMenu
            )
        }
    }
}

// MARK: - Lesson Complete Screen

private struct LessonCompleteScreen: View {
    let masteredSenses: [String]
    let sessionXP:      Int
    let lessonNumber:   Int
    let onBackToMenu:   () -> Void

    // Coverage before and after completing this lesson
    private var coverageBefore: Int { lessonCoverage(lessonNumber - 1) }
    private var coverageAfter:  Int { lessonCoverage(lessonNumber) }
    private var coverageGained: Int { coverageAfter - coverageBefore }

    private func lessonCoverage(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return min(85, Int(25.0 * log10(Double(max(1, n * 7)))))
    }

    // Scene image for the unit this lesson belongs to
    private static let sceneNames: [String] = [
        "scene_classroom", "scene_cycling_path", "scene_village_entry", "scene_village_park",
        "scene_village_river", "scene_library", "scene_kitchen_evening", "scene_cafe_bakery",
        "scene_garden_fence", "scene_school_morning", "scene_village_market", "scene_doctors_office",
        "scene_sports_hall", "scene_train_station", "scene_river_winter", "scene_church_square",
        "scene_school_playground", "scene_bus_stop", "scene_village_street", "scene_river_swimming",
        "scene_winter_street",
    ]
    private var sceneImage: UIImage? {
        guard lessonNumber > 0 else { return nil }
        let idx = ((lessonNumber - 1) / 7) % Self.sceneNames.count
        return UIImage(named: Self.sceneNames[idx])
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Hero banner ──────────────────────────────────────────────
                ZStack(alignment: .bottom) {
                    // Scene at higher opacity for visual richness
                    if let img = sceneImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: [.black.opacity(0.15), .black.opacity(0.65)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    } else {
                        Color.luxGreen.opacity(0.12).frame(height: 220)
                    }

                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.9))
                        Text("Lesson Complete!")
                            .font(.title).fontWeight(.bold)
                            .foregroundColor(.white)
                        if lessonNumber > 0 {
                            Text("Lesson \(lessonNumber)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                    .padding(.bottom, 24)
                }

                // ── Stats pills ──────────────────────────────────────────────
                HStack(spacing: 12) {
                    StatPill(icon: "star.fill",        value: "+\(sessionXP)",
                             label: "XP Earned",        color: .luxAmber)
                    StatPill(icon: "book.closed.fill",  value: "\(masteredSenses.count)",
                             label: "Words practiced",  color: .accentColor)
                    if coverageGained > 0 {
                        StatPill(icon: "chart.line.uptrend.xyaxis", value: "+\(coverageGained)%",
                                 label: "Coverage",    color: .luxGreen)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 4)

                // ── Mini Zipf progress chart ──────────────────────────────────
                if lessonNumber > 0 {
                    MiniCoverageChart(
                        lessonNumber:    lessonNumber,
                        coverageBefore:  coverageBefore,
                        coverageAfter:   coverageAfter
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                // ── Words practiced ───────────────────────────────────────────
                // LazyVGrid (not FlexWrap/GeometryReader) so ScrollView gets the
                // correct height and nothing below overlaps the chips.
                if !masteredSenses.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Words practiced")
                            .font(.headline)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 72, maximum: 180), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(masteredSenses, id: \.self) { sense in
                                Text(sense)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(20)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                // ── Pronunciation results (if available for this session) ─────
                let pronService = PronunciationService.shared
                let sessionResults = pronService.completedResults.suffix(3)  // show latest
                if !sessionResults.isEmpty || !pronService.pendingJobs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Pronunciation", systemImage: "mic.fill")
                            .font(.headline)

                        if pronService.pendingJobs.isEmpty {
                            ForEach(Array(sessionResults)) { result in
                                HStack {
                                    Text(result.targetWord)
                                        .font(.subheadline).fontWeight(.semibold)
                                    Spacer()
                                    Text("\(result.score)%")
                                        .font(.subheadline.bold())
                                        .foregroundColor(result.score >= 80 ? .luxGreen :
                                                         result.score >= 50 ? .luxAmber : .luxRed)
                                    Image(systemName: result.score >= 80 ? "checkmark.circle.fill" :
                                                     result.score >= 50 ? "minus.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.score >= 80 ? .luxGreen :
                                                         result.score >= 50 ? .luxAmber : .luxRed)
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.8)
                                Text("Score arriving shortly…")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                // Generous bottom padding so the last word chip is never behind the footer
                Spacer().frame(height: 100)
            }
        }
        .ignoresSafeArea(edges: .top)
        // Pinned footer — shadow on top edge, solid background, no gradient overlap
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: {
                PronunciationService.shared.markAllResultsViewed()
                onBackToMenu()
            }) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.luxGreen)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.08), radius: 8, y: -3)
        }
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let icon:  String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.title3).fontWeight(.bold)
            Text(label)
                .font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .cornerRadius(14)
    }
}

// MARK: - Mini Coverage Chart

private struct MiniCoverageChart: View {
    let lessonNumber:   Int
    let coverageBefore: Int
    let coverageAfter:  Int

    private struct CurvePoint: Identifiable {
        let id: Int; let coverage: Double
    }

    private var curveData: [CurvePoint] {
        let total = max(lessonNumber + 8, 20)
        return (1...total).map { n in
            CurvePoint(id: n, coverage: min(85, 25.0 * log10(Double(max(1, n * 7)))))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Vocabulary Coverage")
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    Label("Before", systemImage: "circle.fill")
                        .font(.caption2).foregroundColor(.accentColor)
                    Label("Now",    systemImage: "circle.fill")
                        .font(.caption2).foregroundColor(.luxGreen)
                }
            }

            Chart {
                // Gray potential curve
                ForEach(curveData) { pt in
                    LineMark(x: .value("Lesson", pt.id), y: .value("Coverage", pt.coverage))
                        .foregroundStyle(Color(.systemGray4))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .interpolationMethod(.monotone)
                }

                // Green achieved area up to current lesson
                ForEach(curveData.filter { $0.id <= lessonNumber }) { pt in
                    AreaMark(x: .value("Lesson", pt.id), y: .value("Coverage", pt.coverage))
                        .foregroundStyle(LinearGradient(
                            colors: [Color.luxGreen.opacity(0.3), Color.luxGreen.opacity(0.04)],
                            startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Lesson", pt.id), y: .value("Coverage", pt.coverage))
                        .foregroundStyle(Color.luxGreen)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.monotone)
                }

                // Blue dot — where you were before this lesson.
                // For lesson 1, plot at x=1 y=0 (starting point).
                let blueX = lessonNumber > 1 ? lessonNumber - 1 : lessonNumber
                let blueY = lessonNumber > 1 ? Double(coverageBefore) : 0.0
                PointMark(x: .value("Lesson", blueX),
                          y: .value("Coverage", blueY))
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(80)
                PointMark(x: .value("Lesson", blueX),
                          y: .value("Coverage", blueY))
                    .foregroundStyle(Color.white)
                    .symbolSize(25)

                // Green dot — where you are now
                PointMark(x: .value("Lesson", lessonNumber),
                          y: .value("Coverage", Double(coverageAfter)))
                    .foregroundStyle(Color.luxGreen)
                    .symbolSize(100)
                PointMark(x: .value("Lesson", lessonNumber),
                          y: .value("Coverage", Double(coverageAfter)))
                    .foregroundStyle(Color.white)
                    .symbolSize(30)
            }
            .frame(height: 140)
            .chartYScale(domain: 0...90)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75]) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color(.systemGray5))
                    AxisValueLabel {
                        if let v = val.as(Int.self) { Text("\(v)%").font(.caption2) }
                    }
                }
            }

            // Summary label
            HStack {
                Spacer()
                Text("Coverage: \(coverageBefore)%  →  \(coverageAfter)%")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}

// MARK: - FlexWrap (wrapping chip layout using ViewThatFits)

private struct FlexWrap<Item: Hashable, Content: View>: View {
    let items:   [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items   = items
        self.content = content
    }

    var body: some View {
        // Simple wrapping using a GeometryReader-based approach
        GeometryReader { geo in
            self.generateContent(in: geo)
        }
        .frame(minHeight: 32)
    }

    private func generateContent(in geo: GeometryProxy) -> some View {
        var width  = CGFloat.zero
        var height = CGFloat.zero
        var lastHeight = CGFloat.zero
        let spacing: CGFloat = 8

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(.all, 0)
                    .alignmentGuide(.leading) { d in
                        if (abs(width - d.width) > geo.size.width) {
                            width = 0; height -= (lastHeight + spacing)
                        }
                        let result = width
                        if item == items.last { width = 0 } else { width -= d.width + spacing }
                        return result
                    }
                    .alignmentGuide(.top) { d in
                        let result = height
                        lastHeight = d.height
                        if item == items.last { height = 0 }
                        return result
                    }
            }
        }
    }
}

// MARK: - Review Summary Screen

struct ReviewSummaryScreen: View {
    let wordCount:   Int
    let sessionXP:   Int
    let onBackToMenu: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.luxAmber.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.luxAmber)
            }

            // Heading
            VStack(spacing: 8) {
                Text("Review Complete!")
                    .font(.title).fontWeight(.bold)
                Text("You kept \(wordCount) words sharp")
                    .font(.subheadline).foregroundColor(.secondary)
            }

            // XP pill
            HStack(spacing: 6) {
                Image(systemName: "star.fill").foregroundColor(.luxAmber)
                Text("+\(sessionXP) XP").fontWeight(.bold)
            }
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.luxAmber.opacity(0.12))
            .cornerRadius(20)

            // Encouragement
            Text("Regular review keeps vocabulary fresh.\nCome back tomorrow to maintain your streak.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: onBackToMenu) {
                Text("Back to Lessons")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.luxAmber)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}
