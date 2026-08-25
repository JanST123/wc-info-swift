import Foundation
import SwiftUI
import Sentry

@MainActor
final class ErrorManager: ObservableObject {
    static let shared = ErrorManager()

    @Published var currentError: UserError?

    private init() {}

    /// Reports an error to Sentry and, if `showToUser` is true, displays a single non-flooding message.
    func report(
        _ error: Error,
        context: [String: Any] = [:],
        showToUser: Bool = true
    ) {
        let userError = UserError(error: error)

        let sentryEvent = Sentry.Event(level: .error)
        sentryEvent.message = SentryMessage(formatted: userError.message)
        sentryEvent.extra = context
        SentrySDK.capture(event: sentryEvent)

        guard showToUser else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            currentError = userError
        }

        // Auto-dismiss after a delay so the user isn't blocked forever.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.clear()
        }
    }

    func reportMessage(
        _ message: String,
        context: [String: Any] = [:],
        showToUser: Bool = true
    ) {
        let userError = UserError(message: message)

        let sentryEvent = Sentry.Event(level: .error)
        sentryEvent.message = SentryMessage(formatted: message)
        sentryEvent.extra = context
        SentrySDK.capture(event: sentryEvent)

        guard showToUser else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            currentError = userError
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.clear()
        }
    }

    func clear() {
        guard currentError != nil else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentError = nil
        }
    }
}

struct UserError: Identifiable, Equatable {
    let id = UUID()
    let message: String

    init(message: String) {
        self.message = message
    }

    init(error: Error) {
        if let apiError = error as? WCInfoAPIError,
           let message = apiError.message {
            self.message = message
        } else {
            self.message = error.localizedDescription
        }
    }

    static func == (lhs: UserError, rhs: UserError) -> Bool {
        lhs.id == rhs.id
    }
}

struct ErrorBannerView: View {
    @StateObject private var manager = ErrorManager.shared

    var body: some View {
        VStack {
            if let error = manager.currentError {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .accessibilityHidden(true)
                    Text(error.message)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        manager.clear()
                    } label: {
                        Image(systemName: "xmark")
                            .accessibilityLabel("Fehlermeldung schließen")
                    }
                }
                .padding()
                .background(Color.red.opacity(0.95))
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)
                .accessibilityElement(children: .combine)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
    }
}
