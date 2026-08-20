import SwiftUI
import GoogleMaps
import CoreLocation

struct MapView: UIViewRepresentable {
    let center: CLLocationCoordinate2D
    let toilets: [Toilet]
    let selectedToiletID: String?

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: center.latitude, longitude: center.longitude, zoom: 14)
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.settings.myLocationButton = true
        mapView.delegate = context.coordinator
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
            guard let coordinate = toilet.coordinate else { continue }
            let marker = GMSMarker(position: coordinate)
            marker.title = toilet.displayName
            marker.snippet = toilet.address
            marker.map = mapView
            if toilet.id == selectedToiletID {
                mapView.selectedMarker = marker
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        func mapView(_ mapView: GMSMapView, didFailToLocateUserWithError error: Error) {
            print("[MapView] didFailToLocateUserWithError: \(error.localizedDescription)")
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
        name.isEmpty ? "WC #\(nr)" : name
    }
}
