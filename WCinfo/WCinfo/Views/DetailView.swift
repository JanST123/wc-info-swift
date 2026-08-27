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
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(toilet.name)
                            .font(.title.bold())
                            .accessibilityLabel("Name: \(toilet.name)")

                        if toilet.isQualified {
                            QualifiedBadgeView(iconSize: 22)
                        }
                    }

                    Label("Betreiber: \(toilet.owner)", systemImage: "building.2")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .accessibilityLabel("Betreiber: \(toilet.owner)")

                    if toilet.isPublicAccessible {
                        Label("Öffentlich zugänglich", systemImage: "figure.walk")
                            .font(.body)
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Öffentlich zugängliche Toilette")
                    }
                    
                    Spacer(minLength: 4)

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
                    
                    Spacer(minLength: 4)

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
                        
                        Spacer(minLength: 4)
                    }

                   

                    if let periods = toilet.placeOpeningHours, !periods.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Öffnungszeiten")
                                .font(.subheadline.bold())

                            OpeningTimeComponent(
                                hasOpeningHours: true,
                                isOpen: toilet.isOpen,
                                openTimestamp: toilet.openTimestamp,
                                closeTimestamp: toilet.closeTimestamp,
                                accessibleOutsideOpeningTimes: toilet.accessibleOutsideOpeningTimes,
                                alignment: .leading
                            )
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            ForEach(periods.indices, id: \.self) { index in
                                Text(periods[index].formatted)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Öffnungszeiten: \(periods.map(\.formatted).joined(separator: ", "))")
                        
                        Spacer(minLength: 4)
                        
                    } else if toilet.accessibleOutsideOpeningTimes {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Öffnungszeiten")
                                .font(.subheadline.bold())

                            OpeningTimeComponent(
                                hasOpeningHours: false,
                                isOpen: toilet.isOpen,
                                openTimestamp: toilet.openTimestamp,
                                closeTimestamp: toilet.closeTimestamp,
                                accessibleOutsideOpeningTimes: toilet.accessibleOutsideOpeningTimes,
                                alignment: .leading
                            )
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        Spacer(minLength: 4)
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
                        
                        Spacer(minLength: 4)
                    }

                    if let storageSpace = toilet.storageSpace, let title = storageTitle(for: storageSpace) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ablagefläche")
                                .font(.subheadline.bold())

                            HStack(spacing: 10) {
                                if let iconName = storageIconName(for: storageSpace) {
                                    Image(iconName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .padding(6)
                                        .background(Color.purple)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                Text(title)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Ablagefläche: \(title)")
                        
                        Spacer(minLength: 4)
                    }

                    if let website = toilet.website, !website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let trimmed = website.trimmingCharacters(in: .whitespacesAndNewlines)
                        let url: URL? = {
                            if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
                                return URL(string: trimmed)
                            } else {
                                return URL(string: "https://" + trimmed)
                            }
                        }()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Webseite")
                                .font(.subheadline.bold())

                            if let url {
                                Link(destination: url) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "safari")
                                        Text(trimmed)
                                            .underline()
                                    }
                                    .font(.body)
                                    .foregroundColor(.purple)
                                }
                            } else {
                                Text(trimmed)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Webseite: \(trimmed)")
                        
                        Spacer(minLength: 4)
                    }
                    
                    if let comment = toilet.comment, !comment.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bemerkung")
                                .font(.subheadline.bold())
                            Text(comment)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Bemerkung: \(comment)")
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

    private func storageIconName(for value: String) -> String? {
        switch value.lowercased() {
        case "none":
            return "storage-none"
        case "little":
            return "storage-little"
        case "much":
            return "storage-much"
        default:
            return nil
        }
    }

    private func storageTitle(for value: String) -> String? {
        switch value.lowercased() {
        case "none":
            return "Keine"
        case "little":
            return "Wenig"
        case "much":
            return "Viel"
        default:
            return nil
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
