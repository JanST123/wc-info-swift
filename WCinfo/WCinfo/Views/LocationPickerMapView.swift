import SwiftUI
import GoogleMaps
import CoreLocation

struct LocationPickerMapView: View {
    @Environment(\.colorScheme) private var colorScheme
    let initialCoordinate: CLLocationCoordinate2D
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    var onConfirmCoordinate: ((CLLocationCoordinate2D) -> Void)? = nil

    @State private var currentMarkerCoordinate: CLLocationCoordinate2D

    init(
        initialCoordinate: CLLocationCoordinate2D,
        selectedCoordinate: Binding<CLLocationCoordinate2D?>,
        onConfirmCoordinate: ((CLLocationCoordinate2D) -> Void)? = nil
    ) {
        self.initialCoordinate = initialCoordinate
        self._selectedCoordinate = selectedCoordinate
        self.onConfirmCoordinate = onConfirmCoordinate
        self._currentMarkerCoordinate = State(initialValue: selectedCoordinate.wrappedValue ?? initialCoordinate)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                LocationPickerGMSView(
                    center: initialCoordinate,
                    selectedCoordinate: $currentMarkerCoordinate,
                    colorScheme: colorScheme
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Bottom selection bar
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.purple)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ausgewählte Position")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Text(String(format: "Lat: %.5f, Lon: %.5f", currentMarkerCoordinate.latitude, currentMarkerCoordinate.longitude))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                        }

                        Spacer()
                    }

                    Button {
                        selectedCoordinate = currentMarkerCoordinate
                        onConfirmCoordinate?(currentMarkerCoordinate)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Diese Position wählen")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel("Diese Position wählen")
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(12)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
        }
    }
}

private struct LocationPickerGMSView: UIViewRepresentable {
    let center: CLLocationCoordinate2D
    @Binding var selectedCoordinate: CLLocationCoordinate2D
    let colorScheme: ColorScheme

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withLatitude: selectedCoordinate.latitude,
            longitude: selectedCoordinate.longitude,
            zoom: 16
        )
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.settings.myLocationButton = true
        mapView.settings.compassButton = true
        mapView.delegate = context.coordinator
        mapView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light

        let marker = GMSMarker(position: selectedCoordinate)
        marker.isDraggable = true
        marker.title = "Toilette Standort"
        marker.snippet = "Tippe oder ziehe, um den Standort anzupassen"
        marker.map = mapView
        context.coordinator.marker = marker

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let targetStyle: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        if mapView.overrideUserInterfaceStyle != targetStyle {
            mapView.overrideUserInterfaceStyle = targetStyle
        }

        if let marker = context.coordinator.marker {
            if abs(marker.position.latitude - selectedCoordinate.latitude) > 0.00001 ||
               abs(marker.position.longitude - selectedCoordinate.longitude) > 0.00001 {
                marker.position = selectedCoordinate
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: LocationPickerGMSView
        var marker: GMSMarker?

        init(_ parent: LocationPickerGMSView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            parent.selectedCoordinate = coordinate
            marker?.position = coordinate
            marker?.map = mapView
        }

        func mapView(_ mapView: GMSMapView, didEndDragging marker: GMSMarker) {
            parent.selectedCoordinate = marker.position
        }
    }
}
