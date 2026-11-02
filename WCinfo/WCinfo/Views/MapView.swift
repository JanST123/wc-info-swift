import SwiftUI
import GoogleMaps
import CoreLocation
import CoreImage

struct MapView: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    let center: CLLocationCoordinate2D
    var locationName: String? = nil
    let toilets: [Toilet]
    let selectedToiletID: Int?
    var mapType: GMSMapViewType = .normal
    var onSelectToilet: ((Toilet?) -> Void)? = nil
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
        context.coordinator.onSelectToilet = onSelectToilet
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

        if let selectedToiletID {
            context.coordinator.activeInfoWindowToiletID = selectedToiletID
            context.coordinator.isCenterMarkerSelected = false
        }

        // Preserve any currently open marker tooltip ID across marker rebuilds
        let activeMarkerToiletID = selectedToiletID
            ?? (mapView.selectedMarker?.userData as? Int)
            ?? context.coordinator.activeInfoWindowToiletID

        let isCenterMarkerSelected = (mapView.selectedMarker?.userData as? String == "center_location_marker")
            || context.coordinator.isCenterMarkerSelected

        mapView.clear()

        // Default marker at the searched/current location of the ResultsView
        let centerMarker = GMSMarker(position: center)
        centerMarker.title = locationName ?? String(localized: "Ausgewählter Ort")
        centerMarker.userData = "center_location_marker"
        centerMarker.map = mapView

        var selectedMarker: GMSMarker?
        for toilet in toilets {
            if toilet.isSummary, let bounds = toilet.summaryBounds, bounds.isValid {
                let sw = CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.west)
                let ne = CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.east)
                let gmsBounds = GMSCoordinateBounds(coordinate: sw, coordinate: ne)

                if let shiningImage = MarkerImageCache.shiningOverlayImage {
                    let overlay = GMSGroundOverlay(bounds: gmsBounds, icon: shiningImage)
                    overlay.zIndex = toilet.id == activeMarkerToiletID ? 2 : 1
                    overlay.opacity = toilet.id == activeMarkerToiletID ? 1.0 : 0.75
                    overlay.map = mapView
                }

                if toilet.id == activeMarkerToiletID {
                    let rectPath = GMSMutablePath()
                    rectPath.add(CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.west))
                    rectPath.add(CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.west))
                    rectPath.add(CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.east))
                    rectPath.add(CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.east))
                    rectPath.add(CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.west))

                    let polygon = GMSPolygon(path: rectPath)
                    polygon.strokeColor = UIColor.systemPurple.withAlphaComponent(0.6)
                    polygon.strokeWidth = 2.0
                    polygon.fillColor = UIColor.systemPurple.withAlphaComponent(0.08)
                    polygon.zIndex = 3
                    polygon.map = mapView
                }
            }

            let marker = GMSMarker(position: toilet.coordinate)
            marker.title = toilet.displayName
            marker.snippet = toilet.accessibilitySnippet
            marker.icon = toilet.markerIcon
            marker.userData = toilet.id
            if toilet.isSummary {
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                marker.infoWindowAnchor = CGPoint(x: 0.5, y: 0.0)
                marker.zIndex = 10
            } else {
                marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
                marker.infoWindowAnchor = CGPoint(x: 0.5, y: 0.0)
                marker.zIndex = 5
            }
            marker.map = mapView
            if toilet.id == activeMarkerToiletID {
                selectedMarker = marker
            }
        }

        // Restore active addMarker if present
        if let addMarker = context.coordinator.addMarker {
            addMarker.map = mapView
            if activeMarkerToiletID == nil && !isCenterMarkerSelected {
                mapView.selectedMarker = addMarker
            }
        }

        if let selectedMarker {
            mapView.selectedMarker = selectedMarker

            let selectionChanged = context.coordinator.lastSelectedID != selectedToiletID
            if selectionChanged, selectedToiletID != nil {
                if let toilet = toilets.first(where: { $0.id == selectedToiletID }),
                   toilet.isSummary,
                   let bounds = toilet.summaryBounds,
                   bounds.isValid {
                    let sw = CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.west)
                    let ne = CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.east)
                    let gmsBounds = GMSCoordinateBounds(coordinate: sw, coordinate: ne)
                    let update = GMSCameraUpdate.fit(gmsBounds, withPadding: 60)
                    mapView.animate(with: update)
                } else {
                    let camera = GMSCameraPosition.camera(
                        withTarget: selectedMarker.position,
                        zoom: max(mapView.camera.zoom, 16)
                    )
                    mapView.animate(to: camera)
                }
                context.coordinator.lastSelectedID = selectedToiletID
            }
        } else if isCenterMarkerSelected && activeMarkerToiletID == nil {
            mapView.selectedMarker = centerMarker
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
        var onSelectToilet: ((Toilet?) -> Void)? = nil
        var onShowDetails: (Toilet) -> Void = { _ in }
        var onAddToiletAtCoordinate: ((CLLocationCoordinate2D) -> Void)? = nil
        var onCameraWillMove: ((_ gesture: Bool) -> Void)? = nil
        var onCameraIdle: ((_ south: Double, _ west: Double, _ north: Double, _ east: Double) -> Void)? = nil
        var lastCenter: CLLocationCoordinate2D?
        var lastSelectedID: Int?
        var activeInfoWindowToiletID: Int?
        var isCenterMarkerSelected: Bool = false
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

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if marker.userData as? String == "center_location_marker" {
                activeInfoWindowToiletID = nil
                lastSelectedID = nil
                isCenterMarkerSelected = true
                onSelectToilet?(nil)
                return false
            }
            if let toiletID = marker.userData as? Int,
               let toilet = toilets.first(where: { $0.id == toiletID }) {
                activeInfoWindowToiletID = toiletID
                lastSelectedID = toiletID
                isCenterMarkerSelected = false
                onSelectToilet?(toilet)
            }
            return false
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            if let existing = addMarker {
                existing.map = nil
                addMarker = nil
            }
            activeInfoWindowToiletID = nil
            lastSelectedID = nil
            isCenterMarkerSelected = false
            onSelectToilet?(nil)
        }

        func mapView(_ mapView: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D) {
            addMarker?.map = nil
            activeInfoWindowToiletID = nil
            lastSelectedID = nil
            isCenterMarkerSelected = false
            onSelectToilet?(nil)

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
            // In summary mode, result rows do not contain valid toilet ids; opening the detail view is prevented
            guard !toilet.isSummary else {
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
        titleLabel.numberOfLines = 2
        titleLabel.textColor = .label

        var arrangedSubviews: [UIView] = [titleLabel]

        if !toilet.isSummary {
            let snippet = toilet.accessibilitySnippet
            if !snippet.isEmpty {
                let snippetLabel = UILabel()
                snippetLabel.text = snippet
                snippetLabel.font = .preferredFont(forTextStyle: .footnote)
                snippetLabel.textColor = .secondaryLabel
                snippetLabel.numberOfLines = 2
                arrangedSubviews.append(snippetLabel)
            }

            let detailsLabel = UILabel()
            detailsLabel.text = String(localized: "Details ansehen ›")
            detailsLabel.font = .preferredFont(forTextStyle: .footnote).withTraits(.traitBold) ?? .boldSystemFont(ofSize: 13)
            detailsLabel.textColor = .systemPurple
            arrangedSubviews.append(detailsLabel)
        }

        let textStack = UIStackView(arrangedSubviews: arrangedSubviews)
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
        if toilet.isSummary {
            accessibilityLabel = toilet.displayName
            accessibilityHint = String(localized: "Zusammenfassender Bereich mit mehreren Toiletten.")
            accessibilityTraits = .none
        } else {
            accessibilityLabel = "\(toilet.displayName). \(toilet.accessibilitySnippet)"
            accessibilityHint = String(localized: "Doppeltippen, um Details zu öffnen.")
            accessibilityTraits = .button
        }
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
        if isSummary { return "" }
        var parts = [String]()
        if temporaryClosed { parts.append(String(localized: "Temporary closed")) }
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

    var markerIcon: UIImage? {
        MarkerImageCache.markerIcon(for: self)
    }
}

private enum MarkerImageCache {
    private static let ciContext = CIContext(options: nil)
    private static var cache = [String: UIImage]()

    static func markerIcon(for toilet: Toilet) -> UIImage? {
        if toilet.isSummary {
            let count = max(1, toilet.summaryCount ?? 1)
            let key = "summary_\(count)"
            if let cached = cache[key] {
                return cached
            }
            if let summaryImg = createSummaryMarkerImage(count: count) {
                cache[key] = summaryImg
                return summaryImg
            }
        }

        let iconName = toilet.markerIconName
        let key = toilet.temporaryClosed ? "\(iconName)_gray" : iconName
        if let cached = cache[key] {
            return cached
        }

        guard let originalImage = UIImage(named: iconName) else {
            return nil
        }

        if toilet.temporaryClosed {
            if let grayImage = makeGray(image: originalImage) {
                cache[key] = grayImage
                return grayImage
            }
        }

        cache[key] = originalImage
        return originalImage
    }

    static var shiningOverlayImage: UIImage? {
        if let cached = cache["summary_shining_overlay"] {
            return cached
        }
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cgContext = ctx.cgContext
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            let colors: [CGColor] = [
                UIColor.systemPurple.withAlphaComponent(0.40).cgColor,
                UIColor.systemPurple.withAlphaComponent(0.24).cgColor,
                UIColor.systemPurple.withAlphaComponent(0.10).cgColor,
                UIColor.systemPurple.withAlphaComponent(0.0).cgColor
            ]
            let locations: [CGFloat] = [0.0, 0.35, 0.7, 1.0]

            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) {
                let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
                let radius = size.width / 2.0
                cgContext.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: radius,
                    options: .drawsAfterEndLocation
                )
            }
        }
        cache["summary_shining_overlay"] = image
        return image
    }

    private static func createSummaryMarkerImage(count: Int) -> UIImage? {
        let countText = "\(count)"
        let font = UIFont.systemFont(ofSize: 15, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let textSize = (countText as NSString).size(withAttributes: attributes)
        let height: CGFloat = 38.0
        let width = max(38.0, textSize.width + 18.0)
        let shadowPadding: CGFloat = 4.0
        let totalSize = CGSize(width: width + shadowPadding * 2.0, height: height + shadowPadding * 2.0)

        let renderer = UIGraphicsImageRenderer(size: totalSize)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext

            cgContext.saveGState()
            cgContext.setShadow(
                offset: CGSize(width: 0, height: 2),
                blur: 3.5,
                color: UIColor.black.withAlphaComponent(0.35).cgColor
            )

            let badgeRect = CGRect(x: shadowPadding, y: shadowPadding, width: width, height: height)
            let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: height / 2.0)

            UIColor.systemPurple.setFill()
            badgePath.fill()
            cgContext.restoreGState()

            UIColor.white.setStroke()
            badgePath.lineWidth = 2.5
            badgePath.stroke()

            let textRect = CGRect(
                x: badgeRect.origin.x + (badgeRect.width - textSize.width) / 2.0,
                y: badgeRect.origin.y + (badgeRect.height - textSize.height) / 2.0,
                width: textSize.width,
                height: textSize.height
            )
            (countText as NSString).draw(in: textRect, withAttributes: attributes)
        }
    }

    private static func makeGray(image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(0.0, forKey: kCIInputSaturationKey)
        guard let outputImage = filter?.outputImage,
              let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
