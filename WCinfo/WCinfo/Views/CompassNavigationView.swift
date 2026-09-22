import SwiftUI
import CoreLocation
import MapKit

struct CompassNavigationView: View {
    @Environment(\.dismiss) private var dismiss
    let toilet: Toilet

    @StateObject private var compass: CompassManager

    init(toilet: Toilet) {
        self.toilet = toilet
        _compass = StateObject(wrappedValue: CompassManager(targetCoordinate: toilet.coordinate))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                toiletInfoCard

                Spacer(minLength: 10)

                compassView

                Spacer(minLength: 10)

                distanceCard

                Spacer(minLength: 10)

                openInMapsButton
            }
            .padding()
            .navigationTitle("Kompass-Navigation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                    .accessibilityLabel(Text("Kompass-Navigation schließen"))
                }
            }
            .onAppear {
                Analytics.shared.trackScreen("CompassNavigation")
                Analytics.shared.trackEvent(category: "compass_navigation", action: "start", name: toilet.name)
                compass.start()
            }
            .onDisappear {
                compass.stop()
            }
        }
    }

    // MARK: - Toilet Info Header

    private var toiletInfoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(toilet.name)
                    .font(.headline)
                    .lineLimit(2)

                if toilet.isQualified {
                    QualifiedBadgeView(iconSize: 16)
                }

                Spacer()
            }

            if !toilet.owner.isEmpty && toilet.owner != toilet.name {
                Text(toilet.owner)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let address = toilet.address, !address.isEmpty {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Ziel: \(toilet.name), \(toilet.owner)"))
    }

    // MARK: - Compass Dial & Needle

    private var compassView: some View {
        ZStack {
            // Outer glow when facing target
            Circle()
                .stroke(compass.isFacingTarget ? Color.purple.opacity(0.35) : Color.clear, lineWidth: 12)
                .frame(width: 260, height: 260)
                .animation(.easeInOut(duration: 0.3), value: compass.isFacingTarget)

            // Compass Dial Background
            Circle()
                .fill(Color(uiColor: .secondarySystemBackground))
                .frame(width: 240, height: 240)
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)

            // Dial ring with tick marks
            CompassDialTicksView()
                .frame(width: 230, height: 230)

            // Cardinal direction indicators rotating with device heading (North, East, South, West)
            CompassCardinalPointsView()
                .frame(width: 210, height: 210)
                .rotationEffect(.degrees(-compass.headingDegrees))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: compass.headingDegrees)

            // Compass Needle pointing towards the toilet
            CompassNeedleShapeView()
                .frame(width: 60, height: 180)
                .rotationEffect(.degrees(compass.accumulatedNeedleAngle))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: compass.accumulatedNeedleAngle)

            // Target arrival icon when within 10 meters
            if compass.hasArrived {
                Circle()
                    .fill(Color.green)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.title.bold())
                            .foregroundColor(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 270, height: 270)
        .accessibilityElement()
        .accessibilityLabel(Text("Kompassnadel zeigt in Richtung Toilette"))
        .accessibilityValue(accessibilityCompassValue)
    }

    // MARK: - Distance Display

    private var distanceCard: some View {
        VStack(spacing: 6) {
            if let meters = compass.distanceInMeters {
                if compass.hasArrived {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text("Ziel erreicht!")
                            .font(.title2.bold())
                            .foregroundColor(.green)
                    }
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(formatMetersValue(meters))
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)

                        Text("m")
                            .font(.title2.bold())
                            .foregroundColor(.secondary)
                    }

                    Text(compass.directionDescription)
                        .font(.headline)
                        .foregroundColor(compass.isFacingTarget ? .purple : .secondary)
                        .animation(.easeInOut(duration: 0.2), value: compass.isFacingTarget)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Standort wird ermittelt...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: - External Maps Button

    private var openInMapsButton: some View {
        Button(action: openExternalMaps) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                Text("In Karten-App öffnen")
            }
            .font(.subheadline.bold())
            .foregroundColor(.purple)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.purple.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel(Text("In Apple Maps oder Google Maps öffnen"))
        .accessibilityHint(Text("Startet die Routenführung in der externen Karten-App."))
    }

    // MARK: - Helpers

    private func formatMetersValue(_ meters: Double) -> String {
        let rounded = Int(meters.rounded())
        if rounded >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: rounded)) ?? "\(rounded)"
        }
        return "\(rounded)"
    }

    private var accessibilityCompassValue: String {
        if let meters = compass.distanceInMeters {
            if compass.hasArrived {
                return String(localized: "Ziel erreicht!")
            }
            let template = String(localized: "%lld Meter Entfernung, Richtung: %@")
            return String(format: template, Int64(meters.rounded()), compass.directionDescription)
        }
        return String(localized: "Standort wird ermittelt...")
    }

    private func openExternalMaps() {
        Analytics.shared.trackEvent(category: "compass_navigation", action: "open_external_maps", name: toilet.name)
        let coordinate = CLLocationCoordinate2D(latitude: toilet.lat, longitude: toilet.lon)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = toilet.name
        MKMapItem.openMaps(with: [mapItem], launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ])
    }
}

// MARK: - Compass Subviews

struct CompassDialTicksView: View {
    var body: some View {
        ZStack {
            ForEach(0..<24) { tick in
                Rectangle()
                    .fill(Color.secondary.opacity(tick % 6 == 0 ? 0.6 : 0.25))
                    .frame(width: tick % 6 == 0 ? 2 : 1, height: tick % 6 == 0 ? 10 : 6)
                    .offset(y: -105)
                    .rotationEffect(.degrees(Double(tick) * 15))
            }
        }
    }
}

struct CompassCardinalPointsView: View {
    var body: some View {
        ZStack {
            Text("N")
                .font(.caption.bold())
                .foregroundColor(.red)
                .offset(y: -85)

            Text("O")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .offset(x: 85)

            Text("S")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .offset(y: 85)

            Text("W")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .offset(x: -85)
        }
    }
}

struct CompassNeedleShapeView: View {
    var body: some View {
        ZStack {
            // Top needle (pointing to destination in vibrant purple gradient)
            Path { path in
                path.move(to: CGPoint(x: 30, y: 0))
                path.addLine(to: CGPoint(x: 42, y: 80))
                path.addLine(to: CGPoint(x: 30, y: 72))
                path.addLine(to: CGPoint(x: 18, y: 80))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color.purple, Color.indigo],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: Color.purple.opacity(0.4), radius: 6, x: 0, y: 2)

            // Bottom needle tail
            Path { path in
                path.move(to: CGPoint(x: 30, y: 160))
                path.addLine(to: CGPoint(x: 39, y: 95))
                path.addLine(to: CGPoint(x: 30, y: 103))
                path.addLine(to: CGPoint(x: 21, y: 95))
                path.closeSubpath()
            }
            .fill(Color(uiColor: .systemGray3))

            // Center Pin / Pivot
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(uiColor: .systemGray5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                .overlay {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 10, height: 10)
                }
        }
    }
}
