import SwiftUI

struct ToiletSymbolComponent: View {
    let isGenderSeparated: Bool
    let hasWheelchairAccess: Bool
    let hasChangingTable: Bool
    let isUnisex: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isGenderSeparated {
                icon("toiletIconGenderSeparated", label: "Getrennte Toiletten")
            }
            if hasWheelchairAccess {
                icon("toiletIconWheelchair", label: "Rollstuhlgerecht")
            }
            if hasChangingTable {
                icon("toiletIconChangingTable", label: "Wickeltisch")
            }
            if isUnisex {
                icon("toiletIconUnisex", label: "Unisex")
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
