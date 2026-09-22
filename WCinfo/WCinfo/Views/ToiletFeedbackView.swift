import SwiftUI

struct ToiletFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    let toilet: Toilet

    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showSuccessAlert: Bool = false

    private var suggestedSubjects: [String] {
        [
            String(localized: "Toilette existiert nicht"),
            String(localized: "Toilette überprüfen"),
            String(localized: "Toilette wurde verlegt"),
            String(localized: "Toilette gehört woanders hin")
        ]
    }

    private var isFormValid: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    toiletInfoCard

                    subjectSection

                    messageSection

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    submitButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle("Feedback geben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .accessibilityLabel(Text("Feedback abbrechen"))
                }
            }
            .alert("Vielen Dank!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Danke für dein Feedback! Wir kümmern uns so schnell es geht.")
            }
            .onAppear {
                Analytics.shared.trackScreen("ToiletFeedback")
            }
        }
    }

    // MARK: - Subviews

    private var toiletInfoCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(toilet.displayName)
                .font(.headline)
                .foregroundStyle(.primary)

            if !toilet.owner.isEmpty {
                Text("Betreiber: \(toilet.owner)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let address = toilet.address, !address.isEmpty {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Betreff")
                .font(.subheadline.bold())

            // Quick suggestion chips
            FlowLayout(spacing: 8) {
                ForEach(suggestedSubjects, id: \.self) { suggestion in
                    let isSelected = subject == suggestion
                    Button {
                        if isSelected {
                            subject = ""
                        } else {
                            subject = suggestion
                        }
                    } label: {
                        Text(suggestion)
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.purple : Color(uiColor: .secondarySystemBackground))
                            .foregroundColor(isSelected ? .white : .primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.purple : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Vorschlag: \(suggestion)"))
                }
            }

            TextField("Betreff eingeben oder auswählen...", text: $subject, prompt: Text("Betreff eingeben oder auswählen..."))
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel(Text("Betreff Eingabefeld"))
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Nachricht")
                    .font(.subheadline.bold())
                Text("(optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Beschreibe das Problem oder die gewünschten Änderungen...", text: $message, prompt: Text("Beschreibe das Problem oder die gewünschten Änderungen..."), axis: .vertical)
                .lineLimit(4...8)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel(Text("Optionale Nachricht eingeben"))
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.caption)
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(Text("Fehler: \(message)"))
    }

    private var submitButton: some View {
        Button(action: submitFeedback) {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                }
                Text("Feedback senden")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFormValid && !isSubmitting ? Color.purple : Color.gray.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!isFormValid || isSubmitting)
        .accessibilityLabel(Text("Feedback senden"))
    }

    // MARK: - Actions

    private func submitFeedback() {
        guard isFormValid else { return }

        errorMessage = nil
        isSubmitting = true

        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = SendToiletFeedbackRequest(
            subject: trimmedSubject,
            message: trimmedMessage
        )

        Task {
            do {
                _ = try await WCInfoAPIService.shared.sendToiletFeedback(toiletId: toilet.id, payload: payload)
                Analytics.shared.trackEvent(category: "feedback", action: "submit", name: String(toilet.id))
                isSubmitting = false
                showSuccessAlert = true
            } catch {
                isSubmitting = false
                if let apiError = error as? WCInfoAPIError, let errorMsg = apiError.message {
                    errorMessage = errorMsg
                } else {
                    errorMessage = error.localizedDescription
                }
                ErrorManager.shared.report(
                    error,
                    context: [
                        "action": "sendToiletFeedback",
                        "toiletId": toilet.id,
                        "subject": trimmedSubject
                    ],
                    showToUser: false
                )
            }
        }
    }
}

// MARK: - Flow Layout for chips

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return CGSize(width: width, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
    }
}
