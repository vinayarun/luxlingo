import SwiftUI

struct ZipfsLawInfoScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                didYouKnowSection
                wordExamplesSection
                formulaSection
                howWeUseItSection
                lessonRingsSection
            }
            .padding(16)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 0) {
            if let img = UIImage(named: "scene_school_morning") {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Text("The Science of Fluency")
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .resizable().scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.luxGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                    Text("The Science of Fluency")
                        .font(.title2).fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
            }

            JustifiedText(text: "LuxLingo is built on a mathematical principle that explains why some words are infinitely more valuable to learn than others — and uses it to make every minute of study count.")
                .padding(16)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Did you know

    private var didYouKnowSection: some View {
        SectionCard(title: "Did you know?", icon: "lightbulb.fill", iconColor: .luxAmber) {
            VStack(alignment: .leading, spacing: 12) {
                JustifiedText(text: "In every language, a tiny handful of words does most of the heavy lifting. This is Zipf's Law — the most common word appears roughly twice as often as the second most common, three times as often as the third, and so on.")

                VStack(spacing: 8) {
                    CoverageStatRow(label: "Top 10 words",  percent: 25, color: .blue)
                    CoverageStatRow(label: "Top 100 words", percent: 50, color: .orange)
                    CoverageStatRow(label: "Top 500 words", percent: 80, color: .luxGreen)
                }

                JustifiedText(text: "That means just 500 words cover **80% of everyday Luxembourgish conversation**. LuxLingo teaches exactly those words first.")
            }
        }
    }

    // MARK: - Word examples

    private var wordExamplesSection: some View {
        SectionCard(title: "See it in action", icon: "text.magnifyingglass", iconColor: .accentColor) {
            VStack(alignment: .leading, spacing: 6) {
                JustifiedText(text: "These five Luxembourgish words alone account for nearly 40% of all words spoken in everyday conversation:")
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

    // MARK: - The formula

    private var formulaSection: some View {
        SectionCard(title: "The Formula", icon: "function", iconColor: .luxGreen) {
            VStack(alignment: .leading, spacing: 12) {
                Text("f (r)  =  C / r ˢ")
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.luxGreen)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 3) {
                    ForEach([
                        ("r", "rank of the word (1st most common, 2nd…)"),
                        ("s", "exponent ≈ 1 for natural language"),
                        ("C", "normalising constant"),
                    ], id: \.0) { symbol, desc in
                        HStack(alignment: .top, spacing: 8) {
                            Text(symbol)
                                .font(.caption).fontWeight(.bold).foregroundColor(.luxGreen)
                                .frame(width: 14)
                            Text("— \(desc)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

                JustifiedText(text: "A Luxembourgish advantage: with ~600,000 native speakers, Luxembourgish has a much smaller active vocabulary than French, German or English. This steepens the Zipf curve further — the top 500 words cover an even larger share of everyday speech than in larger languages, making the frequency-first approach especially powerful here.",
                              uiFont: .preferredFont(forTextStyle: .caption1))
                    .padding(.top, 4)
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

                JustifiedText(text: "Each lesson card shows a progress ring — it fills as you practise the words in that lesson and turns fully green when complete. Tap **My Progress** to see your overall vocabulary coverage curve.")
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
import SwiftUI

// MARK: - Justified text (SwiftUI Text has no .justified option)
// Uses UITextView so text touches both left and right margins on every line.
// Handles **bold** markdown inline.

struct JustifiedText: UIViewRepresentable {
    let text:    String
    var uiFont:  UIFont  = .preferredFont(forTextStyle: .subheadline)
    var uiColor: UIColor = .secondaryLabel

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable      = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset         = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        tv.attributedText = attributed(text)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let w = proposal.width ?? UIScreen.main.bounds.width
        return uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude))
    }

    private func attributed(_ s: String) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.alignment     = .justified
        para.lineBreakMode = .byWordWrapping
        let base: [NSAttributedString.Key: Any] = [
            .font: uiFont, .foregroundColor: uiColor, .paragraphStyle: para,
        ]
        let out    = NSMutableAttributedString()
        let chunks = s.components(separatedBy: "**")
        for (i, chunk) in chunks.enumerated() {
            guard !chunk.isEmpty else { continue }
            if i % 2 == 1,
               let bd = uiFont.fontDescriptor.withSymbolicTraits(.traitBold) {
                var boldAttrs  = base
                boldAttrs[.font] = UIFont(descriptor: bd, size: uiFont.pointSize)
                out.append(NSAttributedString(string: chunk, attributes: boldAttrs))
            } else {
                out.append(NSAttributedString(string: chunk, attributes: base))
            }
        }
        return out
    }
}

// MARK: - Grammar Tips Section enum (used for deep-linking from exercises)

enum GrammarGuideSection: String, CaseIterable {
    case nRule, articles, conjugation, suppletive, capitalisation
}

// MARK: - Grammar Tips Screen

struct LanguageGuideScreen: View {
    var scrollTo: GrammarGuideSection? = nil

    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    nRuleSection   .id(GrammarGuideSection.nRule)
                    articlesSection.id(GrammarGuideSection.articles)
                    conjugationSection.id(GrammarGuideSection.conjugation)
                    suppletiveSection .id(GrammarGuideSection.suppletive)
                    capitalisationSection.id(GrammarGuideSection.capitalisation)
                }
                .padding(16)
                .onAppear {
                    if let section = scrollTo {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation { proxy.scrollTo(section, anchor: .top) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 0) {
            if let img = UIImage(named: "scene_classroom") {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    Text("Grammar Tips")
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }
            Text("Quick reference for the quirks of Luxembourgish that trip up new learners.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - N-Rule

    private var nRuleSection: some View {
        GuideSectionCard(title: "The N-Rule (Eifeler Regel)", icon: "n.circle.fill", color: .luxPurple) {
            VStack(alignment: .leading, spacing: 12) {
                JustifiedText(text: "Many Luxembourgish words end in **-n** (sinn, hunn, keen…). Whether you keep or drop that n depends entirely on the first sound of the next word.")

                GuideRuleRow(symbol: "✓  Keep the n", color: .luxGreen,
                    detail: "before vowels (a e i o u) and before d, h, n, t, z")
                GuideRuleRow(symbol: "✗  Drop the n", color: .red,
                    detail: "before all other consonants (b, c, f, g, k, l, m, p, r, s, v, w…)")

                // UNITED ZOHA mnemonic
                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory trick: UNITED ZOHA")
                        .font(.caption).fontWeight(.semibold).foregroundColor(.luxPurple)
                    JustifiedText(
                        text: "Each letter in **UNITED ZOHA** is a sound that KEEPS the n: the vowels U, I, E, O, A — plus the consonants N, T, D, Z, H. If the next word starts with anything else, drop the n.",
                        uiFont: .preferredFont(forTextStyle: .caption1)
                    )
                }
                .padding(10)
                .background(Color.luxPurple.opacity(0.07))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Examples").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                    GuideExampleRow(lu: "Mir sinn doheem", en: "keep n — next word starts with d")
                    GuideExampleRow(lu: "Mir si krank", en: "drop n — next word starts with k")
                    GuideExampleRow(lu: "ech hunn eng Iddi", en: "keep n — next word starts with vowel")
                    GuideExampleRow(lu: "ech hu Freed", en: "drop n — next word starts with f")
                }

                Text("The N-Rule Hunter exercise in the app trains this reflex automatically.")
                    .font(.caption).foregroundColor(.secondary).italic()
            }
        }
    }

    // MARK: - Articles

    private var articlesSection: some View {
        GuideSectionCard(title: "Articles & Gender", icon: "textformat.abc", color: .accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                JustifiedText(text: "The Luxembourgish word for \"the\" changes depending on two things: the **gender** of the noun (masculine, feminine or neuter) and what **role** the noun plays in the sentence.")

                // Role explanations with English parallels
                VStack(alignment: .leading, spacing: 10) {
                    ArticleRoleRow(
                        icon: "person.fill", color: .accentColor,
                        role: "The doer",
                        detail: "Who is performing the action. In English: \"**The** dog barks.\" In Luxembourgish this is called the subject.",
                        masc: "de Mann", fem: "d'Fra", neut: "d'Kand"
                    )
                    Divider()
                    ArticleRoleRow(
                        icon: "arrow.right", color: .orange,
                        role: "The receiver",
                        detail: "What the action is done to. In English: \"I see **the** man.\" Only masculine nouns change here: de → den.",
                        masc: "den Mann", fem: "d'Fra", neut: "d'Kand"
                    )
                    Divider()
                    ArticleRoleRow(
                        icon: "link", color: .luxGreen,
                        role: "After prepositions",
                        detail: "After words like mat (with), an (in), op (on), fir (for). Think \"I spoke with **the** teacher.\" The article changes for all genders here.",
                        masc: "dem Mann", fem: "der Fra", neut: "dem Kand"
                    )
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 6) {
                    JustifiedText(
                        text: "Good news — the only change most learners notice is **de → den** for masculine nouns when they are the object, and **de/d' → dem/der** after prepositions. Everything else stays d'.",
                        uiFont: .preferredFont(forTextStyle: .caption1)
                    )
                    JustifiedText(
                        text: "Before a vowel or h, always use d' regardless of gender:",
                        uiFont: .preferredFont(forTextStyle: .caption1)
                    )
                    GuideExampleRow(lu: "d'Anna, d'Haus, d'Auto", en: "vowel or h → always d'")
                    GuideExampleRow(lu: "am Haus  =  an + dem Haus", en: "preposition + dem contracts to am")
                }

                Text("Names always take an article in Luxembourgish. \"De Marc\" and \"D'Anna\" is perfectly normal — unlike in English.")
                    .font(.caption).foregroundColor(.secondary).italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Conjugation

    private var conjugationSection: some View {
        GuideSectionCard(title: "Present Tense Conjugation", icon: "person.3.fill", color: .luxGreen) {
            VStack(alignment: .leading, spacing: 16) {
                JustifiedText(text: "Luxembourgish verbs change their ending depending on who is doing the action. Here are the four most common verbs you'll meet in early lessons.")

                ConjugationTable(verb: "sinn (to be)", rows: [
                    ("ech", "sinn"), ("du", "bass"), ("hien/si/et", "ass"),
                    ("mir", "sinn"), ("dir", "sidd"), ("si", "sinn"),
                ])
                ConjugationTable(verb: "hunn (to have)", rows: [
                    ("ech", "hunn"), ("du", "hues"), ("hien/si/et", "huet"),
                    ("mir", "hunn"), ("dir", "hutt"), ("si", "hunn"),
                ])
                ConjugationTable(verb: "goen (to go)", rows: [
                    ("ech", "ginn"), ("du", "gees"), ("hien/si/et", "geet"),
                    ("mir", "ginn"), ("dir", "gitt"), ("si", "ginn"),
                ])
                ConjugationTable(verb: "kommen (to come)", rows: [
                    ("ech", "kommen"), ("du", "kënns"), ("hien/si/et", "kënnt"),
                    ("mir", "kommen"), ("dir", "kommt"), ("si", "kommen"),
                ])
            }
        }
    }

    // MARK: - Suppletive Verbs

    private var suppletiveSection: some View {
        GuideSectionCard(title: "When the Word Changes Completely", icon: "arrow.triangle.2.circlepath", color: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                JustifiedText(text: "Some Luxembourgish verbs look completely different when conjugated — there is no family resemblance between the infinitive and some of its forms. The most important example is **sinn** (to be).")

                JustifiedText(
                    text: "Compare to English: the verb \"to be\" gives you am, is, are, was, were — none of which look like \"be\". Luxembourgish works the same way.",
                    uiFont: .preferredFont(forTextStyle: .caption1)
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Key examples").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                    GuideExampleRow(lu: "sinn → ass", en: "hien ass doheem  (he is at home)")
                    GuideExampleRow(lu: "sinn → bass", en: "du bass frou  (you are happy)")
                    GuideExampleRow(lu: "goen → geet", en: "si geet an d'Schoul  (she goes to school)")
                    GuideExampleRow(lu: "goen → ginn", en: "mir ginn schwammen  (we go swimming)")
                }

                Text("When a conjugated form appears in your exercises, the app shows a chip (e.g. \"sinn → ass\") so you always know which verb you're working with. The Conjugation Match exercise tests this directly.")
                    .font(.caption).foregroundColor(.secondary).italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Capitalisation

    private var capitalisationSection: some View {
        GuideSectionCard(title: "Capital Letters Mid-Sentence", icon: "textformat.size.larger", color: .luxAmber) {
            VStack(alignment: .leading, spacing: 12) {
                JustifiedText(text: "Like German, Luxembourgish capitalises **all nouns** — even in the middle of a sentence. This is one of the most visible differences from English and French.")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Examples").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                    GuideExampleRow(lu: "D'Kand spillt am Gaart.", en: "The child plays in the garden.")
                    GuideExampleRow(lu: "Ech iessen en Appel.", en: "I eat an apple.")
                    GuideExampleRow(lu: "De Hond geet an d'Schoul.", en: "The dog goes to school.")
                    GuideExampleRow(lu: "Si lieft an enger Stad.", en: "She lives in a city.")
                }

                Text("Verbs, adjectives and adverbs stay lowercase — only nouns get the capital. When you see an unexpected capital mid-sentence in our exercises, that's why.")
                    .font(.caption).foregroundColor(.secondary).italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Sub-components

private struct GuideSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color.opacity(0.13))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 16)

            content()
                .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
    }
}

private struct GuideRuleRow: View {
    let symbol: String
    let color: Color
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(symbol)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(color)
                .frame(width: 100, alignment: .leading)
            JustifiedText(text: detail)
        }
    }
}

private struct GuideExampleRow: View {
    let lu: String
    let en: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(lu)
                .font(.subheadline).fontWeight(.semibold)
            Text(en)
                .font(.caption)
                .foregroundColor(Color(.tertiaryLabel))
                .italic()
        }
    }
}

private struct ArticleRoleRow: View {
    let icon: String
    let color: Color
    let role: String
    let detail: String
    let masc: String
    let fem: String
    let neut: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption).foregroundColor(color)
                Text(role).font(.caption).fontWeight(.bold).foregroundColor(color)
            }
            JustifiedText(text: detail, uiFont: .preferredFont(forTextStyle: .caption1))
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Masc").font(.caption2).foregroundColor(.secondary)
                    Text(masc).font(.caption).fontWeight(.semibold)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Fem").font(.caption2).foregroundColor(.secondary)
                    Text(fem).font(.caption).fontWeight(.semibold)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Neut").font(.caption2).foregroundColor(.secondary)
                    Text(neut).font(.caption).fontWeight(.semibold)
                }
            }
        }
    }
}

