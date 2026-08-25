import SwiftUI
import CoreLocation

struct ResultsView: View {
    let location: SearchedLocation

    @State private var toilets: [Toilet] = []
    @State private var isLoading = true
    @State private var selectedToiletID: Int?
    @State private var portraitRatio: CGFloat = 0.66
    @State private var landscapeRatio: CGFloat = 0.5
    @State private var isDraggingSplit = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            ResizableSplit(
                axis: isLandscape ? .horizontal : .vertical,
                ratio: isLandscape ? $landscapeRatio : $portraitRatio,
                isDragging: $isDraggingSplit
            ) {
                listContent
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Listenansicht der Toiletten")
            } secondary: {
                mapContent
                    .accessibilityElement(children: .contain)
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
    }

    private var listContent: some View {
        NavigationStack(path: $navigationPath) {
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
                        ToiletRowView(toilet: toilet, userLocation: location.coordinate)
                            .listRowBackground(toilet.id == selectedToiletID ? Color.purple.opacity(0.1) : Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedToiletID = toilet.id
                                navigationPath.append(toilet)
                                Analytics.shared.trackEvent(category: "results", action: "select_toilet", name: String(toilet.id))
                            }
                            .accessibilityHint("Toilette auf der Karte anzeigen und Details öffnen")
                            .accessibilityAddTraits(.isButton)
                    }
                    .listStyle(.plain)
                    .accessibilityLabel("Toilettenliste")
                }
            }
            .navigationDestination(for: Toilet.self) { toilet in
                DetailView(toilet: toilet)
            }
        }
    }

    private var mapContent: some View {
        MapView(center: location.coordinate, toilets: toilets, selectedToiletID: selectedToiletID)
            .ignoresSafeArea(edges: [.bottom, .leading, .trailing])
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
            ErrorManager.shared.report(error, context: [
                "action": "fetchToiletsNearby",
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ])
            Analytics.shared.trackEvent(category: "results", action: "error", name: location.name)
        }
    }
}
