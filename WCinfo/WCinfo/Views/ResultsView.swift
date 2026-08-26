import SwiftUI
import CoreLocation

struct ResultsView: View {
    let location: SearchedLocation

    @State private var toilets: [Toilet] = []
    @State private var isLoading = true
    @State private var portraitRatio: CGFloat = 0.66
    @State private var landscapeRatio: CGFloat = 0.5
    @State private var isDraggingSplit = false
    @State private var selectedToilet: Toilet?
    @State private var detailToilet: Toilet?

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            ResizableSplit(
                axis: isLandscape ? .horizontal : .vertical,
                ratio: isLandscape ? $landscapeRatio : $portraitRatio,
                isDragging: $isDraggingSplit
            ) {
                listContent
                    .accessibilityLabel("Listenansicht der Toiletten")
            } secondary: {
                mapContent
                    .accessibilityLabel("Kartenansicht der Toiletten")
            }
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadToilets()
        }
        .onAppear {
            Analytics.shared.trackScreen("Results")
        }
        .sheet(item: $detailToilet) { toilet in
            DetailView(toilet: toilet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var listContent: some View {
        Group {
            if isLoading {
                ProgressView("Suche Toiletten...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Toiletten werden gesucht")
            } else if toilets.isEmpty {
                ContentUnavailableView("Keine Toiletten gefunden", systemImage: "toilet")
                    .accessibilityLabel("Keine Toiletten in der Nähe gefunden")
            } else {
                List(toilets) { toilet in
                    ToiletRowView(
                        toilet: toilet,
                        userLocation: location.coordinate,
                        onShowDetails: { openDetails(for: toilet, source: "list") }
                    )
                    .listRowBackground(toilet.id == selectedToilet?.id ? Color.purple.opacity(0.1) : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedToilet = toilet
                        Analytics.shared.trackEvent(category: "results", action: "select_toilet", name: String(toilet.id))
                    }
                }
                .listStyle(.plain)
                .accessibilityLabel("Toilettenliste")
            }
        }
    }

    private var mapContent: some View {
        MapView(
            center: location.coordinate,
            toilets: toilets,
            selectedToiletID: selectedToilet?.id,
            onShowDetails: { toilet in
                openDetails(for: toilet, source: "marker")
            }
        )
        .ignoresSafeArea(edges: [.bottom, .leading, .trailing])
    }

    private func openDetails(for toilet: Toilet, source: String) {
        detailToilet = toilet
        Analytics.shared.trackEvent(category: "results", action: "open_details_\(source)", name: String(toilet.id))
    }

    private func loadToilets() async {
        isLoading = true
        defer { isLoading = false }
        do {
            toilets = try await WCInfoAPIService.shared.fetchToiletsNearby(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                distance: 25
            )
            Analytics.shared.trackEvent(category: "results", action: "loaded", name: location.name, value: Float(toilets.count))
        } catch {
            var context: [String: Any] = [
                "action": "fetchToiletsNearby",
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ]
            var logToSentry = true
            if let apiError = error as? WCInfoAPIError {
                context.merge(apiError.diagnosticContext) { _, new in new }
                // invalidResponse already captured by the service with the full response body.
                if case .invalidResponse = apiError {
                    logToSentry = false
                }
            }
            ErrorManager.shared.report(error, context: context, logToSentry: logToSentry)
            Analytics.shared.trackEvent(category: "results", action: "error", name: location.name)
        }
    }
}

// A SwiftUI preview.
#Preview {
    ResultsView(location: .init(name: "Much-Niederheimbach", coordinate: .init(latitude: 50.895725646813936, longitude: 7.355648585165031)))
}
