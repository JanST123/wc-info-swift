import SwiftUI
import CoreLocation

struct ToiletRowView: View {
    let toilet: Toilet
    let userLocation: CLLocationCoordinate2D?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(toilet.displayName)
                        .font(.headline)
                    Spacer()
                    if let distance = formattedDistance {
                        Text(distance)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Entfernung \(distance)")
                    }
                }

                Text("WC #\(toilet.id)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let address = toilet.address, !address.isEmpty {
                    Label(address, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    if toilet.hasWheelchairAccess {
                        FeatureBadge(label: "Rollstuhlgerecht", icon: "wheelchair")
                    }
                    if toilet.hasChangingTable {
                        FeatureBadge(label: "Wickeltisch", icon: "figure.and.child.holdinghands")
                    }
                    if !toilet.isGenderSeparated {
                        FeatureBadge(label: "Unisex", icon: "person.2")
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tippe doppelt, um diese Toilette auf der Karte anzuzeigen.")
    }

    private var accessibilityLabel: String {
        var parts = [toilet.displayName, "WC Nummer \(toilet.id)"]
        if let address = toilet.address, !address.isEmpty {
            parts.append(address)
        }
        if let distance = formattedDistance {
            parts.append("Entfernung \(distance)")
        }
        if toilet.hasWheelchairAccess { parts.append("Rollstuhlgerecht") }
        if toilet.hasChangingTable { parts.append("Wickeltisch") }
        if !toilet.isGenderSeparated { parts.append("Unisex") }
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

private struct FeatureBadge: View {
    let label: String
    let icon: String

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.12))
            .foregroundColor(.purple)
            .clipShape(Capsule())
    }
}
