import SwiftUI
import MapKit

struct DetailView: View {
    @Environment(\.dismiss) private var dismiss
    let toilet: Toilet
    @State private var selectedPhotoIndex: Int? = nil

    var body: some View {
        NavigationStack {
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

                    if !toilet.photos.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fotos")
                                .font(.subheadline.bold())

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(toilet.photos.enumerated()), id: \.offset) { index, photo in
                                        Button {
                                            selectedPhotoIndex = index
                                        } label: {
                                            AsyncImage(url: URL(string: photo.urlThumb)) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView()
                                                        .frame(width: 100, height: 100)
                                                        .background(Color(uiColor: .secondarySystemBackground))
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 100, height: 100)
                                                        .clipped()
                                                case .failure:
                                                    Image(systemName: "photo")
                                                        .font(.title2)
                                                        .foregroundColor(.secondary)
                                                        .frame(width: 100, height: 100)
                                                        .background(Color(uiColor: .secondarySystemBackground))
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                    .accessibilityLabel("Details schließen")
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { selectedPhotoIndex != nil },
                set: { if !$0 { selectedPhotoIndex = nil } }
            )) {
                if let index = selectedPhotoIndex {
                    PhotoLightboxView(photos: toilet.photos, selectedIndex: index)
                }
            }
        }
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
