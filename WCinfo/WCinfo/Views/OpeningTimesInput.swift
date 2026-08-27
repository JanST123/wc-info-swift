import SwiftUI

struct OpeningTimesInput: View {
    @Binding var openingHours: [String]?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .foregroundColor(.purple)
                Text("Öffnungszeiten")
                    .font(.subheadline.bold())
            }

            Text("Hier können Öffnungszeiten im Detail eingetragen werden (wird in Kürze erweitert).")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
