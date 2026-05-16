import SwiftUI

struct HowToUseScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                exerciseTypesSection
                featuresSection
                progressSection
                tipsSection
                aboutSection
            }
            .padding(16)
        }
    }

    // MARK: - Exercise Types

    private var exerciseTypesSection: some View {
        SectionCard(title: "Exercise Types", icon: "rectangle.stack.fill", iconColor: .accentColor) {
            VStack(spacing: 0) {
                ExerciseTypeRow(icon: "rectangle.portrait.fill", color: .luxGreen,
                                name: "Flashcard",
                                description: "See a new word, its translation, and an example sentence. Tap the speaker to hear it.")
                Divider().padding(.leading, 44)
                ExerciseTypeRow(icon: "book.fill", color: .blue,
                                name: "Reading",
                                description: "Read a full sentence with the target word highlighted. Tap any word for its dictionary meaning.")
                Divider().padding(.leading, 44)
                ExerciseTypeRow(icon: "pencil.line", color: .purple,
                                name: "Fill in the Blank",
                                description: "Type the missing Luxembourgish word to complete the sentence.")
                Divider().padding(.leading, 44)
                ExerciseTypeRow(icon: "square.grid.3x1.below.line.grid.1x2.fill", color: .orange,
                                name: "Build the Sentence",
                                description: "Arrange shuffled word tiles into the correct order.")
                Divider().padding(.leading, 44)
                ExerciseTypeRow(icon: "checkmark.circle.fill", color: .teal,
                                name: "Multiple Choice",
                                description: "Pick the correct meaning for a word used in context.")
                Divider().padding(.leading, 44)
                ExerciseTypeRow(icon: "arrow.left.arrow.right", color: .indigo,
                                name: "Match the Pairs",
                                description: "Tap a Luxembourgish word, then tap its English meaning to make a pair.")
                Divider().padding(.leading, 44)
                ExerciseTypeRow(icon: "n.circle.fill", color: .luxPurple,
                                name: "N-Rule Hunter",
                                description: "Decide whether the target word keeps its final 'n' based on the Eifeler Regel.")
                Divider().padding(.leading, 44)
                ExerciseTypeRow(icon: "bolt.fill", color: .luxAmber,
                                name: "Speed Round",
                                description: "Swipe right if the translation shown is correct, left if it's wrong — as fast as you can.")
                Divider().padding(.leading, 44)
                ExerciseTypeRow(icon: "ear.fill", color: .teal,
                                name: "Listening",
                                description: "The word plays automatically — no text shown. Pick the correct English meaning from three options. Trains your ear, not your eye.")
                Divider().padding(.leading, 44)
                ExerciseTypeRow(icon: "waveform.and.mic", color: .pink,
                                name: "Audio Dictation",
                                description: "Hear the word and type it in Luxembourgish from memory. Minor spelling errors are flagged but still counted — Luxembourgish spelling from audio is hard!")
                Divider().padding(.leading, 44)
                ExerciseTypeRow(icon: "arrow.triangle.2.circlepath", color: .orange,
                                name: "Conjugation Match",
                                description: "A sentence shows a conjugated verb form — identify which infinitive it belongs to. Covers suppletive verbs like sinn → ass.")
                Divider().padding(.leading, 44)
                ExerciseTypeRow(icon: "tablecells.fill", color: .luxGreen,
                                name: "Verb Forms",
                                description: "Given a verb's conjugation table with one row blanked, pick the correct form for that pronoun.")
            }
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        SectionCard(title: "Features", icon: "star.fill", iconColor: .luxAmber) {
            VStack(spacing: 0) {
                FeatureRow(icon: "speaker.wave.2.fill", color: .blue,
                           name: "Pronunciation",
                           description: "Tap the speaker icon on any word or sentence to hear it spoken aloud.")
                Divider().padding(.leading, 44)
                FeatureRow(icon: "magnifyingglass", color: .purple,
                           name: "Word Lookup",
                           description: "In Reading and Flashcard exercises, tap any word in the Luxembourgish sentence to look it up in the lod.lu dictionary — all meanings are shown.")
                Divider().padding(.leading, 44)
                FeatureRow(icon: "arrow.triangle.branch", color: .luxAmber,
                           name: "Verb Conjugations",
                           description: "Tap the conjugation chip on a verb to see its full present-tense conjugation table.")
                Divider().padding(.leading, 44)
                FeatureRow(icon: "person.2.fill", color: .luxGreen,
                           name: "Characters",
                           description: "Meet Marc, Anna, Lena, Paul, Bello, Claire and Mr. Weiss — their avatars appear when they feature in a sentence.")
                Divider().padding(.leading, 44)
                FeatureRow(icon: "book.pages", color: .luxPurple,
                           name: "Grammar Tips",
                           description: "Open the menu and tap Grammar Tips for quick-reference cards on the N-Rule, articles, verb conjugation, suppletive verbs and capitalisation. The n-rule and conjugation chips in exercises link directly to the relevant card.")
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        SectionCard(title: "Progress & XP", icon: "chart.bar.fill", iconColor: .luxGreen) {
            VStack(spacing: 0) {
                FeatureRow(icon: "circle.dotted", color: .accentColor,
                           name: "Lesson Rings",
                           description: "Each lesson card shows a progress ring. It fills as you practice the words in that lesson and turns green when complete.")
                Divider().padding(.leading, 44)
                FeatureRow(icon: "star.fill", color: .luxAmber,
                           name: "XP (Experience Points)",
                           description: "Earn XP for every correct answer. More XP for harder exercises and higher mastery levels. Your total accumulates across all lessons.")
                Divider().padding(.leading, 44)
                FeatureRow(icon: "flame.fill", color: .orange,
                           name: "Day Streak",
                           description: "Complete at least one lesson each day to build your streak. Missing a day resets it to 1.")
                Divider().padding(.leading, 44)
                FeatureRow(icon: "chart.line.uptrend.xyaxis", color: .luxGreen,
                           name: "Vocabulary Coverage",
                           description: "The My Progress tab shows a Zipf curve of how much everyday Luxembourgish text your vocabulary covers.")
            }
        }
    }

    // MARK: - Tips

    private var tipsSection: some View {
        SectionCard(title: "Tips", icon: "lightbulb.fill", iconColor: .luxAmber) {
            VStack(alignment: .leading, spacing: 10) {
                TipRow(number: "1", text: "Complete lessons in order — each one builds on vocabulary from the last.")
                TipRow(number: "2", text: "Come back daily to keep your streak alive and reinforce what you've learned.")
                TipRow(number: "3", text: "Use the word lookup freely — understanding words in context speeds up learning.")
                TipRow(number: "4", text: "If you're stuck, tap \"Need a hint?\" or use Skip after 3 wrong answers.")
                TipRow(number: "5", text: "The Eifeler Regel (n-rule) is tricky — use the hint card until it clicks, then check the Grammar Tips tab for the UNITED ZOHA memory trick.")
                TipRow(number: "6", text: "Listening and Dictation exercises unlock after a few practices — they train a different skill from reading. Keep your volume on!")
            }
            .padding(.vertical, 4)
        }
    }

    private var aboutSection: some View {
        SectionCard(title: "About LuxLingo", icon: "info.circle.fill", iconColor: .luxGreen) {
            VStack(alignment: .leading, spacing: 14) {
                Text("LuxLingo is a free, ad-free app for learning Luxembourgish — built with care for everyone who wants to connect with Luxembourg's national language.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                // Contact
                VStack(alignment: .leading, spacing: 6) {
                    Label("Contact & Feedback", systemImage: "envelope.fill")
                        .font(.subheadline).fontWeight(.semibold)
                    Text("Found an error in a sentence or exercise? Use the")
                        .font(.caption).foregroundColor(.secondary)
                    + Text(" 🚩 flag button ")
                        .font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                    + Text("during any exercise to report it directly.")
                        .font(.caption).foregroundColor(.secondary)
                    Text("For anything else, email us:")
                        .font(.caption).foregroundColor(.secondary)
                    Button {
                        if let url = URL(string: "mailto:luxlingo.app@gmail.com") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("luxlingo.app@gmail.com")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.luxGreen)
                    }
                }

                Divider()

                // Credits
                VStack(alignment: .leading, spacing: 4) {
                    Label("Powered by", systemImage: "flag.fill")
                        .font(.subheadline).fontWeight(.semibold)
                    Group {
                        Text("• ") + Text("LOD.lu").bold() + Text(" — Lëtzebuerger Online Dictionnaire")
                        Text("• ") + Text("Sproochmaschinn.lu").bold() + Text(" — Luxembourg TTS")
                        Text("• ") + Text("LuxASR / LuxMT").bold() + Text(" — University of Luxembourg")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Text("Version 1.0 · May 2026")
                    .font(.caption2)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Reusable sub-views

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.subheadline)
                Text(title)
                    .font(.headline)
            }
            .padding(.bottom, 12)

            content()
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct ExerciseTypeRow: View {
    let icon: String
    let color: Color
    let name: String
    let description: String

    var body: some View {
        InfoRow(icon: icon, color: color, name: name, description: description)
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let name: String
    let description: String

    var body: some View {
        InfoRow(icon: icon, color: color, name: name, description: description)
    }
}

private struct InfoRow: View {
    let icon: String
    let color: Color
    let name: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(color.opacity(0.13))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 15, weight: .medium))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline).fontWeight(.semibold)
                JustifiedText(text: description, uiFont: .preferredFont(forTextStyle: .caption1))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

private struct TipRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption).fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.luxAmber)
                .clipShape(Circle())
            JustifiedText(text: text, uiFont: .preferredFont(forTextStyle: .subheadline))
        }
    }
}
