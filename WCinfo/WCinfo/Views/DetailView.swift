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
    @State private var isShowingEditOptions = false
    @State private var isShowingFeedbackSheet = false
    @State private var isShowingNavigationOptions = false
    @State private var isShowingCompassNavigation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    editButtonSection
                    headerSection
                    navigationButton
                    featuresSection
                    photosSection
                    openingHoursSection
                    addressSection
                    storageSpaceSection
                    websiteSection
                    commentSection
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
                    .accessibilityLabel(Text("Details schließen"))
                }
            }
            .confirmationDialog(
                "Änderungen vorschlagen",
                isPresented: $isShowingEditOptions,
                titleVisibility: .visible
            ) {
                Button("Problem oder Feedback melden") {
                    isShowingFeedbackSheet = true
                }
                Button("Angaben selbst bearbeiten") {
                    dismiss()
                    onRequestEdit?(toilet)
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Möchtest du eine kurze Rückmeldung als Text senden oder die Angaben im Formular anpassen?")
            }
            .confirmationDialog(
                "Navigation starten",
                isPresented: $isShowingNavigationOptions,
                titleVisibility: .visible
            ) {
                Button("Kompass") {
                    isShowingCompassNavigation = true
                }
                Button("Karten-App") {
                    navigateToToilet()
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Wähle zwischen der internen Kompass-Navigation und der externen Karten-App.")
            }
            .sheet(isPresented: $isShowingFeedbackSheet) {
                ToiletFeedbackView(toilet: toilet)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingCompassNavigation) {
                CompassNavigationView(toilet: toilet)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
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
            .sheet(isPresented: $isShowingPhotoUploadSheet) {
                photoUploadSheetContent
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

    // MARK: - Sections

    private var editButtonSection: some View {
        HStack {
            Spacer()
            Button {
                isShowingEditOptions = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.caption)
                    Text("Änderungen vorschlagen")
                        .font(.subheadline)
                }
                .foregroundColor(.purple)
            }
            .accessibilityLabel(Text("Änderungen für diese Toilette vorschlagen"))
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(toilet.name)
                .font(.title.bold())
                .accessibilityLabel(Text("Name: \(toilet.name)"))

            if toilet.isQualified {
                QualifiedBadgeView(iconSize: 22)
            }
        }

        Label("Betreiber: \(toilet.owner)", systemImage: "building.2")
            .font(.body)
            .foregroundStyle(.primary)
            .accessibilityLabel(Text("Betreiber: \(toilet.owner)"))

        if toilet.isPublicAccessible {
            Label("Öffentlich zugänglich", systemImage: "figure.walk")
                .font(.body)
                .foregroundStyle(.primary)
                .accessibilityLabel(Text("Öffentlich zugängliche Toilette"))
        }

        Spacer(minLength: 4)
    }

    private var navigationButton: some View {
        Button(action: {
            isShowingNavigationOptions = true
        }) {
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
        .accessibilityLabel(Text("Navigieren zu \(toilet.name)"))
        .accessibilityHint(Text("Wähle zwischen Kompass- und Karten-Navigation."))
    }

    private var featuresSection: some View {
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
                    .accessibilityLabel(Text("Informationen zum Euroschlüssel"))
                }
            }

            HStack(alignment: .center, spacing: 8) {
                featureStatusIcon(isAvailable: toilet.hasChangingTable)
                Text("Wickelraum vorhanden")
                    .font(.body)
            }
        }
        .padding(.vertical, 2)
    }

    private var photosSection: some View {
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
                    .accessibilityLabel(Text("Foto hinzufügen"))
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var openingHoursSection: some View {
        if let periods = toilet.placeOpeningHours, !periods.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Öffnungszeiten")
                    .font(.subheadline.bold())

                OpeningTimeComponent(
                    hasOpeningHours: true,
                    isOpen: toilet.isOpen24HoursEveryDay ? true : toilet.isOpen,
                    openTimestamp: toilet.isOpen24HoursEveryDay ? nil : toilet.openTimestamp,
                    closeTimestamp: toilet.isOpen24HoursEveryDay ? nil : toilet.closeTimestamp,
                    accessibleOutsideOpeningTimes: toilet.accessibleOutsideOpeningTimes,
                    isOpen24Hours: toilet.isOpen24HoursEveryDay,
                    alignment: .leading
                )
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if toilet.isOpen24HoursEveryDay {
                    Text("Täglich 24 Stunden geöffnet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(periods.indices, id: \.self) { index in
                        Text(periods[index].formatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(toilet.isOpen24HoursEveryDay ? Text("Öffnungszeiten: Täglich 24 Stunden geöffnet") : Text("Öffnungszeiten: \(periods.map(\.formatted).joined(separator: ", "))"))

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
    }

    @ViewBuilder
    private var addressSection: some View {
        if let address = toilet.address, !address.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Adresse")
                    .font(.subheadline.bold())
                Text(address)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Adresse: \(address)"))

            Spacer(minLength: 4)
        }
    }

    @ViewBuilder
    private var storageSpaceSection: some View {
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
            .accessibilityLabel(Text("Ablagefläche: \(title)"))

            Spacer(minLength: 4)
        }
    }

    @ViewBuilder
    private var websiteSection: some View {
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
            .accessibilityLabel(Text("Webseite: \(trimmed)"))

            Spacer(minLength: 4)
        }
    }

    @ViewBuilder
    private var commentSection: some View {
        if let comment = toilet.comment, !comment.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bemerkung")
                    .font(.subheadline.bold())
                Text(comment)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Bemerkung: \(comment)"))
        }
    }

    private var photoUploadSheetContent: some View {
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
            return String(localized: "Keine")
        case "little":
            return String(localized: "Wenig")
        case "much":
            return String(localized: "Viel")
        default:
            return nil
        }
    }

    private func navigateToToilet() {
        Analytics.shared.trackEvent(category: "detail", action: "navigate_maps", name: toilet.name)
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
