import SwiftUI
import CoreLocation

struct ResultsView: View {
    let location: SearchedLocation

    @State private var toilets: [Toilet] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedToiletID: String?
    @State private var portraitRatio: CGFloat = 0.66
    @State private var landscapeRatio: CGFloat = 0.5
    @State private var isDraggingSplit = false

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            ResizableSplit(
                axis: isLandscape ? .horizontal : .vertical,
                ratio: isLandscape ? $landscapeRatio : $portraitRatio,
                isDragging: $isDraggingSplit
            ) {
                listContent
            } secondary: {
                mapContent
            }
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadToilets()
        }
        .alert("Fehler", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var listContent: some View {
        Group {
            if isLoading {
                ProgressView("Suche Toiletten...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if toilets.isEmpty {
                ContentUnavailableView("Keine Toiletten gefunden", systemImage: "toilet")
            } else {
                List(toilets) { toilet in
                    ToiletRowView(toilet: toilet, userLocation: location.coordinate)
                        .listRowBackground(toilet.id == selectedToiletID ? Color.purple.opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedToiletID = toilet.id
                        }
                }
                .listStyle(.plain)
            }
        }
    }

    private var mapContent: some View {
        MapView(center: location.coordinate, toilets: toilets, selectedToiletID: selectedToiletID)
            .opacity(isDraggingSplit ? 0 : 1)
            .ignoresSafeArea(edges: [.bottom, .leading, .trailing])
    }

    private func loadToilets() async {
        isLoading = true
        do {
            toilets = try await WCInfoAPIService.shared.fetchToiletsNearby(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                distance: 25
            )
        } catch {
            errorMessage = "Toiletten konnten nicht geladen werden."
        }
        isLoading = false
    }
}
