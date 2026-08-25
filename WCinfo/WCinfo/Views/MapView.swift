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
        let centerChanged = abs(currentCenter.latitude - center.latitude) > 0.0001
            || abs(currentCenter.longitude - center.longitude) > 0.0001

        if centerChanged {
            let camera = GMSCameraPosition.camera(withLatitude: center.latitude, longitude: center.longitude, zoom: 14)
            mapView.animate(to: camera)
        }

        mapView.clear()
        var selectedMarker: GMSMarker?
        for toilet in toilets {
            let marker = GMSMarker(position: toilet.coordinate)
            marker.title = toilet.displayName
            marker.snippet = toilet.accessibilitySnippet
            marker.icon = UIImage(named: toilet.markerIconName)
            marker.userData = toilet.id
            marker.map = mapView
            if toilet.id == selectedToiletID {
                selectedMarker = marker
            }
        }

        if let selectedMarker {
            mapView.selectedMarker = selectedMarker

            let selectionChanged = context.coordinator.lastSelectedID != selectedToiletID
            if selectionChanged {
                let camera = GMSCameraPosition.camera(
                    withTarget: selectedMarker.position,
                    zoom: max(mapView.camera.zoom, 16)
                )
                mapView.animate(to: camera)
                context.coordinator.lastSelectedID = selectedToiletID
            }
        } else {
            mapView.selectedMarker = nil
            context.coordinator.lastSelectedID = selectedToiletID
        }

        mapView.accessibilityLabel = "Karte mit \(toilets.count) Toiletten in der Nähe"
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var lastSelectedID: Int?

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
