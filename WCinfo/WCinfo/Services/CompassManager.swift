import Foundation
import CoreLocation

@MainActor
final class CompassManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var userLocation: CLLocation?
    @Published var heading: CLHeading?
    @Published var headingDegrees: Double = 0.0
    @Published var distanceInMeters: Double?
    @Published var bearingToTarget: Double?
    @Published var relativeAngle: Double = 0.0
    @Published var accumulatedNeedleAngle: Double = 0.0
    @Published var isHeadingAvailable: Bool = false
    @Published var isFacingTarget: Bool = false
    @Published var hasArrived: Bool = false

    let targetCoordinate: CLLocationCoordinate2D
    private let locationManager = CLLocationManager()

    init(targetCoordinate: CLLocationCoordinate2D) {
        self.targetCoordinate = targetCoordinate
        super.init()
        self.isHeadingAvailable = CLLocationManager.headingAvailable()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.distanceFilter = 1.0
        self.locationManager.headingFilter = 1.0
        self.authorizationStatus = locationManager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func start() {
        if !isAuthorized {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
            isHeadingAvailable = true
        } else {
            #if targetEnvironment(simulator)
            isHeadingAvailable = true
            headingDegrees = 20.0
            if userLocation == nil {
                userLocation = CLLocation(
                    latitude: targetCoordinate.latitude - 0.0011,
                    longitude: targetCoordinate.longitude - 0.0006
                )
            }
            recalculate()
            #else
            isHeadingAvailable = false
            #endif
        }

        if ProcessInfo.processInfo.arguments.contains("-UITest") {
            isHeadingAvailable = true
            headingDegrees = 15.0
            userLocation = CLLocation(
                latitude: targetCoordinate.latitude - 0.0011,
                longitude: targetCoordinate.longitude - 0.0006
            )
            recalculate()
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        userLocation = location
        recalculate()
    }

    private func handleHeadingUpdate(_ newHeading: CLHeading) {
        heading = newHeading
        if newHeading.trueHeading >= 0 {
            headingDegrees = newHeading.trueHeading
        } else if newHeading.magneticHeading >= 0 {
            headingDegrees = newHeading.magneticHeading
        }
        recalculate()
    }

    private func recalculate() {
        guard let userLoc = userLocation else { return }

        let targetLoc = CLLocation(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
        let distance = userLoc.distance(from: targetLoc)
        distanceInMeters = distance
        hasArrived = distance <= 10.0

        let bearing = Self.calculateBearing(from: userLoc.coordinate, to: targetCoordinate)
        bearingToTarget = bearing

        // Calculate relative angle to target (needle points towards target relative to device heading)
        let targetRaw = (bearing - headingDegrees).truncatingRemainder(dividingBy: 360.0)
        let normalizedTarget = targetRaw >= 0 ? targetRaw : targetRaw + 360.0
        relativeAngle = normalizedTarget

        // Check if facing target within +/- 15 degrees
        let angleDiffFromStraight = min(normalizedTarget, 360.0 - normalizedTarget)
        isFacingTarget = angleDiffFromStraight <= 15.0

        // Smooth accumulated angle to prevent 360-degree spinning flip
        updateSmoothAngle(targetAngle: normalizedTarget)
    }

    private func updateSmoothAngle(targetAngle: Double) {
        var currentNormalized = accumulatedNeedleAngle.truncatingRemainder(dividingBy: 360.0)
        if currentNormalized < 0 { currentNormalized += 360.0 }

        var diff = targetAngle - currentNormalized
        if diff > 180.0 {
            diff -= 360.0
        } else if diff < -180.0 {
            diff += 360.0
        }
        accumulatedNeedleAngle += diff
    }

    static func calculateBearing(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180.0
        let lon1 = start.longitude * .pi / 180.0
        let lat2 = destination.latitude * .pi / 180.0
        let lon2 = destination.longitude * .pi / 180.0

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        let degrees = radians * 180.0 / .pi
        return (degrees + 360.0).truncatingRemainder(dividingBy: 360.0)
    }

    var directionDescription: String {
        guard let _ = distanceInMeters else {
            return String(localized: "Standort wird ermittelt...")
        }
        if hasArrived {
            return String(localized: "Du hast das Ziel erreicht!")
        }
        if !isHeadingAvailable {
            return String(localized: "Kompass nicht verfügbar")
        }

        let angle = relativeAngle
        switch angle {
        case 345...360, 0..<15:
            return String(localized: "Geradeaus")
        case 15..<75:
            return String(localized: "Halb rechts")
        case 75..<105:
            return String(localized: "Rechts")
        case 105..<165:
            return String(localized: "Scharf rechts")
        case 165..<195:
            return String(localized: "Hinter dir")
        case 195..<255:
            return String(localized: "Scharf links")
        case 255..<285:
            return String(localized: "Links")
        case 285..<345:
            return String(localized: "Halb links")
        default:
            return String(localized: "Geradeaus")
        }
    }
}

extension CompassManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                start()
            case .denied, .restricted:
                stop()
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.handleLocationUpdate(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            self.handleHeadingUpdate(newHeading)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let nsError = error as NSError
            guard nsError.code != CLError.Code.locationUnknown.rawValue else { return }
            ErrorManager.shared.report(error, context: ["source": "CompassManager"])
        }
    }
}
