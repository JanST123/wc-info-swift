import SwiftUI
import CoreLocation
import MapKit

struct ResultsView: View {
    let location: SearchedLocation

    @State private var toilets: [Toilet] = []
    @State private var isLoading = true
    @State private var portraitRatio: CGFloat = 0.66
    @State private var landscapeRatio: CGFloat = 0.5
    @State private var isDraggingSplit = false
    @State private var selectedToilet: Toilet?
    @State private var detailToilet: Toilet?
    @State private var isShowingCreateSheet = false
    @State private var createSheetCoordinate: CLLocationCoordinate2D? = nil
    @State private var filterSettings = ToiletFilterSettings.load()

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
        .sheet(isPresented: $isShowingCreateSheet) {
            CreateScreen(
                location: location,
                initialCoordinate: createSheetCoordinate
            ) {
                Task {
                    await loadToilets()
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var listContent: some View {
        VStack(spacing: 8) {
            FilterBannerView(filterSettings: $filterSettings) {
                Task {
                    await loadToilets()
                }
            }

            addToiletBanner

            if isLoading && toilets.isEmpty {
                ProgressView("Suche Toiletten...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Toiletten werden gesucht")
            } else if toilets.isEmpty {
                ScrollView {
                    ContentUnavailableView("Keine Toiletten gefunden", systemImage: "toilet")
                        .accessibilityLabel("Keine Toiletten in der Nähe gefunden")
                        .padding(.top, 40)
                }
                .refreshable {
                    await loadToilets(isPullToRefresh: true)
                }
            } else {
                List(toilets) { toilet in
                    ToiletRowView(
                        toilet: toilet,
                        userLocation: location.coordinate,
                        isActive: toilet.id == selectedToilet?.id,
                        onShowDetails: { openDetails(for: toilet, source: "list") },
                        onNavigate: { openNavigation(to: toilet) }
                    )
                    .listRowBackground(toilet.id == selectedToilet?.id ? Color.purple.opacity(0.1) : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedToilet = toilet
                        Analytics.shared.trackEvent(category: "results", action: "select_toilet", name: String(toilet.id))
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await loadToilets(isPullToRefresh: true)
                }
                .accessibilityLabel("Toilettenliste")
            }
        }
    }

    private var addToiletBanner: some View {
        Button {
            createSheetCoordinate = nil
            isShowingCreateSheet = true
            Analytics.shared.trackEvent(category: "results", action: "click_add_toilet_banner")
        } label: {
            VStack(spacing: 4) {
                Text("Fehlt eine Toilette?")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Text("Klicke hier um eine Toilette hinzuzufügen - wir freuen uns!")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color.purple)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .purple.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
        .accessibilityLabel("Fehlt eine Toilette? Klicke hier um eine Toilette hinzuzufügen")
    }

    private var mapContent: some View {
        MapView(
            center: location.coordinate,
            toilets: toilets,
            selectedToiletID: selectedToilet?.id,
            onShowDetails: { toilet in
                openDetails(for: toilet, source: "marker")
            },
            onAddToiletAtCoordinate: { coordinate in
                createSheetCoordinate = coordinate
                isShowingCreateSheet = true
            }
        )
        .ignoresSafeArea(edges: [.bottom, .leading, .trailing])
    }

    private func openDetails(for toilet: Toilet, source: String) {
        selectedToilet = toilet
        detailToilet = toilet
        Analytics.shared.trackEvent(category: "results", action: "open_details_\(source)", name: String(toilet.id))
    }

    private func openNavigation(to toilet: Toilet) {
        Analytics.shared.trackEvent(category: "results", action: "navigate", name: String(toilet.id))
        let item = MKMapItem(placemark: MKPlacemark(coordinate: toilet.coordinate))
        item.name = toilet.displayName
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    private func loadToilets(isPullToRefresh: Bool = false) async {
        if !isPullToRefresh {
            isLoading = true
        }
        defer { isLoading = false }
        do {
            toilets = try await WCInfoAPIService.shared.fetchToiletsNearby(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                distance: 25,
                filter: filterSettings.apiFilterQueryString
            )
            Analytics.shared.trackEvent(category: "results", action: isPullToRefresh ? "refresh" : "loaded", name: location.name, value: Float(toilets.count))
        } catch {
            var context: [String: Any] = [
                "action": "fetchToiletsNearby",
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "filter": filterSettings.apiFilterQueryString ?? ""
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
