import Foundation
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var location: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func requestAuthorization() {
        Analytics.shared.trackEvent(category: "location", action: "request_authorization")
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        guard isAuthorized else {
            requestAuthorization()
            return
        }
        manager.requestLocation()
    }

    func getCurrentLocation(timeoutSeconds: Double = 8) async throws -> CLLocation {
        if let existing = location, existing.timestamp.timeIntervalSinceNow > -30 {
            return existing
        }

        requestLocation()

        return try await withThrowingTaskGroup(of: CLLocation.self) { group in
            group.addTask { @MainActor in
                for await loc in self.$location.values {
                    if let loc = loc {
                        return loc
                    }
                }
                throw CLError(.locationUnknown)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw CLError(.locationUnknown)
            }

            guard let result = try await group.next() else {
                throw CLError(.locationUnknown)
            }
            group.cancelAll()
            return result
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                Analytics.shared.trackEvent(category: "location", action: "authorized")
                manager.requestLocation()
            case .denied, .restricted:
                Analytics.shared.trackEvent(category: "location", action: "denied")
                ErrorManager.shared.reportMessage(
                    String(localized: "Standortzugriff wurde verweigert. Bitte aktiviere den Standortzugriff in den Einstellungen, um Toiletten in der Nähe zu finden."),
                    context: ["status": String(describing: authorizationStatus)]
                )
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            location = locations.last
            Analytics.shared.trackEvent(category: "location", action: "updated")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let nsError = error as NSError
            // Ignore location simulation cancellation.
            guard nsError.code != CLError.Code.locationUnknown.rawValue else { return }
            ErrorManager.shared.report(error, context: ["source": "LocationManager"])
        }
    }
}
