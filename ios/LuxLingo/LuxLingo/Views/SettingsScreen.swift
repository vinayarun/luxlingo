import SwiftUI

struct SettingsScreen: View {
    @AppStorage("luxlingo_daily_goal") private var dailyGoal: Int = 20

    private struct GoalOption {
        let label: String; let minutes: Int; let xp: Int; let estimate: String
    }
    private let goalOptions: [GoalOption] = [
        GoalOption(label: "Light",     minutes: 5,  xp: 10, estimate: "~6 months to complete all lessons"),
        GoalOption(label: "Regular",   minutes: 10, xp: 20, estimate: "~3 months to complete all lessons"),
        GoalOption(label: "Committed", minutes: 15, xp: 40, estimate: "~2 months to complete all lessons"),
    ]

    var body: some View {
        List {
            Section {
                ForEach(goalOptions, id: \.xp) { option in
                    Button(action: { dailyGoal = option.xp }) {
                        HStack(spacing: 14) {
                            Image(systemName: dailyGoal == option.xp ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(dailyGoal == option.xp ? .luxGreen : Color(.systemGray3))
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("\(option.minutes) min a day")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("· \(option.label)")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Text(option.estimate)
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Daily Goal")
            } footer: {
                Text("The progress bar on the home screen tracks your XP toward this goal each day.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
