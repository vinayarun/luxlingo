import SwiftUI

struct ZipfsSpeedRunView: View {
    let word: String
    let translation: String
    let isCorrect: Bool // Is the proposed translation correct?
    let timeRemaining: Float // 0.0 to 1.0
    let onSwipe: (Bool) -> Void // User input (true = swipe right/correct, false = swipe left/wrong)
    
    @State private var offset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 32) {
            // Timer Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(timerColor)
                        .frame(width: geo.size.width * CGFloat(timeRemaining), height: 8)
                        .shadow(color: timerColor.opacity(0.5), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 8)
            .padding(.horizontal)
            .scaleEffect(timeRemaining < 0.3 ? 1.05 : 1.0)
            .animation(timeRemaining < 0.3 ? .easeInOut(duration: 0.2).repeatForever(autoreverses: true) : .default, value: timeRemaining < 0.3)
            
            Spacer()
            
            // Flash Card
            ZStack {
                VStack(spacing: 20) {
                    Text(word)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Divider()
                        .frame(width: 100)
                    
                    Text("Does it mean: **'\(translation)'**?")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .frame(maxWidth: .infinity)
                .minHeight(300)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(offset == .zero ? 0.1 : 0.2), radius: 10, y: 5)
                )
                .scaleEffect(offset == .zero ? 1.0 : 0.95)
                .offset(x: offset.width, y: offset.height * 0.4)
                .rotationEffect(.degrees(Double(offset.width / 20)))
                .animation(.interactiveSpring, value: offset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            offset = gesture.translation
                        }
                        .onEnded { gesture in
                            if gesture.translation.width > 100 {
                                // Swipe Right -> True
                                triggerHaptic(style: .medium)
                                onSwipe(true)
                                reset()
                            } else if gesture.translation.width < -100 {
                                // Swipe Left -> False
                                triggerHaptic(style: .medium)
                                onSwipe(false)
                                reset()
                            } else {
                                withAnimation(.luxSpring) {
                                    offset = .zero
                                }
                            }
                        }
                )
            }
            .padding(.horizontal)
            
            // Swipe Hints
            HStack {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("FALSE")
                }
                .foregroundColor(.luxRed)
                .bold()
                .opacity(offset.width < -20 ? 1.0 : 0.3)
                
                Spacer()
                
                HStack {
                    Text("TRUE")
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.luxGreen)
                .bold()
                .opacity(offset.width > 20 ? 1.0 : 0.3)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var timerColor: Color {
        if timeRemaining < 0.2 { return .luxRed }
        if timeRemaining < 0.5 { return .luxAmber }
        return .luxGreen
    }
    
    private func reset() {
        offset = .zero
    }

    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

extension View {
    func minHeight(_ height: CGFloat) -> some View {
        frame(minHeight: height)
    }
}

// MARK: - Speed Run Countdown
struct SpeedRunCountdownView: View {
    let count: Int
    let isRapidFire: Bool

    var body: some View {
        VStack(spacing: 20) {
            if isRapidFire {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                    Text("RAPID FIRE")
                    Image(systemName: "bolt.fill")
                }
                .font(.title2.weight(.heavy))
                .foregroundColor(.luxAmber)
            } else {
                Text("Get ready!")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            Text("\(count)")
                .font(.system(size: 100, weight: .heavy, design: .rounded))
                .foregroundColor(.luxGreen)
                .id(count)
                .transition(.asymmetric(
                    insertion: .scale(scale: 1.4).combined(with: .opacity),
                    removal: .scale(scale: 0.6).combined(with: .opacity)
                ))

            Text(isRapidFire ? "Swipe right for TRUE, left for FALSE" : "Swipe right for TRUE, left for FALSE")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: count)
    }
}
