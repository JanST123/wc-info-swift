import SwiftUI
import GoogleMaps
import CoreLocation

struct MapView: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    let center: CLLocationCoordinate2D
    let toilets: [Toilet]
    let selectedToiletID: Int?
    var mapType: GMSMapViewType = .normal
    var onShowDetails: (Toilet) -> Void = { _ in }
    var onAddToiletAtCoordinate: ((CLLocationCoordinate2D) -> Void)? = nil
    var onCameraWillMove: ((_ gesture: Bool) -> Void)? = nil
    var onCameraIdle: ((_ south: Double, _ west: Double, _ north: Double, _ east: Double) -> Void)? = nil

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: center.latitude, longitude: center.longitude, zoom: 14)
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.mapType = mapType
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.delegate = context.coordinator
        mapView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let template = String(localized: "Karte mit %lld Toiletten in der Nähe")
        mapView.accessibilityLabel = String(format: template, Int64(toilets.count))
        mapView.isAccessibilityElement = true
        context.coordinator.lastCenter = center
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.toilets = toilets
        context.coordinator.onShowDetails = onShowDetails
        context.coordinator.onAddToiletAtCoordinate = onAddToiletAtCoordinate
        context.coordinator.onCameraWillMove = onCameraWillMove
        context.coordinator.onCameraIdle = onCameraIdle

        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        if !mapView.isMyLocationEnabled {
            mapView.isMyLocationEnabled = true
        }

        let targetStyle: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        if mapView.overrideUserInterfaceStyle != targetStyle {
            mapView.overrideUserInterfaceStyle = targetStyle
        }

        let centerChanged = context.coordinator.lastCenter == nil ||
            abs(context.coordinator.lastCenter!.latitude - center.latitude) > 0.0001 ||
            abs(context.coordinator.lastCenter!.longitude - center.longitude) > 0.0001

        if centerChanged {
            context.coordinator.lastCenter = center
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

        let template = String(localized: "Karte mit %lld Toiletten in der Nähe")
        mapView.accessibilityLabel = String(format: template, Int64(toilets.count))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: MapView
        var toilets: [Toilet] = []
        var onShowDetails: (Toilet) -> Void = { _ in }
        var onAddToiletAtCoordinate: ((CLLocationCoordinate2D) -> Void)? = nil
        var onCameraWillMove: ((_ gesture: Bool) -> Void)? = nil
        var onCameraIdle: ((_ south: Double, _ west: Double, _ north: Double, _ east: Double) -> Void)? = nil
        var lastCenter: CLLocationCoordinate2D?
        var lastSelectedID: Int?
        var addMarker: GMSMarker?

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
            onCameraWillMove?(gesture)
        }

        func mapView(_ mapView: GMSMapView, idleAt cameraPosition: GMSCameraPosition) {
            let visibleRegion = mapView.projection.visibleRegion()
            let south = min(visibleRegion.nearLeft.latitude, visibleRegion.nearRight.latitude)
            let north = max(visibleRegion.farLeft.latitude, visibleRegion.farRight.latitude)
            let west = min(visibleRegion.nearLeft.longitude, visibleRegion.farLeft.longitude)
            let east = max(visibleRegion.nearRight.longitude, visibleRegion.farRight.longitude)
            onCameraIdle?(south, west, north, east)
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            if let existing = addMarker {
                existing.map = nil
                addMarker = nil
            }
        }

        func mapView(_ mapView: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D) {
            addMarker?.map = nil

            let marker = GMSMarker(position: coordinate)
            marker.title = String(localized: "Neue Toilette hinzufügen")
            marker.snippet = String(localized: "Tippe hier, um an diesem Ort eine Toilette einzutragen ›")
            marker.icon = GMSMarker.markerImage(with: .systemPurple)
            marker.userData = "add_toilet_marker"
            marker.map = mapView
            addMarker = marker
            mapView.selectedMarker = marker
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
/// `GMSMapViewDelegate.mapView(_:didTapInfoWindowOf:)` .
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
        detailsLabel.text = String(localized: "Details ansehen ›")
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
        accessibilityHint = String(localized: "Doppeltippen, um Details zu öffnen.")
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
        titleLabel.text = String(localized: "Neue Toilette hinzufügen")
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 1
        titleLabel.textColor = .systemPurple

        let snippetLabel = UILabel()
        snippetLabel.text = String(localized: "Tippe hier, um an diesem Ort eine Toilette einzutragen ›")
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
        accessibilityLabel = String(localized: "Neue Toilette an diesem Ort hinzufügen")
        accessibilityHint = String(localized: "Doppeltippen, um die Toilettenerfassung zu starten.")
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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "toilette" {
            return String(localized: "Toilette")
        }
        return name
    }

    var accessibilitySnippet: String {
        var parts = [String]()
        if hasWheelchairAccess { parts.append(String(localized: "Rollstuhlgerecht")) }
        if isGenderSeparated { parts.append(String(localized: "Getrennte Toiletten")) } else { parts.append(String(localized: "Unisex")) }
        if hasChangingTable { parts.append(String(localized: "Wickeltisch")) }
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
