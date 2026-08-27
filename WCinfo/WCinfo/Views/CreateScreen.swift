import SwiftUI
import CoreLocation

enum QuestionStep: Int, CaseIterable, Identifiable {
    case place = 1
    case name = 2
    case gpsLocation = 3
    case mapPicker = 4
    case genderSeparated = 5
    case wheelchair = 6
    case euroKey = 7
    case publicAccess = 9
    case address = 10
    case website = 11
    case openingTimes = 12
    case outsideOpeningTimes = 13
    case storageSpace = 14
    case photos = 15
    case comment = 16

    var id: Int { rawValue }
}

struct CreateScreen: View {
    @Environment(\.dismiss) private var dismiss
    let location: SearchedLocation?
    var onToiletCreated: (() -> Void)? = nil

    @StateObject private var placesService = PlacesService()
    @StateObject private var locationManager = LocationManager()

    // MARK: - Navigation & Flow State
    @State private var currentStep: QuestionStep = .place
    @State private var stepHistory: [QuestionStep] = []
    @State private var createdToiletId: Int? = nil
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var showHeartAnimation = false

    // MARK: - Places Data
    @State private var nearbyPlaces: [NearbyPlaceOption] = []
    @State private var isLoadingPlaces = false
    @State private var selectedPlace: NearbyPlaceOption?
    @State private var selectedPlaceDetails: PlaceDetails?
    @State private var isNoneOfThesePlaces = false

    // MARK: - Answers State
    @State private var toiletName = ""
    @State private var usedGpsPosition = false
    @State private var gpsCoordinate: CLLocationCoordinate2D?
    @State private var mapSelectedCoordinate: CLLocationCoordinate2D?

    @State private var isGenderSeparated: Bool?
    @State private var isUnisex: Bool?
    @State private var hasWheelchairAccess: Bool?
    @State private var euroKey: String?
    @State private var showingEuroKeyInfo = false

    @State private var publicAccessible: Bool?
    @State private var addressInput = ""
    @State private var websiteInput = ""
    @State private var placeOpeningHours: [String]?
    @State private var accessibleOutsideOpeningTimes: Bool?
    @State private var storageSpace: String?
    @State private var commentInput = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    progressBar

