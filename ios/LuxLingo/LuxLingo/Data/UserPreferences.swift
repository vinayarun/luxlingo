import Foundation
import SwiftUI

// MARK: - User Preferences (replaces DataStore Preferences)
final class UserPreferences: ObservableObject {
    @AppStorage("luxlingo_xp") var xp: Int = 0
    @AppStorage("luxlingo_streak") var streak: Int = 0
    @AppStorage("luxlingo_last_lesson_date") var lastLessonDate: Int = 0
    @AppStorage("luxlingo_daily_xp") private var _dailyXp: Int = 0
    @AppStorage("luxlingo_daily_xp_date") private var dailyXpDate: Int = 0
    @AppStorage("luxlingo_onboarded") var hasCompletedOnboarding: Bool = false
    @AppStorage("luxlingo_daily_goal") private var _dailyGoal: Int = 20

    var dailyGoal: Int { _dailyGoal }
    func setDailyGoal(_ xp: Int) { _dailyGoal = xp }

    private var todayDay: Int { Int(Date().timeIntervalSince1970 / (60 * 60 * 24)) }

    /// XP earned today — resets to 0 automatically at midnight.
    var todayXp: Int { dailyXpDate == todayDay ? _dailyXp : 0 }

    func addXp(_ amount: Int) {
        xp += amount
        let t = todayDay
        if dailyXpDate != t { _dailyXp = amount; dailyXpDate = t }
        else                 { _dailyXp += amount }
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
