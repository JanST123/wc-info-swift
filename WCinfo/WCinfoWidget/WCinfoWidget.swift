//
//  WCinfoWidget.swift
//  WCinfoWidget
//
//  Created by Jan on 23.09.26.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> UrgentToiletEntry {
        UrgentToiletEntry(date: Date(), configuration: UrgentToiletConfigurationIntent())
    }

    func snapshot(for configuration: UrgentToiletConfigurationIntent, in context: Context) async -> UrgentToiletEntry {
        UrgentToiletEntry(date: Date(), configuration: configuration)
    }

    func timeline(for configuration: UrgentToiletConfigurationIntent, in context: Context) async -> Timeline<UrgentToiletEntry> {
        let entry = UrgentToiletEntry(date: Date(), configuration: configuration)
        return Timeline(entries: [entry], policy: .never)
    }
}

struct UrgentToiletEntry: TimelineEntry {
    let date: Date
    let configuration: UrgentToiletConfigurationIntent
}

// MARK: - Urgent Person Pictogram View

struct UrgentPersonPictogramView: View {
    var size: CGFloat = 44
    var color: Color = .white

    var body: some View {
        ZStack {
            // Urgency Alert Glow
            Circle()
                .fill(Color.yellow.opacity(0.25))
                .frame(width: size * 1.35, height: size * 1.35)

            // Pictogram Person with Urgent Posture
            VStack(spacing: size * 0.05) {
                // Head
                Circle()
                    .fill(color)
                    .frame(width: size * 0.28, height: size * 0.28)

                // Torso with bent urgent posture
                RoundedRectangle(cornerRadius: size * 0.06)
                    .fill(color)
                    .frame(width: size * 0.26, height: size * 0.36)

                // Crossed legs (Urgent need representation)
                HStack(spacing: size * 0.02) {
                    // Left leg angled right
                    Capsule()
                        .fill(color)
                        .frame(width: size * 0.09, height: size * 0.38)
                        .rotationEffect(.degrees(18), anchor: .top)

                    // Right leg angled left (crossing)
                    Capsule()
                        .fill(color)
                        .frame(width: size * 0.09, height: size * 0.38)
                        .rotationEffect(.degrees(-18), anchor: .top)
                }
            }

            // Exclamation Warning Badge
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundColor(.yellow)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                .offset(x: size * 0.42, y: -size * 0.28)
        }
        .frame(width: size * 1.4, height: size * 1.4)
    }
}

// MARK: - Widget Views

struct WCinfoWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallWidgetView
            case .systemMedium:
                mediumWidgetView
            case .accessoryCircular:
                accessoryCircularView
            case .accessoryRectangular:
                accessoryRectangularView
            case .accessoryInline:
                accessoryInlineView
            default:
                smallWidgetView
            }
        }
        .widgetURL(entry.configuration.deepLinkURL)
    }

    // MARK: - Small Widget
    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Row: Emergency Badge
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 6, height: 6)
                    Text("NOTFALL")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.35))
                .clipShape(Capsule())

                Spacer()

                Text("WC")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Spacer(minLength: 0)

            // Center Pictogram
            HStack {
                Spacer()
                UrgentPersonPictogramView(size: 46, color: .white)
                Spacer()
            }

            Spacer(minLength: 0)

            // Bottom Actions & Title
            VStack(alignment: .leading, spacing: 1) {
                Text("Nächste Toilette")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 3) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("1-Tap Kompass")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(12)
    }

    // MARK: - Medium Widget
    private var mediumWidgetView: some View {
        HStack(spacing: 16) {
            // Left Pictogram Badge
            VStack {
                Spacer()
                UrgentPersonPictogramView(size: 52, color: .white)
                Spacer()
                Text("WC NOTFALL")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Capsule())
            }
            .frame(width: 80)

            // Right Information & CTA
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow)
                        Text("SOFORT-NAVIGATION")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Text("Nächste Toilette")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }

                // Filter Tags
                filterTagsView

                Spacer(minLength: 0)

                // Action Callout
                HStack(spacing: 6) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Tippen zum Navigieren")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
    }

    // Active filter chips for medium widget
    @ViewBuilder
    private var filterTagsView: some View {
        let tags = activeFilterTags
        if !tags.isEmpty {
            HStack(spacing: 4) {
                ForEach(tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                if tags.count > 2 {
                    Text("+\(tags.count - 2)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        } else {
            Text("Alle verfügbaren Toiletten")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var activeFilterTags: [String] {
        var tags: [String] = []
        if !entry.configuration.showClosed {
            tags.append("Geöffnet")
        }
        if !entry.configuration.showNonPublic {
            if entry.configuration.allowNonPublicFallback {
                tags.append("Öffentlich (>\(entry.configuration.maxPublicDistanceMeters)m Ausweich)")
            } else {
                tags.append("Nur Öffentlich")
            }
        }
        if !entry.configuration.showNonWheelchairAccessible {
            tags.append("Rollstuhlgerecht")
        }
        if !entry.configuration.showWithoutChangingTable {
            tags.append("Wickeltisch")
        }
        if !entry.configuration.showWithoutGenderSeparation {
            tags.append("Getrennt")
        }
        if !entry.configuration.showWithoutEuroKey {
            tags.append("Euroschlüssel")
        }
        return tags
    }

    // MARK: - Lock Screen Accessories
    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("WC")
                    .font(.system(size: 12, weight: .black, design: .rounded))
            }
        }
    }

    private var accessoryRectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text("Nächste Toilette")
                    .font(.system(size: 13, weight: .bold))
                Text("1-Tap Kompass-Start")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var accessoryInlineView: some View {
        Label("Nächste Toilette", systemImage: "exclamationmark.triangle.fill")
    }
}

// MARK: - Main Widget Definition

struct WCinfoWidget: Widget {
    let kind: String = "WCinfoWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: UrgentToiletConfigurationIntent.self, provider: Provider()) { entry in
            WCinfoWidgetEntryView(entry: entry)
                .containerBackground(
                    LinearGradient(
                        colors: [
                            Color(red: 0.88, green: 0.12, blue: 0.18),
                            Color(red: 0.65, green: 0.05, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    for: .widget
                )
        }
        .configurationDisplayName("Notfall-Toilette")
        .description("Finde und navigiere mit nur einem Fingertipp direkt per Kompass zur nächsten passenden Toilette.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    WCinfoWidget()
} timeline: {
    UrgentToiletEntry(date: .now, configuration: UrgentToiletConfigurationIntent())
}

#Preview(as: .systemMedium) {
    WCinfoWidget()
} timeline: {
    UrgentToiletEntry(date: .now, configuration: UrgentToiletConfigurationIntent())
}