                    ScrollView {
                        VStack(spacing: 24) {
                            questionContentView
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                                .id(currentStep)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }

                if showHeartAnimation {
                    celebrationHeartsView
                }
            }
            .navigationTitle("Toilette hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !stepHistory.isEmpty {
                        Button {
                            goBack()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Zurück")
                            }
                        }
                        .accessibilityLabel("Vorherige Frage")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(createdToiletId != nil ? "Fertig" : "Abbrechen") {
                        if createdToiletId != nil {
                            finishWithCelebration()
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(showHeartAnimation)
                    .accessibilityLabel(createdToiletId != nil ? "Fertigstellen" : "Abbrechen")
                }
            }
            .sheet(isPresented: $showingEuroKeyInfo) {
                EuroKeyInfoView()
            }
            .task {
                await loadPlaces()
            }
            .onAppear {
                Analytics.shared.trackScreen("CreateToiletWizard")
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        let activeSteps = determineActiveSteps()
        let currentIndex = activeSteps.firstIndex(of: currentStep) ?? 0
        let progress = Double(currentIndex + 1) / Double(max(activeSteps.count, 1))

        return VStack(spacing: 4) {
            ProgressView(value: progress, total: 1.0)
                .tint(.purple)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)

            HStack {
                Text("Frage \(currentIndex + 1) von \(activeSteps.count)")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Spacer()
                if createdToiletId != nil {
                    Text("✓ Toilette gespeichert")
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
    }

    // MARK: - Dynamic Step Content

    @ViewBuilder
    private var questionContentView: some View {
        switch currentStep {
        case .place:
            question1PlaceView
        case .name:
            question2NameView
        case .gpsLocation:
            question3GpsLocationView
        case .mapPicker:
            question4MapPickerView
        case .genderSeparated:
            question5GenderSeparatedView
        case .wheelchair:
            question6WheelchairView
        case .euroKey:
            question7EuroKeyView
        case .publicAccess:
            question9PublicAccessView
        case .address:
            question10AddressView
        case .website:
            question11WebsiteView
        case .openingTimes:
            question12OpeningTimesView
        case .outsideOpeningTimes:
            question13OutsideOpeningTimesView
        case .storageSpace:
            question14StorageSpaceView
        case .photos:
            question15PhotosView
        case .comment:
            question16CommentView
        }
    }

    // MARK: - Question 1: Place ("Gehört die Toilette zu einem dieser Orte?")

    private var question1PlaceView: some View {
        VStack(spacing: 20) {
            questionHeader(
                iconName: "building.2.crop.circle.fill",
                title: "Gehört die Toilette zu einem dieser Orte?",
                subtitle: "Wähle den Ort aus, zu dem die Toilette gehört:"
            )

            if isLoadingPlaces {
                ProgressView("Orte in der Nähe werden gesucht...")
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(nearbyPlaces.prefix(3)) { place in
                        primaryChoiceButton(title: place.name, subtitle: place.secondaryText) {
                            selectPlaceOption(place)
                        }
                    }

                    secondaryChoiceButton(title: "Keiner dieser Orte") {
                        selectPlaceOption(nil)
                    }
                }
            }
        }
    }

    private func selectPlaceOption(_ place: NearbyPlaceOption?) {
        selectedPlace = place
        isNoneOfThesePlaces = (place == nil)

        if let place {
            Task {
                do {
                    let details = try await placesService.fetchPlaceDetails(for: place.id)
                    selectedPlaceDetails = details
                    if addressInput.isEmpty, let addr = details.formattedAddress {
                        addressInput = addr
                    }
                    if websiteInput.isEmpty, let site = details.website {
                        websiteInput = site
                    }
                } catch {
                    print("[CreateScreen] Error loading place details: \(error)")
                }
            }
        } else {
            selectedPlaceDetails = nil
        }

        advanceToNextStep()
    }

    // MARK: - Question 2: Name ("Wo befindet sich die Toilette?")

    private var question2NameView: some View {
        VStack(spacing: 20) {
            questionHeader(
                iconName: "signpost.right.and.left.fill",
                title: "Wo befindet sich die Toilette?",
                subtitle: "Gib eine kurze Ortsangabe oder Bezeichnung an:"
            )

            TextField("z.B. 1. Stock bei den Umkleiden", text: $toiletName)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 1))

            primaryChoiceButton(title: "Weiter") {
                advanceToNextStep()
            }
        }
    }

    // MARK: - Question 3: GPS Position

    private var question3GpsLocationView: some View {
        VStack(spacing: 20) {
            questionHeader(
                iconName: "location.fill",
                title: "Befindest du dich gerade unter freiem Himmel und vor dem Eingang der Toilette?",
                subtitle: "Dann können wir deine aktuelle Position zur Toilette hinzufügen, um anderen die Navigation zu erleichtern."
            )

            VStack(spacing: 12) {
                primaryChoiceButton(title: "Ja, benutzt meine Position") {
                    locationManager.requestLocation()
                    if let userCoord = locationManager.location?.coordinate {
                        gpsCoordinate = userCoord
                        usedGpsPosition = true
                    } else if let locCoord = location?.coordinate {
                        gpsCoordinate = locCoord
                        usedGpsPosition = true
                    }
                    advanceToNextStep()
                }

                secondaryChoiceButton(title: "Nein") {
                    usedGpsPosition = false
                    gpsCoordinate = nil
                    advanceToNextStep()
                }
            }
        }
    }

    // MARK: - Question 4: Map Point Picker

    private var question4MapPickerView: some View {
        VStack(spacing: 16) {
            questionHeader(
                iconName: "map.fill",
                title: "Bitte wähle den Punkt auf der Karte, an dem sich die Toilette befindet",
                subtitle: "Tippe auf die Karte oder verschiebe die Markierung:"
            )

            let centerCoord = location?.coordinate ?? CLLocationCoordinate2D(latitude: 50.8957, longitude: 7.3556)

            LocationPickerMapView(
                initialCoordinate: mapSelectedCoordinate ?? centerCoord,
                selectedCoordinate: $mapSelectedCoordinate
            ) { confirmedCoord in
                mapSelectedCoordinate = confirmedCoord
                advanceToNextStep()
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Question 5: Gender Separated

    private var question5GenderSeparatedView: some View {
        VStack(spacing: 20) {
            questionHeader(
                iconAsset: "restroom-solid-full",
                title: "Ist die Toilette nach Geschlecht getrennt?"
            )

            VStack(spacing: 12) {
                primaryChoiceButton(title: "Ja") {
                    isGenderSeparated = true
                    isUnisex = false
                    advanceToNextStep()
                }

                secondaryChoiceButton(title: "Nein, Unisex") {
                    isGenderSeparated = false
                    isUnisex = true
                    advanceToNextStep()
                }
            }
        }
    }

    // MARK: - Question 6: Wheelchair Access

    private var question6WheelchairView: some View {
        VStack(spacing: 20) {
            questionHeader(
                iconAsset: "wheelchair-solid-full",
                title: "Ist eine barrierefreie Toilette vorhanden?"
            )

            VStack(spacing: 12) {
                primaryChoiceButton(title: "Ja") {
                    hasWheelchairAccess = true
                    advanceToNextStep()
                }

                secondaryChoiceButton(title: "Nein") {
                    hasWheelchairAccess = false
                    euroKey = nil
                    advanceToNextStep()
                }
            }
        }
    }

    // MARK: - Question 7: Euro Key

    private var question7EuroKeyView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.purple)

                HStack(spacing: 6) {
                    Text("Kann die Türe mit Euro-Schlüssel geöffnet werden?")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)

                    Button {
                        showingEuroKeyInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Informationen zum Euroschlüssel")
                }

                Text("Diese Information ist oft in der Nähe des Schlosses zu lesen.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if isSubmitting {
                ProgressView("Toilette wird gespeichert...")
                    .padding()
            } else {
                VStack(spacing: 12) {
                    primaryChoiceButton(title: "Ja") {
                        euroKey = "yes"
                        advanceToNextStep()
                    }

                    secondaryChoiceButton(title: "Nicht sicher") {
                        euroKey = "unknown"
                        advanceToNextStep()
                    }

                    secondaryChoiceButton(title: "Nein") {
                        euroKey = "no"
                        advanceToNextStep()
                    }
                }
            }
        }
    }

    // MARK: - Question 9: Public Access

    private var question9PublicAccessView: some View {
        VStack(spacing: 20) {
            questionHeader(
                iconName: "person.2.fill",
                title: "Ist der Zugang öffentlich möglich?",
                subtitle: "Gib an, ob man diese Toilette auch nutzen kann, ohne eine Eintrittskarte zu haben, Mitglied zu sein oder etwas zu kaufen etc."
            )

            VStack(spacing: 12) {
                primaryChoiceButton(title: "Ja, öffentlicher Zugang möglich") {
                    publicAccessible = true
                    patchCurrentState()
                    advanceToNextStep()
                }

                secondaryChoiceButton(title: "Nein, nicht ohne weiteres möglich") {
                    publicAccessible = false
                    patchCurrentState()
                    advanceToNextStep()
                }
            }
        }
    }

    // MARK: - Question 10: Address

    private var question10AddressView: some View {
        VStack(spacing: 20) {
            questionHeader(
                iconName: "envelope.fill",
                title: "Möchtest du eine Adresse angeben?"
            )

            TextField("Adresse eingeben", text: $addressInput, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 1))

            VStack(spacing: 12) {
                primaryChoiceButton(title: "Adresse speichern") {
                    let trimmed = addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        patchCurrentState()
                        advanceToNextStep()
                    }
                }

                secondaryChoiceButton(title: "Nein, weiter") {
                    advanceToNextStep()
                }
            }
        }
    }

    // MARK: - Question 11: Website

    private var question11WebsiteView: some View {
        VStack(spacing: 20) {
            questionHeader(
                iconName: "globe",
                title: "Möchtest du eine Webseite angeben?"
            )

            TextField("http://www.beispiel.de", text: $websiteInput)
                .textFieldStyle(.plain)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 1))

            VStack(spacing: 12) {
                primaryChoiceButton(title: "Website speichern") {
                    let trimmed = websiteInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        patchCurrentState()
                        advanceToNextStep()
                    }
                }

                secondaryChoiceButton(title: "Nein, weiter") {
                    advanceToNextStep()
                }
            }
        }
    }

    // MARK: - Question 12: Opening Times

    private var question12OpeningTimesView: some View {
        VStack(spacing: 20) {
            questionHeader(
                iconName: "clock.fill",
                title: "Möchtest du Öffnungszeiten angeben?",
                subtitle: "Du kannst auch im nächsten Schritt ein Foto der Öffnungszeiten hochladen, dann machen wir das für dich."
            )

            OpeningTimesInput(openingHours: $placeOpeningHours)

            VStack(spacing: 12) {
                primaryChoiceButton(title: "Öffnungszeiten speichern") {
                    patchCurrentState()
                    advanceToNextStep()
                }

                secondaryChoiceButton(title: "Nein, weiter") {
                    advanceToNextStep()
                }
            }
        }
    }

    // MARK: - Question 13: Outside Opening Times

    private var question13OutsideOpeningTimesView: some View {
        VStack(spacing: 20) {
            questionHeader(
                iconName: "moon.stars.fill",
                title: "Ist der Zugang auch ausserhalb der Öffnungszeiten möglich?",
                subtitle: "z.B. wenn die Toilette von aussen oder per Euro-Schlüssel zugänglich ist"
            )

            VStack(spacing: 12) {
                primaryChoiceButton(title: "Ja, auf jeden Fall möglich") {
                    accessibleOutsideOpeningTimes = true
                    patchCurrentState()
                    advanceToNextStep()
                }

                secondaryChoiceButton(title: "Nein oder nicht sicher") {
                    accessibleOutsideOpeningTimes = false
                    patchCurrentState()
                    advanceToNextStep()
                }
            }
        }
    }

    // MARK: - Question 14: Storage Space

    private var question14StorageSpaceView: some View {
        VStack(spacing: 20) {
            questionHeader(
                iconName: "square.grid.2x2.fill",
                title: "Gibt es Ablageflächen, Kleiderhaken usw.?"
            )

            VStack(spacing: 10) {
                secondaryChoiceButton(title: "Keine") {
                    storageSpace = "none"
                    patchCurrentState()
                    advanceToNextStep()
                }

                secondaryChoiceButton(title: "Wenig") {
                    storageSpace = "little"
                    patchCurrentState()
                    advanceToNextStep()
                }

                secondaryChoiceButton(title: "Viel") {
                    storageSpace = "much"
                    patchCurrentState()
                    advanceToNextStep()
                }

                secondaryChoiceButton(title: "Keine Angabe") {
                    advanceToNextStep()
                }
            }
        }
    }

    // MARK: - Question 15: Photos

    private var question15PhotosView: some View {
        VStack(spacing: 20) {
            questionHeader(
                iconName: "camera.fill",
                title: "Möchtest du Fotos hinzufügen?"
            )

            PhotoUpload()

            secondaryChoiceButton(title: "Weiter") {
                advanceToNextStep()
            }
        }
    }

    // MARK: - Question 16: Comment & Celebration

    private var question16CommentView: some View {
        VStack(spacing: 20) {
            questionHeader(
                iconName: "bubble.left.and.bubble.right.fill",
                title: "Möchtest du sonst noch etwas zu dieser Toilette schreiben?"
            )

            TextField("Kommentar oder Hinweise eingeben...", text: $commentInput, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 1))

            primaryChoiceButton(title: "Toilette speichern") {
                let trimmed = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    patchCurrentState()
                }
                finishWithCelebration()
            }
        }
    }

    // MARK: - Celebration Animation View

    private var celebrationHeartsView: some View {
        FloatingHeartsOverlay()
    }

    private func finishWithCelebration() {
        showHeartAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            onToiletCreated?()
            dismiss()
        }
    }

    // MARK: - Reusable UI Elements

    private func questionHeader(iconName: String? = nil, iconAsset: String? = nil, title: String, subtitle: String? = nil) -> some View {
        VStack(spacing: 10) {
            if let iconAsset {
                Image(iconAsset)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .foregroundColor(.purple)
            } else if let iconName {
                Image(systemName: iconName)
                    .font(.system(size: 40))
                    .foregroundColor(.purple)
            }

            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 8)
    }

    private func primaryChoiceButton(title: String, subtitle: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.purple)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .purple.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .accessibilityLabel(title)
    }

    private func secondaryChoiceButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.5), lineWidth: 1.5))
        }
        .accessibilityLabel(title)
    }

    // MARK: - Flow & Step Transitions

    private func determineActiveSteps() -> [QuestionStep] {
        var steps: [QuestionStep] = []

        // Q1
        steps.append(.place)
        // Q2
        steps.append(.name)

        // Q3 (Skipped if no location authorization)
        if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            steps.append(.gpsLocation)
        }

        // Q4 (Appears only if no place_id and no lat/lon from Q3)
        if selectedPlace == nil && gpsCoordinate == nil {
            steps.append(.mapPicker)
        }

        // Q5
        steps.append(.genderSeparated)
        // Q6
        steps.append(.wheelchair)

        // Q7 (Skipped if wheelchair == false)
        if hasWheelchairAccess != false {
            steps.append(.euroKey)
        }

        // Optional Steps (9-16)
        steps.append(.publicAccess)

        // Q10 (Skipped if place has formatted_address)
        if selectedPlace == nil || selectedPlaceDetails?.formattedAddress == nil {
            steps.append(.address)
        }

        // Q11 (Skipped if place has website)
        if selectedPlace == nil || selectedPlaceDetails?.website == nil {
            steps.append(.website)
        }

        // Q12
        steps.append(.openingTimes)
        // Q13
        steps.append(.outsideOpeningTimes)
        // Q14
        steps.append(.storageSpace)
        // Q15
        steps.append(.photos)
        // Q16
        steps.append(.comment)

        return steps
    }

    private func advanceToNextStep() {
        let activeSteps = determineActiveSteps()

        guard let currentIndex = activeSteps.firstIndex(of: currentStep) else { return }

        // Check if we just completed mandatory questions (Q7 or Q6 if Q7 skipped)
        let isCompletingMandatory = (currentStep == .euroKey) ||
            (currentStep == .wheelchair && hasWheelchairAccess == false)

        if isCompletingMandatory && createdToiletId == nil {
            submitMandatoryToilet()
            return
        }

        // If toilet already created and user changed a previous answer, patch it
        if createdToiletId != nil {
            patchCurrentState()
        }

        if currentIndex + 1 < activeSteps.count {
            stepHistory.append(currentStep)
            withAnimation(.easeInOut(duration: 0.25)) {
                currentStep = activeSteps[currentIndex + 1]
            }
        } else {
            finishWithCelebration()
        }
    }

    private func goBack() {
        guard let previous = stepHistory.popLast() else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStep = previous
        }
    }

    // MARK: - API Calls

    private func resolveCoordinates() -> (lat: Double?, lon: Double?) {
        if let gps = gpsCoordinate {
            return (gps.latitude, gps.longitude)
        }
        if let map = mapSelectedCoordinate {
            return (map.latitude, map.longitude)
        }
        if let placeCoord = selectedPlaceDetails?.coordinate {
            return (placeCoord.latitude, placeCoord.longitude)
        }
        if let loc = location?.coordinate {
            return (loc.latitude, loc.longitude)
        }
        return (nil, nil)
    }

    private func submitMandatoryToilet() {
        let coords = resolveCoordinates()
        let trimmedName = toiletName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWebsite = websiteInput.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = AddToiletPayload(
            name: trimmedName.isEmpty ? nil : trimmedName,
            owner: selectedPlace?.name,
            lat: coords.lat,
            lon: coords.lon,
            placeId: selectedPlace?.id,
            isUnisex: isUnisex,
            isGenderSeparated: isGenderSeparated,
            hasWheelchairAccess: hasWheelchairAccess,
            hasChangingTable: nil,
            accessibleOutsideOpeningTimes: nil,
            publicAccessible: nil,
            placeOpeningHours: nil,
            address: trimmedAddress.isEmpty ? selectedPlaceDetails?.formattedAddress : trimmedAddress,
            website: trimmedWebsite.isEmpty ? selectedPlaceDetails?.website : trimmedWebsite,
            comment: nil,
            euroKey: euroKey,
            storageSpace: nil,
            status: "active"
        )

        isSubmitting = true
        Task {
            do {
                let response = try await WCInfoAPIService.shared.addToilet(payload)
                isSubmitting = false
                if response.success {
                    createdToiletId = response.id
                    Analytics.shared.trackEvent(category: "toilet", action: "create_success", name: String(response.id))

                    let activeSteps = determineActiveSteps()
                    if let currentIndex = activeSteps.firstIndex(of: currentStep), currentIndex + 1 < activeSteps.count {
                        stepHistory.append(currentStep)
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentStep = activeSteps[currentIndex + 1]
                        }
                    }
                }
            } catch {
                isSubmitting = false
                ErrorManager.shared.report(error, context: ["action": "addToiletMandatory"])
            }
        }
    }

    private func patchCurrentState() {
        guard let toiletId = createdToiletId else { return }

        let coords = resolveCoordinates()
        let trimmedName = toiletName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWebsite = websiteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedComment = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = UpdateToiletPayload(
            name: trimmedName.isEmpty ? nil : trimmedName,
            owner: selectedPlace?.name,
            lat: coords.lat,
            lon: coords.lon,
            placeId: selectedPlace?.id,
            isQualified: nil,
            isUnisex: isUnisex,
            isGenderSeparated: isGenderSeparated,
            hasWheelchairAccess: hasWheelchairAccess,
            hasChangingTable: nil,
            accessibleOutsideOpeningTimes: accessibleOutsideOpeningTimes,
            publicAccessible: publicAccessible,
            placeOpeningHours: placeOpeningHours,
            address: trimmedAddress.isEmpty ? nil : trimmedAddress,
            website: trimmedWebsite.isEmpty ? nil : trimmedWebsite,
            comment: trimmedComment.isEmpty ? nil : trimmedComment,
            euroKey: euroKey,
            storageSpace: storageSpace,
            status: "active"
        )

        Task {
            do {
                _ = try await WCInfoAPIService.shared.updateToilet(id: toiletId, payload: payload)
            } catch {
                ErrorManager.shared.report(error, context: ["action": "updateToiletPatch", "toiletId": toiletId])
            }
        }
    }

    private func loadPlaces() async {
        guard let location else { return }
        isLoadingPlaces = true
        defer { isLoadingPlaces = false }

        do {
            let places = try await placesService.fetchNearbyPlaces(coordinate: location.coordinate, radius: 200.0)
            nearbyPlaces = places
        } catch {
            print("[CreateScreen] fetchNearbyPlaces error: \(error)")
        }
    }
}

