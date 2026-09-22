//
//  AppIntent.swift
//  WCinfoWidget
//
//  Created by Jan on 23.09.26.
//

import WidgetKit
import AppIntents

struct UrgentToiletConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Notfall-Filter" }
    static var description: IntentDescription { "Passe an, welche Kriterien bei der schnellen Notfall-Navigation berücksichtigt werden sollen." }

    @Parameter(title: "Geschlossene Toiletten anzeigen", default: false)
    var showClosed: Bool

    @Parameter(title: "Nicht-öffentliche Toiletten anzeigen", default: true)
    var showNonPublic: Bool

    @Parameter(
        title: "Nähere geöffnete, nicht-öffentliche Toilette als Ausweichoption erlauben",
        description: "Navigiert zu einer näheren geöffneten nicht-öffentlichen Toilette, falls die nächste öffentliche weiter entfernt ist.",
        default: true
    )
    var allowNonPublicFallback: Bool

    @Parameter(
        title: "Max. Distanz zur öffentlichen Toilette (Meter)",
        description: "Ab welcher Distanz zur nächsten öffentlichen Toilette auf eine nähere geöffnete nicht-öffentliche ausgewichen wird.",
        default: 500
    )
    var maxPublicDistanceMeters: Int

    @Parameter(title: "Nicht-barrierefreie Toiletten anzeigen", default: true)
    var showNonWheelchairAccessible: Bool

    @Parameter(title: "Ohne Wickeltisch anzeigen", default: true)
    var showWithoutChangingTable: Bool

    @Parameter(title: "Ohne Geschlechtertrennung anzeigen", default: true)
    var showWithoutGenderSeparation: Bool

    @Parameter(title: "Ohne Euroschlüssel anzeigen", default: true)
    var showWithoutEuroKey: Bool

    static var parameterSummary: some ParameterSummary {
        When(\.$showNonPublic, .equalTo, false) {
            Summary("Nur öffentliche Toiletten mit Ausweichoption") {
                \.$showClosed
                \.$showNonPublic
                \.$allowNonPublicFallback
                \.$maxPublicDistanceMeters
                \.$showNonWheelchairAccessible
                \.$showWithoutChangingTable
                \.$showWithoutGenderSeparation
                \.$showWithoutEuroKey
            }
        } otherwise: {
            Summary("Alle Toiletten") {
                \.$showClosed
                \.$showNonPublic
                \.$showNonWheelchairAccessible
                \.$showWithoutChangingTable
                \.$showWithoutGenderSeparation
                \.$showWithoutEuroKey
            }
        }
    }

    var deepLinkURL: URL {
        var components = URLComponents()
        components.scheme = "wcinfo"
        components.host = "urgent-navigate"
        components.queryItems = [
            URLQueryItem(name: "showClosed", value: String(showClosed)),
            URLQueryItem(name: "showNonPublic", value: String(showNonPublic)),
            URLQueryItem(name: "allowNonPublicFallback", value: String(allowNonPublicFallback)),
            URLQueryItem(name: "maxPublicDistanceMeters", value: String(maxPublicDistanceMeters)),
            URLQueryItem(name: "showNonWheelchairAccessible", value: String(showNonWheelchairAccessible)),
            URLQueryItem(name: "showWithoutChangingTable", value: String(showWithoutChangingTable)),
            URLQueryItem(name: "showWithoutGenderSeparation", value: String(showWithoutGenderSeparation)),
            URLQueryItem(name: "showWithoutEuroKey", value: String(showWithoutEuroKey))
        ]
        return components.url ?? URL(string: "wcinfo://urgent-navigate")!
    }
}
