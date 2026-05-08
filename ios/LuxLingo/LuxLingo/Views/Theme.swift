import SwiftUI

// MARK: - LuxLingo Color Palette
extension Color {
    static let luxGreen = Color(red: 0.345, green: 0.8, blue: 0.008)       // #58CC02
    static let luxPurple = Color(red: 0.808, green: 0.51, blue: 1.0)       // #CE82FF
    static let luxRed = Color(red: 1.0, green: 0.294, blue: 0.294)         // #FF4B4B
    static let luxGreenLight = Color(red: 0.843, green: 1.0, blue: 0.722)  // #D7FFB8
    static let luxRedLight = Color(red: 1.0, green: 0.843, blue: 0.843)    // #FFD7D7
    static let luxAmber = Color(red: 1.0, green: 0.757, blue: 0.027)       // #FFC107
    static let feedbackGreen = Color(red: 0.298, green: 0.686, blue: 0.314) // #4CAF50
    static let feedbackRed = Color(red: 0.957, green: 0.263, blue: 0.212)   // #F44336
}

// MARK: - Button Style
struct LuxLingoButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    var isCorrect: Bool? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.bold)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(backgroundColor(configuration.isPressed))
            .foregroundColor(contentColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }

    private func backgroundColor(_ isPressed: Bool) -> Color {
        switch isCorrect {
        case true: return .feedbackGreen
        case false: return .feedbackRed
        default:
            if isSelected { return .luxGreen }
            return isPressed ? Color(.systemGray4) : Color(.systemGray6)
        }
    }

    private var contentColor: Color {
        if isCorrect != nil { return .white }
        if isSelected { return .white }
        return .primary
    }
}

// MARK: - Feedback Colors
struct FeedbackColors {
    static func background(for feedback: AnswerFeedback) -> Color {
        switch feedback {
        case .correct: return .luxGreenLight
        case .wrong: return .luxRedLight
        case .typo, .nRule: return Color(.systemYellow).opacity(0.2)
        case .none: return .clear
        }
    }

    static func text(for feedback: AnswerFeedback) -> Color {
        switch feedback {
        case .correct: return .feedbackGreen
        case .wrong: return .feedbackRed
        case .typo, .nRule: return .luxAmber
        case .none: return .primary
        }
    }

    static func message(for feedback: AnswerFeedback) -> String {
        switch feedback {
        case .correct: return "Correct!"
        case .wrong: return "Incorrect"
        case .typo: return "Close! Check your spelling."
        case .nRule: return "Right word, but check the N-Rule!"
        case .none: return ""
        }
    }
}

// MARK: - Animation Presets
extension Animation {
    static let luxSpring = Animation.spring(response: 0.35, dampingFraction: 0.7)
    static let luxQuick = Animation.easeInOut(duration: 0.2)
}
