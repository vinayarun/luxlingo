import SwiftUI

struct OnboardingScreen: View {
    @ObservedObject var preferences: UserPreferences
    @State private var page = 0
    @State private var selectedGoalXp: Int? = nil

    private struct Goal {
        let label: String; let minutes: Int; let xp: Int; let estimate: String
    }
    private let goals: [Goal] = [
        Goal(label: "Light",     minutes: 5,  xp: 10, estimate: "about 6 months"),
        Goal(label: "Regular",   minutes: 10, xp: 20, estimate: "about 3 months"),
        Goal(label: "Committed", minutes: 15, xp: 40, estimate: "about 2 months"),
    ]

    var body: some View {
        Group {
            if page == 0 { welcomePage } else { goalPage }
        }
        .animation(.easeInOut(duration: 0.25), value: page)
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                if let img = UIImage(named: "scene_village_aerial") {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 260).clipped()
                } else {
                    Color.luxGreen.opacity(0.15).frame(height: 260)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.65)],
                               startPoint: .center, endPoint: .bottom)
                VStack(spacing: 6) {
                    Text("LuxLingo")
                        .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                    Text("Luxembourgish for beginners")
                        .font(.subheadline).foregroundColor(.white.opacity(0.85))
                }
                .padding(.bottom, 28)
            }
            .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Making Luxembourgish accessible to everyone!")
                        .font(.title2).fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 18) {
                        OnboardingFeatureRow(
                            icon: "chart.line.uptrend.xyaxis", color: .luxGreen,
                            title: "The right words first",
                            detail: "Zipf's Law tells us a small set of words covers most of everyday speech. We teach those first, so every minute counts."
                        )
                        OnboardingFeatureRow(
                            icon: "clock.fill", color: .luxAmber,
                            title: "As little as 5 minutes a day",
                            detail: "Short sessions designed around a busy work schedule. Pick it up on the train, at lunch, anywhere."
                        )
                        OnboardingFeatureRow(
                            icon: "person.3.fill", color: .luxPurple,
                            title: "Free, forever",
                            detail: "No ads, no subscriptions. Built by volunteers for all who want to learn."
                        )
                    }

                    // Page indicator
                    HStack(spacing: 6) {
                        Spacer()
                        Circle().fill(Color.luxGreen).frame(width: 7, height: 7)
                        Circle().fill(Color(.systemGray4)).frame(width: 7, height: 7)
                        Spacer()
                    }
                    .padding(.top, 4)

                    Button {
                        withAnimation(.luxSpring) { page = 1 }
                    } label: {
                        Text("Get started")
                            .font(.headline)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.luxGreen)
                            .foregroundColor(.white).cornerRadius(14)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
    }

    // MARK: - Page 2: Daily goal

    private var goalPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            VStack(spacing: 8) {
                Text("How much time\ncan you spare each day?")
                    .font(.title2).fontWeight(.bold)
                    .multilineTextAlignment(.center)
                Text("You can update this any time in the More tab.")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                ForEach(goals, id: \.xp) { goal in
                    OnboardingGoalRow(
                        label: goal.label,
                        minutes: goal.minutes,
                        estimate: goal.estimate,
                        isSelected: selectedGoalXp == goal.xp,
                        isRecommended: goal.xp == 20
                    ) {
                        selectedGoalXp = goal.xp
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Page indicator
            HStack(spacing: 6) {
                Circle().fill(Color(.systemGray4)).frame(width: 7, height: 7)
                Circle().fill(Color.luxGreen).frame(width: 7, height: 7)
            }
            .padding(.bottom, 16)

            Button {
                preferences.setDailyGoal(selectedGoalXp ?? 20)
                preferences.hasCompletedOnboarding = true
            } label: {
                Text("Start learning")
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding()
                    .background(selectedGoalXp != nil ? Color.luxGreen : Color(.systemGray4))
                    .foregroundColor(.white).cornerRadius(14)
            }
            .disabled(selectedGoalXp == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }
}

// MARK: - Feature Row

private struct OnboardingFeatureRow: View {
    let icon: String; let color: Color; let title: String; let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 42, height: 42)
                Image(systemName: icon).foregroundColor(color).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                JustifiedText(text: detail, uiFont: .preferredFont(forTextStyle: .caption1))
            }
        }
    }
}

// MARK: - Goal Row

private struct OnboardingGoalRow: View {
    let label: String; let minutes: Int; let estimate: String
    let isSelected: Bool; let isRecommended: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.luxGreen : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.luxGreen).frame(width: 12, height: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("\(minutes) min a day")
                            .font(.headline)
                        Text("· \(label)")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        Text("Complete all lessons in \(estimate)")
                            .font(.caption).foregroundColor(.secondary)
                        if isRecommended {
                            Text("Recommended")
                                .font(.caption2).fontWeight(.semibold)
                                .foregroundColor(.luxGreen)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.luxGreen.opacity(0.12))
                                .cornerRadius(6)
                        }
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(isSelected ? Color.luxGreen.opacity(0.08) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.luxGreen : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.luxQuick, value: isSelected)
    }
}
