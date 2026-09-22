import SwiftUI

struct EmergencyLoadingOverlayView: View {
    @ObservedObject private var emergencyManager = EmergencyNavigationManager.shared

    var body: some View {
        if emergencyManager.isSearching {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 72, height: 72)

                        Image(systemName: "location.north.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            .scaleEffect(1.6)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 6) {
                        Text("Notfall-Navigation")
                            .font(.headline.bold())
                            .foregroundColor(.primary)

                        if let message = emergencyManager.statusMessage {
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Button("Abbrechen") {
                        withAnimation {
                            emergencyManager.isSearching = false
                            emergencyManager.statusMessage = nil
                        }
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
                .padding(24)
                .frame(maxWidth: 300)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
                .transition(.scale.combined(with: .opacity))
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: emergencyManager.isSearching)
        }
    }
}
