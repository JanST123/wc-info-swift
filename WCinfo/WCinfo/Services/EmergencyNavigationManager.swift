import Foundation
import CoreLocation
import SwiftUI

enum EmergencyNavigationError: LocalizedError {
    case noToiletsFound
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .noToiletsFound:
            return String(localized: "Keine passende Toilette im Umkreis von 10 km gefunden.")
        case .locationUnavailable:
            return String(localized: "Dein aktueller Standort konnte nicht ermittelt werden.")
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
    private let maxSearchDistanceKm = 10

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
        statusMessage = String(localized: "Standort wird ermittelt...")
        errorMessage = nil

        Task {
            do {
                let location = try await locationManager.getCurrentLocation()
                let userLocation = location

                statusMessage = String(localized: "Nächste Toilette wird gesucht...")

                let initialFilterQuery = filterSettings.apiFilterQueryString
                let toilets = try await WCInfoAPIService.shared.fetchToiletsNearby(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    distance: maxSearchDistanceKm,
                    filter: initialFilterQuery
                )

                let sortedToilets = toilets.sorted { (t1: Toilet, t2: Toilet) -> Bool in
                    let d1 = userLocation.distance(from: CLLocation(latitude: t1.lat, longitude: t1.lon))
                    let d2 = userLocation.distance(from: CLLocation(latitude: t2.lat, longitude: t2.lon))
                    return d1 < d2
                }

                var selectedToilet: Toilet? = sortedToilets.first { ($0.placeOpeningHours?.count ?? 0) > 0 || $0.accessibleOutsideOpeningTimes }
                var fallbackUsed = false

                // Non-public fallback check:
                // If public-only was selected, fallback is enabled, and the closest public toilet
                // is further away than maxPublicDistanceMeters (or none was found within 10km),
                // search for closer opened non-public toilets within 10km.
                if !filterSettings.showNonPublic && filterSettings.allowNonPublicFallback {
                    let publicDistance = selectedToilet.map {
                        userLocation.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lon))
                    } ?? Double.infinity

                    if publicDistance > Double(filterSettings.maxPublicDistanceMeters) {
                        statusMessage = String(localized: "Prüfe nähere geöffnete Toiletten...")

                        var fallbackSettings = filterSettings
                        fallbackSettings.showNonPublic = true // allow non-public
                        fallbackSettings.showClosed = false   // must be opened

                        let fallbackToilets = try await WCInfoAPIService.shared.fetchToiletsNearby(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            distance: maxSearchDistanceKm,
                            filter: fallbackSettings.apiFilterQueryString
                        )

                        let sortedFallback = fallbackToilets.sorted { (t1: Toilet, t2: Toilet) -> Bool in
                            let d1 = userLocation.distance(from: CLLocation(latitude: t1.lat, longitude: t1.lon))
                            let d2 = userLocation.distance(from: CLLocation(latitude: t2.lat, longitude: t2.lon))
                            return d1 < d2
                        }

                        if let nearestFallback = sortedFallback.first(where: { ($0.placeOpeningHours?.count ?? 0) > 0 || $0.accessibleOutsideOpeningTimes }) {
                            let fallbackDistance = userLocation.distance(
                                from: CLLocation(latitude: nearestFallback.lat, longitude: nearestFallback.lon)
                            )
                            if fallbackDistance < publicDistance {
                                selectedToilet = nearestFallback
                                fallbackUsed = true
                            }
                        }
                    }
                }

                guard let targetToilet = selectedToilet else {
                    throw EmergencyNavigationError.noToiletsFound
                }

                Analytics.shared.trackEvent(
                    category: "urgent_navigation",
                    action: fallbackUsed ? "found_nearest_nonpublic_fallback" : "found_nearest",
                    name: targetToilet.name
                )

                self.isSearching = false
                self.statusMessage = nil
                self.compassToilet = targetToilet
            } catch let error as EmergencyNavigationError {
                self.isSearching = false
                self.statusMessage = nil
                self.errorMessage = error.localizedDescription
                ErrorManager.shared.reportMessage(error.localizedDescription, context: ["action": "urgent_navigation"])
            } catch {
                self.isSearching = false
                self.statusMessage = nil
                let errDesc = error.localizedDescription
                self.errorMessage = String(localized: "Fehler bei der Notfall-Suche: \(errDesc)")
                ErrorManager.shared.report(error, context: ["action": "urgent_navigation"])
            }
        }
    }
}
