import SwiftUI

struct ToiletSymbolComponent: View {
    let isGenderSeparated: Bool
    let hasWheelchairAccess: Bool
    let hasChangingTable: Bool
    let isUnisex: Bool
    var hasEuroKey: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if isGenderSeparated {
                toiletIcon("restroom-solid-full", label: "Getrennte Toiletten")
            }
            if hasWheelchairAccess {
                toiletIcon("wheelchair-solid-full", label: "Rollstuhlgerecht")
            }
            if hasEuroKey {
                Image(systemName: "key.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundColor(.purple)
                    .accessibilityLabel("Euroschlüssel erforderlich")
            }
            if hasChangingTable {
                toiletIcon("baby-solid-full", label: "Wickeltisch")
            }
            if isUnisex && !isGenderSeparated {
                toiletIcon("toilet-paper-solid-full", label: "Unisex")
            }
        }
        .frame(height: 20)
    }

    private func toiletIcon(_ name: String, label: String) -> some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .foregroundColor(.purple)
            .accessibilityLabel(label)
    }
}

// A SwiftUI preview.
#Preview {
    ResultsView(location: .init(name: "Much-Niederheimbach", coordinate: .init(latitude: 50.895725646813936, longitude: 7.355648585165031)))
}
