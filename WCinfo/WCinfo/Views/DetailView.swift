import SwiftUI
import MapKit

struct DetailView: View {
    @Environment(\.dismiss) private var dismiss
    let toilet: Toilet
    var onPhotosUpdated: (() -> Void)? = nil
    var onRequestEdit: ((Toilet) -> Void)? = nil
    @State private var selectedPhotoIndex: Int? = nil
    @State private var isShowingPhotoUploadSheet = false
    @State private var isShowingEuroKeyInfoSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                            onRequestEdit?(toilet)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                Text("Änderungen vorschlagen")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.purple)
                        }
                        .accessibilityLabel("Änderungen für diese Toilette vorschlagen")
                    }

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
                    
                    // Features checklist
                    VStack(alignment: .leading, spacing: 8) {
                        

                        HStack(alignment: .center, spacing: 8) {
                            featureStatusIcon(isAvailable: toilet.isGenderSeparated)
                            Text("Nach Geschlecht getrennte Toiletten vorhanden")
                                .font(.body)
                        }

                        HStack(alignment: .center, spacing: 8) {
                            featureStatusIcon(isAvailable: toilet.hasWheelchairAccess)
                            Text("Barrierefreie Toilette vorhanden")
                                .font(.body)
                        }

                        if toilet.hasWheelchairAccess || toilet.euroKey != nil {
                            HStack(alignment: .center, spacing: 8) {
                                euroKeyStatusIcon(toilet.euroKey)
                                Text("Kann mit Euroschlüssel geöffnet werden")
                                    .font(.body)

                                Button {
                                    isShowingEuroKeyInfoSheet = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.body)
                                        .foregroundColor(.purple)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Informationen zum Euroschlüssel")
                            }
                        }

                        HStack(alignment: .center, spacing: 8) {
                            featureStatusIcon(isAvailable: toilet.hasChangingTable)
                            Text("Wickelraum vorhanden")
                                .font(.body)
                        }
                    }
                    .padding(.vertical, 2)

                    Spacer(minLength: 4)

                    // Photos Section with thumbnails and upload button
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

                                // Upload photo button (always visible)
                                Button {
                                    isShowingPhotoUploadSheet = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 26))
                                        Image(systemName: "plus")
                                            .font(.system(size: 20, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(width: 100, height: 100)
                                    .background(Color.purple)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(color: Color.purple.opacity(0.3), radius: 3, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Foto hinzufügen")
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    
                    Spacer(minLength: 4)

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
            .sheet(isPresented: $isShowingPhotoUploadSheet) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            PhotoUpload(
                                toiletId: toilet.id,
                                onPhotoUploaded: { _ in
                                    onPhotosUpdated?()
                                }
                            )
                            .padding()
                        }
                    }
                    .navigationTitle("Fotos hochladen")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fertig") {
                                isShowingPhotoUploadSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingEuroKeyInfoSheet) {
                EuroKeyInfoView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            Analytics.shared.trackScreen("Detail")
            Analytics.shared.trackEvent(category: "detail", action: "view", name: toilet.name)
        }
    }

    @ViewBuilder
    private func featureStatusIcon(isAvailable: Bool) -> some View {
        if isAvailable {
            Image(systemName: "checkmark")
                .font(.body.bold())
                .foregroundColor(.green)
                .frame(width: 20)
        } else {
            Image(systemName: "xmark")
                .font(.body.bold())
                .foregroundColor(.red)
                .frame(width: 20)
        }
    }

    @ViewBuilder
    private func euroKeyStatusIcon(_ status: String?) -> some View {
        switch status?.lowercased() {
        case "yes", "true", "1":
            Image(systemName: "checkmark")
                .font(.body.bold())
                .foregroundColor(.green)
                .frame(width: 20)
        case "no", "false", "0":
            Image(systemName: "xmark")
                .font(.body.bold())
                .foregroundColor(.red)
                .frame(width: 20)
        default:
            Image(systemName: "questionmark")
                .font(.body.bold())
                .foregroundColor(.orange)
                .frame(width: 20)
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
