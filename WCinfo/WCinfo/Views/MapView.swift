import SwiftUI
import GoogleMaps
import CoreLocation

struct MapView: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    let center: CLLocationCoordinate2D
    let toilets: [Toilet]
    let selectedToiletID: Int?
    var onShowDetails: (Toilet) -> Void = { _ in }
    var onAddToiletAtCoordinate: ((CLLocationCoordinate2D) -> Void)? = nil

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: center.latitude, longitude: center.longitude, zoom: 14)
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.settings.myLocationButton = true
        mapView.delegate = context.coordinator
        mapView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        mapView.accessibilityLabel = "Karte mit \(toilets.count) Toiletten in der Nähe"
        mapView.isAccessibilityElement = true
        print("[MapView] Created map at \(center.latitude), \(center.longitude)")
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.toilets = toilets
        context.coordinator.onShowDetails = onShowDetails
        context.coordinator.onAddToiletAtCoordinate = onAddToiletAtCoordinate

        let targetStyle: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        if mapView.overrideUserInterfaceStyle != targetStyle {
            mapView.overrideUserInterfaceStyle = targetStyle
        }

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

        // Restore active addMarker if present
        if let addMarker = context.coordinator.addMarker {
            addMarker.map = mapView
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
        } else if context.coordinator.addMarker == nil {
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
        var toilets: [Toilet] = []
        var onShowDetails: (Toilet) -> Void = { _ in }
        var onAddToiletAtCoordinate: ((CLLocationCoordinate2D) -> Void)? = nil
        var addMarker: GMSMarker?

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

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            addMarker?.map = nil
            let marker = GMSMarker(position: coordinate)
            marker.title = "Neue Toilette hinzufügen"
            marker.snippet = "Tippe hier, um eine Toilette hinzuzufügen ›"
            marker.icon = GMSMarker.markerImage(with: .systemPurple)
            marker.userData = "add_toilet_marker"
            marker.map = mapView
            mapView.selectedMarker = marker
            addMarker = marker
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if marker.userData as? String != "add_toilet_marker" {
                addMarker?.map = nil
                addMarker = nil
            }
            return false
        }

        func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
            if marker.userData as? String == "add_toilet_marker" {
                return AddToiletInfoWindowView(userInterfaceStyle: mapView.overrideUserInterfaceStyle)
            }
            guard let toiletID = marker.userData as? Int,
                  let toilet = toilets.first(where: { $0.id == toiletID }) else {
                return nil
            }
            return ToiletInfoWindowView(toilet: toilet, userInterfaceStyle: mapView.overrideUserInterfaceStyle)
        }

        func mapView(_ mapView: GMSMapView, didTapInfoWindowOf marker: GMSMarker) {
            if marker.userData as? String == "add_toilet_marker" {
                let coordinate = marker.position
                marker.map = nil
                addMarker = nil
                onAddToiletAtCoordinate?(coordinate)
                return
            }
            guard let toiletID = marker.userData as? Int,
                  let toilet = toilets.first(where: { $0.id == toiletID }) else {
                return
            }
            onShowDetails(toilet)
        }
    }
}

/// Custom info window content shown above a tapped marker.
/// Note: GMSMapView renders info windows as a static snapshot, so real
/// UIControls (e.g. UIButton) inside this view will not receive touches.
/// Taps anywhere on the window are instead handled by
/// `GMSMapViewDelegate.mapView(_:didTapInfoWindowOf:)`.
private final class ToiletInfoWindowView: UIView {
    private static let maxWidth: CGFloat = 260
    private static let horizontalPadding: CGFloat = 12
    private static let verticalPadding: CGFloat = 8

    init(toilet: Toilet, userInterfaceStyle: UIUserInterfaceStyle = .unspecified) {
        super.init(frame: .zero)
        overrideUserInterfaceStyle = userInterfaceStyle
        backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = toilet.displayName
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 1
        titleLabel.textColor = .label

        let snippetLabel = UILabel()
        snippetLabel.text = toilet.accessibilitySnippet
        snippetLabel.font = .preferredFont(forTextStyle: .footnote)
        snippetLabel.textColor = .secondaryLabel
        snippetLabel.numberOfLines = 2

        let detailsLabel = UILabel()
        detailsLabel.text = "Details ansehen ›"
        detailsLabel.font = .preferredFont(forTextStyle: .footnote).withTraits(.traitBold) ?? .boldSystemFont(ofSize: 13)
        detailsLabel.textColor = .systemPurple

        let textStack = UIStackView(arrangedSubviews: [titleLabel, snippetLabel, detailsLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.frame = CGRect(
            x: Self.horizontalPadding,
            y: Self.verticalPadding,
            width: Self.maxWidth - Self.horizontalPadding * 2,
            height: 0
        )

        addSubview(textStack)

        // GMSMapView uses this view's `frame` directly (it does not resolve
        // Auto Layout constraints), so we must size it manually up front.
        let fittingSize = textStack.systemLayoutSizeFitting(
            CGSize(width: Self.maxWidth - Self.horizontalPadding * 2, height: .greatestFiniteMagnitude),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        textStack.frame.size = fittingSize
        frame = CGRect(
            x: 0,
            y: 0,
            width: Self.maxWidth,
            height: fittingSize.height + Self.verticalPadding * 2
        )

        isAccessibilityElement = true
        accessibilityLabel = "\(toilet.displayName). \(toilet.accessibilitySnippet)"
        accessibilityHint = "Doppeltippen, um Details zu öffnen."
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class AddToiletInfoWindowView: UIView {
    private static let maxWidth: CGFloat = 250
    private static let horizontalPadding: CGFloat = 12
    private static let verticalPadding: CGFloat = 8

    init(userInterfaceStyle: UIUserInterfaceStyle = .unspecified) {
        super.init(frame: .zero)
        overrideUserInterfaceStyle = userInterfaceStyle
        backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = "Neue Toilette hinzufügen"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 1
        titleLabel.textColor = .systemPurple

        let snippetLabel = UILabel()
        snippetLabel.text = "Tippe hier, um an diesem Ort eine Toilette einzutragen ›"
        snippetLabel.font = .preferredFont(forTextStyle: .footnote)
        snippetLabel.textColor = .secondaryLabel
        snippetLabel.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [titleLabel, snippetLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.frame = CGRect(
            x: Self.horizontalPadding,
            y: Self.verticalPadding,
            width: Self.maxWidth - Self.horizontalPadding * 2,
            height: 0
        )

        addSubview(textStack)

        let fittingSize = textStack.systemLayoutSizeFitting(
            CGSize(width: Self.maxWidth - Self.horizontalPadding * 2, height: .greatestFiniteMagnitude),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        textStack.frame.size = fittingSize
        frame = CGRect(
            x: 0,
            y: 0,
            width: Self.maxWidth,
            height: fittingSize.height + Self.verticalPadding * 2
        )

        isAccessibilityElement = true
        accessibilityLabel = "Neue Toilette an diesem Ort hinzufügen"
        accessibilityHint = "Doppeltippen, um die Toilettenerfassung zu starten."
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return nil }
        return UIFont(descriptor: descriptor, size: pointSize)
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
