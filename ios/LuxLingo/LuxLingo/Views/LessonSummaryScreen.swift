import SwiftUI

// MARK: - Lesson Summary Screen
struct LessonSummaryScreen: View {
    let masteredSenses: [String]
    var sessionXP: Int = 0
    let onBackToMenu: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Celebration
            Text("🎉")
                .font(.system(size: 64))

            Text("Lesson Complete!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.luxGreen)

            // XP Earned
            if sessionXP > 0 {
                VStack(spacing: 8) {
                    Text("XP Earned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("+\(sessionXP)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.luxGreen)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color.luxGreen.opacity(0.08))
                .cornerRadius(16)
            }

            // Mastered words
            VStack(spacing: 8) {
                Text("You mastered:")
                    .font(.headline)

                ForEach(masteredSenses, id: \.self) { word in
                    Text(word)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                onBackToMenu()
            } label: {
                Text("Back to Menu")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.luxGreen)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.bottom, 32)
        }
        .padding(16)
    }
}
