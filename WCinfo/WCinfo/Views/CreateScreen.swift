import SwiftUI

struct CreateScreen: View {
    @Environment(\.dismiss) private var dismiss
    var location: SearchedLocation?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)

                Text("Toilette hinzufügen")
                    .font(.title2.bold())

                Text("Hier kannst du in Kürze eine neue Toilette eintragen.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Toilette hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .accessibilityLabel("Abbrechen")
                }
            }
            .onAppear {
                Analytics.shared.trackScreen("CreateToilet")
            }
        }
    }
}

#Preview {
    CreateScreen()
}
