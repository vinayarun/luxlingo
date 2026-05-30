import SwiftUI

// MARK: - LuxLingo Color System
extension Color {
    // Luxembourg national brand colors — used as tasteful accents, not overwhelming fills
    static let luxBrandRed  = Color(red: 0.937, green: 0.200, blue: 0.251)  // #EF3340
    static let luxBrandBlue = Color(red: 0.000, green: 0.639, blue: 0.882)  // #00A3E1

    // Action / feedback (Duolingo-familiar — users expect these associations)
    static let luxGreen      = Color(red: 0.345, green: 0.800, blue: 0.008)  // #58CC02
    static let luxGreenLight = Color(red: 0.843, green: 1.000, blue: 0.722)  // #D7FFB8
    static let luxRed        = Color(red: 1.000, green: 0.294, blue: 0.294)  // #FF4B4B
    static let luxRedLight   = Color(red: 1.000, green: 0.843, blue: 0.843)  // #FFD7D7
    static let luxAmber      = Color(red: 1.000, green: 0.757, blue: 0.027)  // #FFC107
    static let luxPurple     = Color(red: 0.808, green: 0.510, blue: 1.000)  // #CE82FF

    // Feedback tones (richer than the action palette — used in banners)
    static let feedbackGreen = Color(red: 0.220, green: 0.690, blue: 0.230)  // #38B03B
    static let feedbackRed   = Color(red: 0.878, green: 0.200, blue: 0.169)  // #E0332B

    // Surface tokens
    static let surfaceCard     = Color(.secondarySystemBackground)
    static let surfaceElevated = Color(.systemBackground)
}

// MARK: - Typography
extension Font {
    /// Serif target word — "dictionary" feel for the vocabulary word under study.
    static func luxTargetWord(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }

    /// SF Pro Rounded — friendlier and more legible for numerics (XP, streak, counts).
    static func luxNumeric(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Animation Presets
extension Animation {
    /// Standard spring — alive without bouncing.
    static let luxSpring = Animation.spring(response: 0.35, dampingFraction: 0.65)
    /// Snappier spring for button feedback.
    static let luxSnapSpring = Animation.spring(response: 0.25, dampingFraction: 0.70)
    static let luxQuick = Animation.easeInOut(duration: 0.2)
}

// MARK: - Haptic Helpers
enum LuxHaptic {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

// MARK: - Primary CTA Button Style
/// Full-width green (or custom colour) action button with spring shadow depth.
struct LuxPrimaryButtonStyle: ButtonStyle {
    var color: Color  = .luxGreen
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? color : Color(.systemGray4))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(
                color: isEnabled ? color.opacity(0.28) : .clear,
                radius: configuration.isPressed ? 2 : 10,
                y: configuration.isPressed ? 1 : 4
            )
            .animation(.luxSnapSpring, value: configuration.isPressed)
    }
}

// MARK: - Legacy button style (kept for compatibility)
struct LuxLingoButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    var isCorrect: Bool? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(backgroundColor(configuration.isPressed))
            .foregroundColor(contentColor)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.luxSnapSpring, value: configuration.isPressed)
    }

    private func backgroundColor(_ isPressed: Bool) -> Color {
        switch isCorrect {
        case true:  return .feedbackGreen
        case false: return .feedbackRed
        default:
            if isSelected { return .luxGreen }
            return isPressed ? Color(.systemGray4) : Color(.systemGray6)
        }
    }

    private var contentColor: Color {
        if isCorrect != nil { return .white }
        if isSelected       { return .white }
        return .primary
    }
}

// MARK: - Feedback Colors
struct FeedbackColors {
    static func background(for feedback: AnswerFeedback) -> Color {
        switch feedback {
        case .correct:       return .luxGreenLight
        case .wrong:         return .luxRedLight
        case .typo, .nRule:  return Color(.systemYellow).opacity(0.2)
        case .none:          return .clear
        }
    }

    static func text(for feedback: AnswerFeedback) -> Color {
        switch feedback {
        case .correct:       return .feedbackGreen
        case .wrong:         return .feedbackRed
        case .typo, .nRule:  return .luxAmber
        case .none:          return .primary
        }
    }

    static func message(for feedback: AnswerFeedback) -> String {
        switch feedback {
        case .correct:  return ""
        case .wrong:    return "Incorrect"
        case .typo:     return "Close! Check your spelling."
        case .nRule:    return "Right word, but check the N-Rule!"
        case .none:     return ""
        }
    }
}
