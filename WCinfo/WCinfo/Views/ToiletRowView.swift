import SwiftUI
import CoreLocation

struct ToiletRowView: View {
    let toilet: Toilet
    let userLocation: CLLocationCoordinate2D?
    var isActive: Bool = false
    var onShowDetails: () -> Void = {}
    var onNavigate: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            rowContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint("Tippe doppelt, um diese Toilette auf der Karte anzuzeigen.")
                .accessibilityAddTraits(.isButton)

            if isActive {
                Spacer(minLength: 8)
                HStack(spacing: 16) {
                    Button(action: onNavigate) {
                        Label("Navigieren", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.footnote.bold())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .accessibilityHint("Startet die Routenführung zu dieser Toilette.")

                    Spacer()
                    
                    Button(action: onShowDetails) {
                        Text("Details ansehen ›")
                            .font(.footnote.bold())
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityHint("Öffnet die Detailansicht.")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(toilet.owner)
                        .font(.headline.bold())

                    Text(toilet.name)
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 12)

                OpeningTimeComponent(
                    isOpen: toilet.isOpen,
                    openTimestamp: toilet.openTimestamp,
                    closeTimestamp: toilet.closeTimestamp
                )
            }
            
            Spacer(minLength: 8)

            ToiletSymbolComponent(
                isGenderSeparated: toilet.isGenderSeparated,
                hasWheelchairAccess: toilet.hasWheelchairAccess,
                hasChangingTable: toilet.hasChangingTable,
                isUnisex: toilet.isUnisex
            )

            HStack(alignment: .bottom, spacing: 12) {
                if let address = toilet.address, !address.isEmpty {
                    Text(address)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                Spacer(minLength: 12)

                if let distance = formattedDistance {
                    Text(distance)
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private var accessibilityLabel: String {
        var parts = [toilet.owner, toilet.name]
        if let address = toilet.address, !address.isEmpty {
            parts.append(address)
        }
        if let distance = formattedDistance {
            parts.append("Entfernung \(distance)")
        }
        if toilet.hasWheelchairAccess { parts.append("Rollstuhlgerecht") }
        if toilet.hasChangingTable { parts.append("Wickeltisch") }
        if toilet.isGenderSeparated { parts.append("Getrennte Toiletten") }
        if toilet.isUnisex { parts.append("Unisex") }
        return parts.joined(separator: ", ")
    }

    private var formattedDistance: String? {
        if let distance = toilet.distance {
            if distance < 1 {
                return String(format: "%.0f m", distance * 1000)
            } else {
                return String(format: "%.1f km", distance)
            }
        }
        guard let userLocation else { return nil }
        let location = CLLocation(latitude: toilet.coordinate.latitude, longitude: toilet.coordinate.longitude)
        let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let meters = location.distance(from: userLoc)
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }
}
