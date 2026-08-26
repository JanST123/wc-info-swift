import SwiftUI
import MapKit

struct DetailView: View {
    let toilet: Toilet

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(toilet.name)
                    .font(.title.bold())
                    .accessibilityLabel("Name: \(toilet.name)")

                Label("Betreiber: \(toilet.owner)", systemImage: "building.2")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Betreiber: \(toilet.owner)")

                Button(action: navigateToToilet) {
                    HStack {
                        Image(systemName: "arrow.turn.up.right")
                        Text("Navigieren")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Navigieren zu \(toilet.name)")
                .accessibilityHint("Öffnet die Karten-App mit der Route zur Toilette.")

                if let address = toilet.address, !address.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Adresse")
                            .font(.subheadline.bold())
                        Text(address)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Adresse: \(address)")
                }

                if let periods = toilet.placeOpeningHours, !periods.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Öffnungszeiten")
                            .font(.subheadline.bold())
                        ForEach(periods.indices, id: \.self) { index in
                            Text(periods[index].formatted)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Öffnungszeiten: \(periods.map(\.formatted).joined(separator: ", "))")
                }

                Spacer(minLength: 40)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Analytics.shared.trackScreen("Detail")
            Analytics.shared.trackEvent(category: "detail", action: "view", name: toilet.name)
        }
    }

    private func navigateToToilet() {
        Analytics.shared.trackEvent(category: "detail", action: "navigate", name: toilet.name)
        let coordinate = CLLocationCoordinate2D(latitude: toilet.lat, longitude: toilet.lon)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = toilet.name
        MKMapItem.openMaps(with: [mapItem], launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ])
    }
}
