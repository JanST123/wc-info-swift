import SwiftUI
import CoreLocation

struct ToiletRowView: View {
    let toilet: Toilet
    let userLocation: CLLocationCoordinate2D?
    var isActive: Bool = false
    var onShowDetails: () -> Void = {}
    var onNavigate: () -> Void = {}
    var onPhotosUpdated: (() -> Void)? = nil

    @State private var selectedPhotoIndex: Int? = nil
    @State private var showingNonPublicInfo = false

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
        .alert("Nicht-öffentliche Toilette", isPresented: $showingNonPublicInfo) {
            Button("Verstanden", role: .cancel) { }
        } message: {
            Text("Diese Toilette ist nicht öffentlich zugänglich. Sie befindet sich beispielsweise in einem Restaurant, Geschäft oder einer privaten Einrichtung und ist oft Kunden oder Gästen vorbehalten.")
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedPhotoIndex != nil },
            set: { if !$0 { selectedPhotoIndex = nil } }
        )) {
            if let index = selectedPhotoIndex {
                PhotoLightboxView(
                    toiletId: toilet.id,
                    photos: toilet.photos,
                    selectedIndex: index,
                    onPhotoDeleted: {
                        onPhotosUpdated?()
                    }
                )
            }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(toilet.owner)
                            .font(.headline.bold())

                        if toilet.isQualified {
                            QualifiedBadgeView(iconSize: 15)
                        }
                    }

                    Text(toilet.name)
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    OpeningTimeComponent(
                        hasOpeningHours: toilet.placeOpeningHours != nil,
                        isOpen: toilet.isOpen24HoursEveryDay ? true : toilet.isOpen,
                        openTimestamp: toilet.isOpen24HoursEveryDay ? nil : toilet.openTimestamp,
                        closeTimestamp: toilet.isOpen24HoursEveryDay ? nil : toilet.closeTimestamp,
                        accessibleOutsideOpeningTimes: toilet.accessibleOutsideOpeningTimes,
                        isOpen24Hours: toilet.isOpen24HoursEveryDay
                    )

                    if !toilet.isPublicAccessible {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)

                            Text("Nicht öffentlich")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Button {
                                showingNonPublicInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Informationen zu nicht-öffentlichen Toiletten")
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingNonPublicInfo = true
                        }
                    }
                }
            }

            if !toilet.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
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
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            
            Spacer(minLength: 8)

            ToiletSymbolComponent(
                isGenderSeparated: toilet.isGenderSeparated,
                hasWheelchairAccess: toilet.hasWheelchairAccess,
                hasChangingTable: toilet.hasChangingTable,
                isUnisex: toilet.isUnisex,
                hasEuroKey: toilet.euroKey?.lowercased() == "yes" || toilet.euroKey?.lowercased() == "true" || toilet.euroKey == "1"
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
        if !toilet.isPublicAccessible {
            parts.append("Nicht öffentlich zugänglich")
        }
        if let address = toilet.address, !address.isEmpty {
            parts.append(address)
        }
        if let distance = formattedDistance {
            parts.append("Entfernung \(distance)")
        }
        if toilet.isQualified { parts.append("Geprüfte Toilette") }
        if toilet.hasWheelchairAccess { parts.append("Rollstuhlgerecht") }
        if toilet.euroKey?.lowercased() == "yes" || toilet.euroKey?.lowercased() == "true" || toilet.euroKey == "1" {
            parts.append("Euroschlüssel")
        }
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
