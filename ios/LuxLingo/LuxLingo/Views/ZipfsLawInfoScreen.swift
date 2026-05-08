import SwiftUI

struct ZipfsLawInfoScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                didYouKnowSection
                wordExamplesSection
                howWeUseItSection
                lessonRingsSection
            }
            .padding(16)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(.luxGreen)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            Text("The Science of Fluency")
                .font(.title2).fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Text("LuxLingo is built on a mathematical principle that explains why some words are infinitely more valuable to learn than others — and uses it to make every minute of study count.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Did you know

    private var didYouKnowSection: some View {
        SectionCard(title: "Did you know?", icon: "lightbulb.fill", iconColor: .luxAmber) {
            VStack(alignment: .leading, spacing: 12) {
                Text("In every language, a tiny handful of words does most of the heavy lifting. This is Zipf's Law — the most common word appears roughly twice as often as the second most common, three times as often as the third, and so on.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    CoverageStatRow(label: "Top 10 words",  percent: 25, color: .blue)
                    CoverageStatRow(label: "Top 100 words", percent: 50, color: .orange)
                    CoverageStatRow(label: "Top 500 words", percent: 80, color: .luxGreen)
                }

                Text("That means just 500 words cover **80% of everyday Luxembourgish conversation**. LuxLingo teaches exactly those words first.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Word examples

    private var wordExamplesSection: some View {
        SectionCard(title: "See it in action", icon: "text.magnifyingglass", iconColor: .accentColor) {
            VStack(alignment: .leading, spacing: 6) {
                Text("These five Luxembourgish words alone account for nearly 40% of all words spoken in everyday conversation:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                WordExampleRow(word: "ech",   meaning: "I",        percent: 13)
                Divider()
                WordExampleRow(word: "sinn",  meaning: "to be",    percent: 8)
                Divider()
                WordExampleRow(word: "de/d'", meaning: "the",      percent: 7)
                Divider()
                WordExampleRow(word: "an",    meaning: "and / in", percent: 6)
                Divider()
                WordExampleRow(word: "hunn",  meaning: "to have",  percent: 5)

                Text("Percentages are approximate and based on frequency analysis of Luxembourgish text corpora.")
                    .font(.caption2)
                    .foregroundColor(Color(.tertiaryLabel))
                    .padding(.top, 6)
            }
        }
    }

    // MARK: - How we use it

    private var howWeUseItSection: some View {
        SectionCard(title: "How LuxLingo uses this", icon: "graduationcap.fill", iconColor: .luxGreen) {
            VStack(spacing: 0) {
                FeatureRow(icon: "list.number", color: .luxGreen,
                           name: "Frequency-first curriculum",
                           description: "Lessons are ordered by word frequency, not by theme. You learn the most useful words in every lesson.")
                Divider().padding(.leading, 40)
                FeatureRow(icon: "chart.line.uptrend.xyaxis", color: .accentColor,
                           name: "Coverage tracking",
                           description: "The My Progress tab shows the exact percentage of everyday text your current vocabulary covers.")
                Divider().padding(.leading, 40)
                FeatureRow(icon: "bolt.fill", color: .luxAmber,
                           name: "Maximum efficiency",
                           description: "Early lessons deliver the biggest coverage gains. Each lesson you complete unlocks a disproportionately large slice of real conversations.")
            }
        }
    }

    // MARK: - Lesson rings

    private var lessonRingsSection: some View {
        SectionCard(title: "Your Lesson Rings", icon: "circle.dotted", iconColor: .accentColor) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle().stroke(Color(.systemGray5), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: 0.57)
                        .stroke(Color.luxGreen,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("4").font(.system(size: 12, weight: .bold))
                        Text("/7").font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }
                .frame(width: 44, height: 44)

                Text("Each lesson card shows a progress ring — it fills as you practise the words in that lesson and turns fully green when complete. Tap **My Progress** to see your overall vocabulary coverage curve.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Sub-views

private struct CoverageStatRow: View {
    let label: String
    let percent: Int
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption).fontWeight(.medium)
                .frame(width: 100, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: geo.size.width * CGFloat(percent) / 100)
                }
            }
            .frame(height: 8)
            Text("\(percent)%")
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(color)
                .frame(width: 34, alignment: .trailing)
        }
    }
}

private struct WordExampleRow: View {
    let word: String
    let meaning: String
    let percent: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(word)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(meaning)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 72, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(Color.luxGreen.opacity(0.75))
                        .frame(width: geo.size.width * CGFloat(percent) / 20)
                }
            }
            .frame(height: 7)

            Text("~\(percent)%")
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(.luxGreen)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}
