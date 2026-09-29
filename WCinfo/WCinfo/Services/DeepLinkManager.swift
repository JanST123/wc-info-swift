import Foundation
import CoreLocation
import SwiftUI

@MainActor
final class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published var selectedLocation: SearchedLocation?
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String?

    private let placesService = PlacesService()

    func handleURL(_ url: URL) {
        // 1. Check if it's an urgent navigation URL
        if url.scheme?.lowercased() == "wcinfo", url.host == "urgent-navigate" || url.path.contains("urgent-navigate") {
            EmergencyNavigationManager.shared.handleURL(url)
            return
        }

        // 2. Parse Universal Link / deep link
        guard let deepLink = DeepLinkParser.parse(url: url) else {
            return
        }

        switch deepLink {
        case .home:
            selectedLocation = nil

        case .urgentNavigation(let filterSettings):
            EmergencyNavigationManager.shared.startUrgentNavigation(with: filterSettings)

        case .toilets(let placeId, let placeName, let toiletId, _):
            openToilets(placeId: placeId, fallbackName: placeName, toiletId: toiletId)
        }
    }

    private func openToilets(placeId: String, fallbackName: String?, toiletId: Int?) {
        isLoading = true
        loadingMessage = String(localized: "Ort wird geladen...")
        Analytics.shared.trackEvent(
            category: "deep_link",
            action: "open_toilets",
            name: "\(placeId)\(toiletId.map { "/\($0)" } ?? "")"
        )

        Task {
            do {
                var coordinate: CLLocationCoordinate2D? = nil
                var resolvedName = fallbackName

                do {
                    let details = try await placesService.fetchPlaceDetails(for: placeId)
                    coordinate = details.coordinate
                    if let name = details.name, !name.isEmpty {
                        resolvedName = name
                    }
                } catch {
                    coordinate = try await placesService.fetchCoordinates(for: placeId)
                }

                guard let coord = coordinate else {
                    throw PlacesService.PlacesError.noCoordinate
                }

                let finalName = (resolvedName?.isEmpty == false) ? resolvedName! : String(localized: "Ausgewählter Ort")
                let location = SearchedLocation(
                    name: finalName,
                    coordinate: coord,
                    initialToiletId: toiletId
                )

                self.isLoading = false
                self.loadingMessage = nil
                self.selectedLocation = location
            } catch {
                self.isLoading = false
                self.loadingMessage = nil
                ErrorManager.shared.report(
                    error,
                    context: [
                        "action": "open_toilets_deep_link",
                        "placeId": placeId,
                        "toiletId": String(toiletId ?? -1)
                    ]
                )
            }
        }
    }
}
