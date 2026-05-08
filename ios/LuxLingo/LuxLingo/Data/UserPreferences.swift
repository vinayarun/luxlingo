import Foundation
import SwiftUI

// MARK: - User Preferences (replaces DataStore Preferences)
final class UserPreferences: ObservableObject {
    @AppStorage("luxlingo_xp") var xp: Int = 0
    @AppStorage("luxlingo_streak") var streak: Int = 0
    @AppStorage("luxlingo_last_lesson_date") var lastLessonDate: Int = 0

    func addXp(_ amount: Int) {
        xp += amount
    }

    func updateStreak() {
        let today = Int(Date().timeIntervalSince1970 / (60 * 60 * 24)) // Days since epoch

        if lastLessonDate == today - 1 {
            streak += 1
        } else if lastLessonDate < today - 1 {
            streak = 1
        } else if streak == 0 {
            streak = 1
        }

        lastLessonDate = today
    }
}
