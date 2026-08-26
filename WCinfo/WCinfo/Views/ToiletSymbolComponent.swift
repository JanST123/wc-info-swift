import SwiftUI

struct ToiletSymbolComponent: View {
    let isGenderSeparated: Bool
    let hasWheelchairAccess: Bool
    let hasChangingTable: Bool
    let isUnisex: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isGenderSeparated {
                systemIcon("person.2", label: "Getrennte Toiletten")
            }
            if hasWheelchairAccess {
                systemIcon("accessibility", label: "Rollstuhlgerecht")
            }
            if hasChangingTable {
                systemIcon("baby.fill", label: "Wickeltisch")
            }
            if isUnisex {
                systemIcon("person", label: "Unisex")
            }
        }
        .frame(height: 20)
    }

    private func systemIcon(_ name: String, label: String) -> some View {
        Image(systemName: name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .foregroundColor(.purple)
            .accessibilityLabel(label)
    }
}
