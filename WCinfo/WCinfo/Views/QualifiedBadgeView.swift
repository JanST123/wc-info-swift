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
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundColor(.green)

                    Text("Geprüfte Angaben")
                        .font(.headline)
                }

                Text("Von anderen Gästen oder dem Betreiber vor Ort bestätigt.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 290)
            .presentationCompactAdaptation(.popover)
        }
    }
}
