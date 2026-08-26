import SwiftUI
import GooglePlaces
import CoreLocation

struct HomeView: View {
    @StateObject private var placesService = PlacesService()
    @StateObject private var locationManager = LocationManager()

    @State private var searchText = ""
    @State private var predictions: [GMSAutocompletePlaceSuggestion] = []
    @State private var selectedLocation: SearchedLocation?
    @State private var keyboardHeight: CGFloat = 0
    @State private var showSearchValidation = false
    @FocusState private var searchFieldFocused: Bool

    private var isSearchInvalid: Bool {
        showSearchValidation && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundImage

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 80)

                        logo
                            .padding(.bottom, 36)

                        searchCard
                            .padding(.bottom, 20)

                        actionButtons
                            .frame(height: 52)

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, keyboardHeight)
                    .frame(maxWidth: min(UIScreen.main.bounds.width - 48, 420))
                    .frame(minHeight: UIScreen.main.bounds.height)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .defaultScrollAnchor(.top)
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("")
            .navigationDestination(item: $selectedLocation) { location in
                ResultsView(location: location)
            }
            .onAppear {
                observeKeyboard()
                Analytics.shared.trackScreen("Home")
            }
        }
    }

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            keyboardHeight = frame.height
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }

    private var backgroundImage: some View {
        Image("lavendel")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private var logo: some View {
        Image("logo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 160, height: 220)
            .foregroundStyle(.white)
            .shadow(radius: 4)
            .accessibilityLabel("WCinfo Logo")
            .accessibilityHidden(true)
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                TextField("Wo möchtest du nach Toiletten suchen?", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.primary)
                    .tint(.purple)
                    .submitLabel(.search)
                    .focused($searchFieldFocused)
                    .accessibilityLabel("Ort eingeben")
                    .accessibilityHint("Gib eine Adresse, einen Ort oder eine Sehenswürdigkeit ein.")
                    .onSubmit { performSearch() }
                    .onChange(of: searchText) { _, newValue in
                        if showSearchValidation {
                            showSearchValidation = false
                        }
                        Task { await updatePredictions(for: newValue) }
                    }

                Button(action: requestCurrentLocation) {
                    Image(systemName: "location.circle.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Aktuellen Standort verwenden")
                .accessibilityHint("Sucht Toiletten in der Nähe deines aktuellen Standorts.")
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(isSearchInvalid ? Color.red.opacity(0.08) : Color(uiColor: .systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSearchInvalid ? Color.red : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)

            if isSearchInvalid {
                Text("Bitte gib einen Ort ein, um danach zu suchen.")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
                    .accessibilityLabel("Eingabefehler: Bitte gib einen Ort ein.")
            }

            if !predictions.isEmpty {
                predictionsList
                    .padding(.top, 8)
            }
        }
    }

    private var predictionsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(predictions, id: \.placeID) { prediction in
                    Button {
                        selectPrediction(prediction)
                    } label: {
                        Text(prediction.attributedFullText.string)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Tippe doppelt, um diesen Ort auszuwählen.")

                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .frame(maxHeight: 220)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Vorschläge")
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: performSearch) {
                Text("Suchen")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(searchText.isEmpty ? Color.gray : Color(red: 0.4, green: 0.4, blue: 0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Suchen")
            .accessibilityHint("Sucht Toiletten am eingegebenen Ort.")

            Button(action: requestCurrentLocation) {
                Text("In der Nähe")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.purple)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("In der Nähe suchen")
            .accessibilityHint("Sucht Toiletten in der Nähe deines aktuellen Standorts.")
        }
    }

    private func updatePredictions(for query: String) async {
        guard query.count > 2 else {
            predictions = []
            return
        }
        do {
            predictions = try await placesService.autocomplete(query: query)
        } catch {
            predictions = []
            ErrorManager.shared.report(error, context: ["action": "autocomplete", "query": query])
        }
    }

    private func selectPrediction(_ prediction: GMSAutocompletePlaceSuggestion) {
        searchText = prediction.attributedFullText.string
        predictions = []
        showSearchValidation = false
        searchFieldFocused = false
        Analytics.shared.trackEvent(category: "search", action: "select_prediction", name: prediction.attributedPrimaryText.string)
        Task {
            do {
                let coordinate = try await placesService.fetchCoordinates(for: prediction.placeID)
                selectedLocation = SearchedLocation(name: searchText, coordinate: coordinate)
            } catch {
                ErrorManager.shared.report(error, context: ["action": "select_prediction", "placeID": prediction.placeID])
            }
        }
    }

    private func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showSearchValidation = true
            UIAccessibility.post(notification: .announcement, argument: "Bitte gib einen Ort ein.")
            return
        }
        predictions = []
        showSearchValidation = false
        searchFieldFocused = false
        Analytics.shared.trackEvent(category: "search", action: "submit", name: trimmed)
        Task {
            do {
                let coordinate = try await placesService.fetchCoordinates(for: trimmed)
                selectedLocation = SearchedLocation(name: trimmed, coordinate: coordinate)
            } catch {
                ErrorManager.shared.report(error, context: ["action": "perform_search", "query": trimmed])
            }
        }
    }

    private func requestCurrentLocation() {
        Analytics.shared.trackEvent(category: "search", action: "nearby_current_location")
        locationManager.requestLocation()
        Task {
            for await _ in locationManager.$location.values {
                guard let location = locationManager.location else { continue }
                selectedLocation = SearchedLocation(
                    name: "Aktueller Standort",
                    coordinate: location.coordinate
                )
                break
            }
        }
    }
}
