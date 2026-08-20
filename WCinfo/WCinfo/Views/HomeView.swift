import SwiftUI
import GooglePlaces
import CoreLocation

struct HomeView: View {
    @StateObject private var placesService = PlacesService()
    @StateObject private var locationManager = LocationManager()

    @State private var searchText = ""
    @State private var predictions: [GMSAutocompletePrediction] = []
    @State private var errorMessage: String?
    @State private var selectedLocation: SearchedLocation?

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundImage

                VStack(spacing: 0) {
                    Spacer(minLength: 80)

                    logo
                        .padding(.bottom, 36)

                    searchCard
                        .padding(.bottom, 20)

                    actionButtons
                        .frame(height: 52)

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: min(UIScreen.main.bounds.width - 48, 420))
            }
            .navigationTitle("")
            .preferredColorScheme(.light)
            .navigationDestination(item: $selectedLocation) { location in
                ResultsView(location: location)
            }
            .alert("Fehler", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var backgroundImage: some View {
        Image("lavendel")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }

    private var logo: some View {
        Image("logo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 160, height: 220)
            .foregroundStyle(.white)
            .shadow(radius: 4)
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                TextField("Wo möchtest du nach Toiletten suchen?", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.primary)
                    .tint(.purple)
                    .submitLabel(.search)
                    .onSubmit { performSearch() }
                    .onChange(of: searchText) { _, newValue in
                        Task { await updatePredictions(for: newValue) }
                    }

                Button(action: requestCurrentLocation) {
                    Image(systemName: "location.circle.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)

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

                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .frame(maxHeight: 220)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: performSearch) {
                Text("Suchen")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .disabled(searchText.isEmpty)
            .background(searchText.isEmpty ? Color.gray : Color(red: 0.4, green: 0.4, blue: 0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: requestCurrentLocation) {
                Text("In der Nähe")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.purple)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
        }
    }

    private func selectPrediction(_ prediction: GMSAutocompletePrediction) {
        searchText = prediction.attributedFullText.string
        predictions = []
        Task {
            do {
                let coordinate = try await placesService.fetchCoordinates(for: prediction.placeID)
                selectedLocation = SearchedLocation(name: searchText, coordinate: coordinate)
            } catch {
                errorMessage = "Ort konnte nicht geladen werden."
            }
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        predictions = []
        Task {
            do {
                let coordinate = try await placesService.fetchCoordinates(for: searchText)
                selectedLocation = SearchedLocation(name: searchText, coordinate: coordinate)
            } catch {
                errorMessage = "Ort konnte nicht gefunden werden."
            }
        }
    }

    private func requestCurrentLocation() {
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
