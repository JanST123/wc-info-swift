import SwiftUI
import CoreLocation

struct ToiletRowView: View {
    let toilet: Toilet
    let userLocation: CLLocationCoordinate2D?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(toilet.displayName)
                    .font(.headline)
                Spacer()
                if let distance = formattedDistance {
                    Text(distance)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
        }
        .padding(.vertical, 4)
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