struct FloatingHeartsOverlay: View {
    @State private var isAnimating = false

    fileprivate struct HeartParticle: Identifiable {
        let id: Int
        let xOffset: CGFloat
        let size: CGFloat
        let delay: Double
        let duration: Double
    }

    private let particles: [HeartParticle] = [
        .init(id: 0, xOffset: -110, size: 52, delay: 0.0, duration: 1.8),
        .init(id: 1, xOffset: -40, size: 70, delay: 0.12, duration: 2.0),
        .init(id: 2, xOffset: 25, size: 58, delay: 0.05, duration: 1.9),
        .init(id: 3, xOffset: 100, size: 54, delay: 0.22, duration: 2.1),
        .init(id: 4, xOffset: -70, size: 44, delay: 0.28, duration: 1.7),
        .init(id: 5, xOffset: 65, size: 78, delay: 0.16, duration: 2.0),
        .init(id: 6, xOffset: 0, size: 88, delay: 0.08, duration: 1.9),
        .init(id: 7, xOffset: -130, size: 48, delay: 0.32, duration: 2.1),
        .init(id: 8, xOffset: 130, size: 50, delay: 0.26, duration: 1.8)
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(isAnimating ? 0.35 : 0.0)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                Text("❤️")
                    .font(.system(size: 64))
                    .scaleEffect(isAnimating ? 1.15 : 0.8)

                Text("Vielen Dank!")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text("Deine Angaben wurden gespeichert.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)
            .scaleEffect(isAnimating ? 1.0 : 0.75)
            .opacity(isAnimating ? 1.0 : 0.0)

            ForEach(particles) { particle in
                SingleFloatingHeart(particle: particle, isAnimating: isAnimating)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                isAnimating = true
            }
        }
    }
}

private struct SingleFloatingHeart: View {
    let particle: FloatingHeartsOverlay.HeartParticle
    let isAnimating: Bool

    @State private var startRise = false

    var body: some View {
        Text("❤️")
            .font(.system(size: particle.size))
            .offset(x: particle.xOffset, y: startRise ? -550 : 420)
            .opacity(startRise ? 0.0 : 1.0)
            .scaleEffect(startRise ? 1.25 : 0.5)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: particle.duration)
                    .delay(particle.delay)
                ) {
                    startRise = true
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
