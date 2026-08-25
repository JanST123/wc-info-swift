import SwiftUI

struct ToiletSymbolComponent: View {
    let isGenderSeparated: Bool
    let hasWheelchairAccess: Bool
    let hasChangingTable: Bool
    let isUnisex: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isGenderSeparated {
                icon("toiletGenderSeparated", label: "Getrennte Toiletten")
            }
            if hasWheelchairAccess {
                icon("toiletAccessible", label: "Rollstuhlgerecht")
            }
            if hasChangingTable {
                icon("toiletChangingTable", label: "Wickeltisch")
            }
            if isUnisex {
                icon("toiletUnisex", label: "Unisex")
            }
        }
        .frame(height: 16)
    }

    private func icon(_ name: String, label: String) -> some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(height: 16)
            .foregroundColor(.purple)
            .accessibilityLabel(label)
    }
}
