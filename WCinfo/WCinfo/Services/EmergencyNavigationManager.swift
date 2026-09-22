import Foundation
import CoreLocation
import SwiftUI

enum EmergencyNavigationError: LocalizedError {
    case noToiletsFound
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .noToiletsFound:
            return "Keine passende Toilette in deiner Nähe gefunden."
        case .locationUnavailable:
            return "Dein aktueller Standort konnte nicht ermittelt werden."
        }
    }
}

@MainActor
final class EmergencyNavigationManager: ObservableObject {
    static let shared = EmergencyNavigationManager()

    @Published var isSearching = false
    @Published var statusMessage: String? = nil
    @Published var compassToilet: Toilet? = nil
    @Published var errorMessage: String? = nil

    private let locationManager = LocationManager()

    func handleURL(_ url: URL) {
        guard url.scheme == "wcinfo",
              url.host == "urgent-navigate" || url.path.contains("urgent-navigate") else {
            return
        }

        let filterSettings = ToiletFilterSettings(url: url)
        startUrgentNavigation(with: filterSettings)
    }

    func startUrgentNavigation(with filterSettings: ToiletFilterSettings) {
        Analytics.shared.trackEvent(
            category: "urgent_navigation",
            action: "trigger_from_widget",
            name: filterSettings.apiFilterQueryString ?? "all"
        )

        isSearching = true
        statusMessage = "Standort wird ermittelt..."
        errorMessage = nil

        Task {
            do {
                let location = try await locationManager.getCurrentLocation()

                statusMessage = "Nächste freie Toilette wird gesucht..."

                let filterQuery = filterSettings.apiFilterQueryString
                let toilets = try await WCInfoAPIService.shared.fetchToiletsNearby(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    distance: 25,
                    filter: filterQuery
                )

                let userLocation = location
                let sortedToilets = toilets.sorted { (t1: Toilet, t2: Toilet) -> Bool in
                    let d1 = userLocation.distance(from: CLLocation(latitude: t1.lat, longitude: t1.lon))
                    let d2 = userLocation.distance(from: CLLocation(latitude: t2.lat, longitude: t2.lon))
                    return d1 < d2
                }

                guard let nearest = sortedToilets.first else {
                    throw EmergencyNavigationError.noToiletsFound
                }

                Analytics.shared.trackEvent(
                    category: "urgent_navigation",
                    action: "found_nearest",
                    name: nearest.name
                )

                self.isSearching = false
                self.statusMessage = nil
                self.compassToilet = nearest
            } catch let error as EmergencyNavigationError {
                self.isSearching = false
                self.statusMessage = nil
                self.errorMessage = error.localizedDescription
                ErrorManager.shared.reportMessage(error.localizedDescription, context: ["action": "urgent_navigation"])
            } catch {
                self.isSearching = false
                self.statusMessage = nil
                self.errorMessage = "Fehler bei der Notfall-Suche: \(error.localizedDescription)"
                ErrorManager.shared.report(error, context: ["action": "urgent_navigation"])
            }
        }
    }
}
