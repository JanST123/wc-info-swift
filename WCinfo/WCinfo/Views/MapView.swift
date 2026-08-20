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
            marker.icon = MarkerRenderer.image(for: toilet)
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

private enum MarkerRenderer {
    static let pinColor = UIColor(red: 0x88 / 255, green: 0x3c / 255, blue: 0xae / 255, alpha: 1)
    static let size = CGSize(width: 44, height: 54)
    static let pinRadius: CGFloat = 18

    static func image(for toilet: Toilet) -> UIImage? {
        let symbolName = symbolName(for: toilet.type)
        return renderPin(symbolName: symbolName)
    }

    private static func symbolName(for type: String) -> String {
        switch type {
        case "mwd":
            return "figure.roll"
        case "mwb":
            return "figure.and.child.holdinghands"
        case "mw", "forall", "":
            return "person.2"
        default:
            return "person.2"
        }
    }

    private static func renderPin(symbolName: String) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        guard let symbol = UIImage(systemName: symbolName, withConfiguration: config)?.withTintColor(pinColor, renderingMode: .alwaysOriginal) else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let ctx = context.cgContext
            let center = CGPoint(x: size.width / 2, y: pinRadius + 4)

            // Pin circle
            ctx.setFillColor(pinColor.cgColor)
            ctx.fillEllipse(in: CGRect(x: center.x - pinRadius, y: center.y - pinRadius,
                                       width: pinRadius * 2, height: pinRadius * 2))

            // Pin point
            ctx.beginPath()
            ctx.move(to: CGPoint(x: center.x, y: size.height))
            ctx.addLine(to: CGPoint(x: center.x - pinRadius + 6, y: center.y + pinRadius - 6))
            ctx.addLine(to: CGPoint(x: center.x + pinRadius - 6, y: center.y + pinRadius - 6))
            ctx.closePath()
            ctx.fillPath()

            // White inner circle
            ctx.setFillColor(UIColor.white.cgColor)
            let innerRadius = pinRadius - 6
            ctx.fillEllipse(in: CGRect(x: center.x - innerRadius, y: center.y - innerRadius,
                                       width: innerRadius * 2, height: innerRadius * 2))

            // Symbol centered
            let symbolSize = symbol.size
            let symbolOrigin = CGPoint(x: center.x - symbolSize.width / 2,
                                       y: center.y - symbolSize.height / 2)
            symbol.draw(at: symbolOrigin)
        }
    }
}

extension Toilet {
    var displayName: String {
        name.isEmpty ? "WC #\(nr)" : name
    }
}
