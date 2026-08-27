import SwiftUI

struct QualifiedBadgeView: View {
    var iconSize: CGFloat = 16
    @State private var showInfo = false

    var body: some View {
        Button {
            showInfo = true
        } label: {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(.green)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Geprüfte Toilette. Tippe für weitere Informationen.")
        .popover(isPresented: $showInfo) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundColor(.green)

                    Text("Geprüfte Angaben")
                        .font(.headline)
                }

                Text("Die Angaben und Ausstattungsmerkmale dieser Toilette wurden von Gästen oder dem Betreiber überprüft und bestätigt.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: 280)
            .presentationCompactAdaptation(.popover)
        }
    }
}
