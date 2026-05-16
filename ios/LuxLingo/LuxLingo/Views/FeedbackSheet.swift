import SwiftUI
import MessageUI

private let FEEDBACK_EMAIL = "luxlingo.app@gmail.com"   // ← swap with your address

struct FeedbackSheet: View {
    let lessonId:     String
    let exerciseType: String
    let sentenceLu:   String
    let targetWord:   String

    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText  = ""
    @State private var showMailView  = false
    @State private var showCopied    = false
    @State private var mailError     = false

    private let maxChars = 500

    private var autoContext: String {
        var parts: [String] = []
        if !lessonId.isEmpty && lessonId != "review" {
            parts.append("Lesson: \(lessonId.replacingOccurrences(of: "lesson_", with: ""))")
        }
        if !exerciseType.isEmpty  { parts.append("Exercise: \(exerciseType)") }
        if !targetWord.isEmpty    { parts.append("Word: \(targetWord)") }
        if !sentenceLu.isEmpty    { parts.append("Sentence: \(sentenceLu)") }
        return parts.joined(separator: "\n")
    }

    private var canSend: Bool {
        !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {

                // Auto-context (read-only)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Exercise context")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(autoContext)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }

                // Feedback input
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your feedback")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                        TextEditor(text: $feedbackText)
                            .padding(8)
                            .frame(minHeight: 120)
                            .onChange(of: feedbackText) {
                                if feedbackText.count > maxChars {
                                    feedbackText = String(feedbackText.prefix(maxChars))
                                }
                            }
                        if feedbackText.isEmpty {
                            Text("Describe the issue or suggestion…")
                                .foregroundColor(Color(.placeholderText))
                                .padding(14)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(minHeight: 130)

                    HStack {
                        Spacer()
                        Text("\(feedbackText.count)/\(maxChars)")
                            .font(.caption2)
                            .foregroundColor(feedbackText.count > maxChars - 50 ? .luxAmber : .secondary)
                    }
                }

                if showCopied {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard.fill").foregroundColor(.luxGreen)
                        Text("Copied! Send it to \(FEEDBACK_EMAIL)")
                            .font(.subheadline)
                    }
                }

                Spacer()

                // Send button
                Button {
                    guard canSend else { return }
                    if MFMailComposeViewController.canSendMail() {
                        showMailView = true
                    } else {
                        // No mail app — copy to clipboard instead
                        let full = "Feedback:\n\(feedbackText)\n\n---\n\(autoContext)"
                        UIPasteboard.general.string = full
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { dismiss() }
                    }
                } label: {
                    Text(canSend ? "Send Feedback" : "Write something first")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSend ? Color.luxGreen : Color(.systemGray4))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .disabled(!canSend)
            }
            .padding(20)
            .navigationTitle("Report an Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showMailView) {
                MailComposeView(
                    subject:   "LuxLingo Feedback — \(lessonId)",
                    body:      "\(feedbackText)\n\n---\n\(autoContext)",
                    recipient: FEEDBACK_EMAIL,
                    onDismiss: { dismiss() }
                )
            }
        }
    }
}

// MARK: - MFMailComposeViewController wrapper

struct MailComposeView: UIViewControllerRepresentable {
    let subject:   String
    let body:      String
    let recipient: String
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.setToRecipients([recipient])
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            controller.dismiss(animated: true) { self.onDismiss() }
        }
    }
}