private struct ArticleHeaderRow: View {
    var body: some View {
        HStack {
            Text("Case").frame(width: 90, alignment: .leading)
            Text("Masc").frame(maxWidth: .infinity)
            Text("Fem").frame(maxWidth: .infinity)
            Text("Neut").frame(maxWidth: .infinity)
        }
        .font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
        .padding(.horizontal, 10).padding(.vertical, 6)
    }
}

private struct ArticleRow: View {
    let case_: String
    let masc: String
    let fem: String
    let neut: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(case_).font(.caption).fontWeight(.medium).frame(width: 90, alignment: .leading)
                Text(masc).font(.subheadline).fontWeight(.bold).frame(maxWidth: .infinity)
                Text(fem).font(.subheadline).fontWeight(.bold).frame(maxWidth: .infinity)
                Text(neut).font(.subheadline).fontWeight(.bold).frame(maxWidth: .infinity)
            }
            Text(note).font(.caption2).foregroundColor(.secondary).padding(.leading, 90)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
    }
}

private struct ConjugationTable: View {
    let verb: String
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verb)
                .font(.caption).fontWeight(.semibold).foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    HStack {
                        Text(row.0)
                            .font(.subheadline).foregroundColor(.secondary)
                            .frame(width: 90, alignment: .leading)
                        Text(row.1)
                            .font(.subheadline).fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    if idx < rows.count - 1 { Divider().padding(.leading, 10) }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}
