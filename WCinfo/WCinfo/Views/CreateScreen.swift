import SwiftUI
import CoreLocation

struct CreateScreen: View {
    @Environment(\.dismiss) private var dismiss
    let location: SearchedLocation?
    var onToiletCreated: (() -> Void)? = nil

    @StateObject private var placesService = PlacesService()

    @State private var belongsToPlace = true
    @State private var nearbyPlaces: [NearbyPlaceOption] = []
    @State private var selectedPlace: NearbyPlaceOption?
    @State private var isLoadingPlaces = false
    @State private var placesError: String?

    @State private var toiletName = ""
    @State private var isGenderSeparated = false
    @State private var hasChangingTable = false
    @State private var hasWheelchairAccess = false

    @State private var website = ""
    @State private var address = ""
    @State private var placeCoordinates: CLLocationCoordinate2D?

    @State private var isSubmitting = false
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    placeAssociationSection

                    if let placesError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(placesError)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                Task { await loadInitialData() }
                            } label: {
                                Text("Erneut versuchen")
                                    .font(.caption.bold())
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    toiletNameSection

                    propertiesSection

                    websiteSection

                    addressSection

                    if let validationError {
                        Text(validationError)
                            .font(.caption)
                            .foregroundColor(.red)
                            .accessibilityLabel("Fehler: \(validationError)")
                    }

                    submitButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle("Toilette hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .accessibilityLabel("Abbrechen")
                }
            }
            .task {
                await loadInitialData()
            }
            .onAppear {
                Analytics.shared.trackScreen("CreateToilet")
            }
        }
    }

    // MARK: - Section 1: Place Association ("Toilette gehört zum Ort")

    private var placeAssociationSection: some View {
        HStack(spacing: 12) {
            Button {
                belongsToPlace.toggle()
                if !belongsToPlace {
                    selectedPlace = nil
                } else if selectedPlace == nil, let first = nearbyPlaces.first {
                    selectPlace(first)
                }
            } label: {
                HStack(spacing: 8) {
                    checkboxView(isChecked: belongsToPlace)
                    Text("Toilette gehört zum Ort")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toilette gehört zum Ort: \(belongsToPlace ? "Ausgewählt" : "Nicht ausgewählt")")
            .accessibilityHint("Umschalten, ob die Toilette zu einer bestimmten Einrichtung gehört.")

            Spacer()

            if belongsToPlace {
                placeDropdownMenu
            }
        }
    }

    private var placeDropdownMenu: some View {
        Menu {
            if isLoadingPlaces {
                Text("Orte werden geladen...")
            } else if nearbyPlaces.isEmpty {
                Text("Keine Orte in der Nähe gefunden")
            } else {
                ForEach(nearbyPlaces) { place in
                    Button {
                        selectPlace(place)
                    } label: {
                        if place.id == selectedPlace?.id {
                            Label(place.name, systemImage: "checkmark")
                        } else {
                            Text(place.name)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedPlace?.name ?? (isLoadingPlaces ? "Laden..." : "Ort wählen"))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 160, alignment: .leading)

                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(uiColor: .systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.purple, lineWidth: 1.5)
            )
        }
        .accessibilityLabel("Ort auswählen. Aktuell ausgewählt: \(selectedPlace?.name ?? "Keiner")")
    }

    // MARK: - Section 2: Name der Toilette (optional)

    private var toiletNameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name der Toilette (optional)")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            TextField("z.B. \"Hauptgebäude\" falls es mehrere Toiletten gibt", text: $toiletName)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(uiColor: .systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .accessibilityLabel("Name der Toilette")
        }
    }

    // MARK: - Section 3: Eigenschaften

    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Eigenschaften:")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                propertyCard(
                    iconName: "toiletIconGenderSeparated",
                    title: "Nach Geschlecht getrennte Toiletten vorhanden",
                    isChecked: $isGenderSeparated
                )

                propertyCard(
                    iconName: "toiletIconChangingTable",
                    title: "Wickelraum vorhanden",
                    isChecked: $hasChangingTable
                )

                propertyCard(
                    iconName: "toiletIconWheelchair",
                    title: "Barrierefreie Toilette vorhanden",
                    isChecked: $hasWheelchairAccess
                )
            }

            euroKeyDisabledCard
        }
    }

    private func propertyCard(iconName: String, title: String, isChecked: Binding<Bool>) -> some View {
        Button {
            isChecked.wrappedValue.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(iconName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.45))

                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                HStack {
                    Spacer()
                    checkboxView(isChecked: isChecked.wrappedValue, size: 18)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background(Color(uiColor: .systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isChecked.wrappedValue ? Color.purple : Color(.systemGray4), lineWidth: isChecked.wrappedValue ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(isChecked.wrappedValue ? "Ausgewählt" : "Nicht ausgewählt")")
        .accessibilityHint("Doppeltippen, um diese Eigenschaft umzuschalten.")
        .accessibilityAddTraits(.isButton)
    }

    private var euroKeyDisabledCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.body)
                .foregroundColor(Color(.systemGray3))

            HStack(spacing: 4) {
                Text("Kann mit Euroschlüssel geöffnet werden")
                    .font(.system(size: 13))
                    .foregroundColor(Color(.systemGray2))
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(Color(.systemGray3))
            }

            Spacer()

            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(.systemGray4), lineWidth: 1)
                .frame(width: 18, height: 18)
                .foregroundColor(Color(.systemGray5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    // MARK: - Section 4: Webseite

    private var websiteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Webseite")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            TextField("http://www.beispiel.de", text: $website)
                .textFieldStyle(.plain)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(uiColor: .systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .accessibilityLabel("Webseite der Toilette oder Einrichtung")
        }
    }

    // MARK: - Section 5: Adresse

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Adresse")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            TextField("Adresse eingeben", text: $address, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(uiColor: .systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .accessibilityLabel("Adresse der Toilette")
        }
    }

    // MARK: - Section 6: Submit Button

    private var submitButton: some View {
        Button(action: submitToilet) {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                }
                Text(isSubmitting ? "Wird gespeichert..." : "Toilette hinzufügen")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isSubmitting ? Color.purple.opacity(0.6) : Color.purple)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isSubmitting)
        .padding(.top, 8)
        .accessibilityLabel("Toilette hinzufügen")
        .accessibilityHint("Speichert die neue Toilette im System.")
    }

    // MARK: - Checkbox Helper View

    private func checkboxView(isChecked: Bool, size: CGFloat = 20) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(isChecked ? Color.purple : Color.clear)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isChecked ? Color.purple : Color(.systemGray3), lineWidth: 1.5)
                )

            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Logic & Actions

    private func loadInitialData() async {
        guard let location else { return }
        isLoadingPlaces = true
        placesError = nil
        defer { isLoadingPlaces = false }

        if address.isEmpty {
            address = location.name
        }
        placeCoordinates = location.coordinate

        do {
            let places = try await placesService.fetchNearbyPlaces(
                coordinate: location.coordinate,
                radius: 200.0
            )
            nearbyPlaces = places
            if let first = places.first {
                selectPlace(first)
            }
        } catch {
            let message = "Orte in der Nähe konnten nicht geladen werden: \(error.localizedDescription)"
            placesError = message
            ErrorManager.shared.report(
                error,
                context: [
                    "action": "fetchNearbyPlaces",
                    "lat": location.coordinate.latitude,
                    "lon": location.coordinate.longitude
                ],
                showToUser: false // shown inline in the sheet instead
            )
        }
    }

    private func selectPlace(_ place: NearbyPlaceOption) {
        selectedPlace = place
        Task {
            do {
                let details = try await placesService.fetchPlaceDetails(for: place.id)
                if let formatted = details.formattedAddress, !formatted.isEmpty {
                    address = formatted
                }
                if let site = details.website, !site.isEmpty {
                    website = site
                }
                if let coord = details.coordinate {
                    placeCoordinates = coord
                }
            } catch {
                print("[CreateScreen] fetchPlaceDetails error: \(error)")
            }
        }
    }

    private func submitToilet() {
        validationError = nil

        let finalLat = placeCoordinates?.latitude ?? location?.coordinate.latitude
        let finalLon = placeCoordinates?.longitude ?? location?.coordinate.longitude

        guard let lat = finalLat, let lon = finalLon else {
            validationError = "Keine Standortkoordinaten gefunden. Bitte wähle einen Ort aus."
            return
        }

        let trimmedName = toiletName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWebsite = website.trimmingCharacters(in: .whitespacesAndNewlines)

        let ownerName = belongsToPlace ? (selectedPlace?.name) : nil
        let placeID = belongsToPlace ? (selectedPlace?.id) : nil

        let payload = AddToiletPayload(
            name: trimmedName.isEmpty ? nil : trimmedName,
            owner: ownerName,
            lat: lat,
            lon: lon,
            placeId: placeID,
            isUnisex: !isGenderSeparated,
            isGenderSeparated: isGenderSeparated,
            hasWheelchairAccess: hasWheelchairAccess,
            hasChangingTable: hasChangingTable,
            address: trimmedAddress.isEmpty ? nil : trimmedAddress,
            website: trimmedWebsite.isEmpty ? nil : trimmedWebsite,
            comment: nil,
            euroKey: nil,
            status: "active"
        )

        isSubmitting = true
        Analytics.shared.trackEvent(category: "toilet", action: "create_submit", name: ownerName ?? trimmedName)

        Task {
            do {
                let response = try await WCInfoAPIService.shared.addToilet(payload)
                isSubmitting = false
                if response.success {
                    Analytics.shared.trackEvent(category: "toilet", action: "create_success", name: String(response.id))
                    onToiletCreated?()
                    dismiss()
                }
            } catch {
                isSubmitting = false
                var context: [String: Any] = [
                    "action": "addToilet",
                    "lat": lat,
                    "lon": lon
                ]
                if let apiError = error as? WCInfoAPIError {
                    context.merge(apiError.diagnosticContext) { _, new in new }
                    validationError = apiError.message
                } else {
                    validationError = error.localizedDescription
                }
                ErrorManager.shared.report(error, context: context)
                Analytics.shared.trackEvent(category: "toilet", action: "create_error")
            }
        }
    }
}

#Preview {
    CreateScreen(
        location: .init(
            name: "Much-Niederheimbach",
            coordinate: .init(latitude: 50.895725646813936, longitude: 7.355648585165031)
        )
    )
}
