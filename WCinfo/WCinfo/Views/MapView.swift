import SwiftUI
import GoogleMaps
import CoreLocation

struct MapView: UIViewRepresentable {
    let center: CLLocationCoordinate2D
    let toilets: [Toilet]
    let selectedToiletID: Int?

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: center.latitude, longitude: center.longitude, zoom: 14)
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.settings.myLocationButton = true
        mapView.delegate = context.coordinator
        mapView.accessibilityLabel = "Karte mit \(toilets.count) Toiletten in der Nähe"
        mapView.isAccessibilityElement = true
        print("[MapView] Created map at \(center.latitude), \(center.longitude)")
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let currentCenter = mapView.camera.target
        let shouldMove = abs(currentCenter.latitude - center.latitude) > 0.0001
            || abs(currentCenter.longitude - center.longitude) > 0.0001

        if shouldMove {
            let camera = GMSCameraPosition.camera(withLatitude: center.latitude, longitude: center.longitude, zoom: 14)
            mapView.animate(to: camera)
        }

        mapView.clear()
        for toilet in toilets {
            let marker = GMSMarker(position: toilet.coordinate)
            marker.title = toilet.displayName
            marker.snippet = toilet.accessibilitySnippet
            marker.icon = UIImage(named: toilet.markerIconName)
            marker.map = mapView
            if toilet.id == selectedToiletID {
                mapView.selectedMarker = marker
            }
        }

        mapView.accessibilityLabel = "Karte mit \(toilets.count) Toiletten in der Nähe"
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        @MainActor
        func mapView(_ mapView: GMSMapView, didFailToLocateUserWithError error: Error) {
            print("[MapView] didFailToLocateUserWithError: \(error.localizedDescription)")
            ErrorManager.shared.report(error, context: ["source": "MapView.userLocation"])
        }

        func mapViewDidStartTileRendering(_ mapView: GMSMapView) {
            print("[MapView] Started tile rendering")
        }

        func mapViewDidFinishTileRendering(_ mapView: GMSMapView) {
            print("[MapView] Finished tile rendering")
        }
    }
}

extension Toilet {
    var displayName: String {
        name.isEmpty ? "WC #\(id)" : name
    }

    var accessibilitySnippet: String {
        var parts = [String]()
        if hasWheelchairAccess { parts.append("Rollstuhlgerecht") }
        if isGenderSeparated { parts.append("Getrennte Toiletten") } else { parts.append("Unisex") }
        if hasChangingTable { parts.append("Wickeltisch") }
        if let address, !address.isEmpty { parts.append(address) }
        return parts.joined(separator: ", ")
    }

    var markerIconName: String {
        if hasWheelchairAccess {
            return "toiletAccessible"
        } else if isGenderSeparated {
            return "toiletGenderSeparated"
        } else {
            return "toiletUnisex"
        }
    }
}
