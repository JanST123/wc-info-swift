import Foundation
import SwiftUI

struct ToiletFilterSettings: Equatable, Codable {
    var showClosed: Bool = false
    var showNonPublic: Bool = true
    var allowNonPublicFallback: Bool = true
    var maxPublicDistanceMeters: Int = 500
    var showNonWheelchairAccessible: Bool = true
    var showWithoutChangingTable: Bool = true
    var showWithoutGenderSeparation: Bool = true
    var showWithoutEuroKey: Bool = true

    static let `default` = ToiletFilterSettings()
    private static let userDefaultsKey = "wcinfo.filter_settings"

    var isDefault: Bool {
        self == .default
    }

    mutating func resetToDefaults() {
        self = .default
    }

    static func load() -> ToiletFilterSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(ToiletFilterSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }

    init(
        showClosed: Bool = false,
        showNonPublic: Bool = true,
        allowNonPublicFallback: Bool = true,
        maxPublicDistanceMeters: Int = 500,
        showNonWheelchairAccessible: Bool = true,
        showWithoutChangingTable: Bool = true,
        showWithoutGenderSeparation: Bool = true,
        showWithoutEuroKey: Bool = true
    ) {
        self.showClosed = showClosed
        self.showNonPublic = showNonPublic
        self.allowNonPublicFallback = allowNonPublicFallback
        self.maxPublicDistanceMeters = maxPublicDistanceMeters
        self.showNonWheelchairAccessible = showNonWheelchairAccessible
        self.showWithoutChangingTable = showWithoutChangingTable
        self.showWithoutGenderSeparation = showWithoutGenderSeparation
        self.showWithoutEuroKey = showWithoutEuroKey
    }

    init(url: URL) {
        self.init()
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }
        for item in queryItems {
            switch item.name {
            case "showClosed":
                if let val = item.value, let b = Bool(val) { showClosed = b }
            case "showNonPublic":
                if let val = item.value, let b = Bool(val) { showNonPublic = b }
            case "allowNonPublicFallback":
                if let val = item.value, let b = Bool(val) { allowNonPublicFallback = b }
            case "maxPublicDistanceMeters":
                if let val = item.value, let i = Int(val) { maxPublicDistanceMeters = i }
            case "showNonWheelchairAccessible":
                if let val = item.value, let b = Bool(val) { showNonWheelchairAccessible = b }
            case "showWithoutChangingTable":
                if let val = item.value, let b = Bool(val) { showWithoutChangingTable = b }
            case "showWithoutGenderSeparation":
                if let val = item.value, let b = Bool(val) { showWithoutGenderSeparation = b }
            case "showWithoutEuroKey":
                if let val = item.value, let b = Bool(val) { showWithoutEuroKey = b }
            default:
                break
            }
        }
    }

    func toURL() -> URL {
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

    var apiFilterQueryString: String? {
        var pairs: [String] = []

        if !showClosed {
            pairs.append("is_open:true")
        }
        if !showNonPublic {
            pairs.append("public_accessible:true")
        }
        if !showNonWheelchairAccessible {
            pairs.append("has_wheelchair_access:true")
        }
        if !showWithoutChangingTable {
            pairs.append("has_changing_table:true")
        }
        if !showWithoutGenderSeparation {
            pairs.append("is_gender_separated:true")
        }
        if !showWithoutEuroKey {
            pairs.append("euro_key:yes")
        }

        return pairs.isEmpty ? nil : pairs.joined(separator: ",")
    }

    var summaryText: AttributedString {
        var activeRestrictions: [String] = []

        if !showClosed {
            activeRestrictions.append("jetzt geöffnete")
        }
        if !showNonPublic {
            activeRestrictions.append("öffentliche")
        }
        if !showNonWheelchairAccessible {
            activeRestrictions.append("barrierefreie")
        }
        if !showWithoutChangingTable {
            activeRestrictions.append("mit Wickelraum")
        }
        if !showWithoutGenderSeparation {
            activeRestrictions.append("getrennte")
        }
        if !showWithoutEuroKey {
            activeRestrictions.append("mit Euroschlüssel")
        }

        if activeRestrictions.isEmpty {
            var string = AttributedString("Zeige ")
            var all = AttributedString("alle")
            all.inlinePresentationIntent = .stronglyEmphasized
            string.append(all)
            string.append(AttributedString(" Toiletten an."))
            return string
        } else {
            var string = AttributedString("Zeige nur ")
            var boldPart = AttributedString(activeRestrictions.joined(separator: ", "))
            boldPart.inlinePresentationIntent = .stronglyEmphasized
            string.append(boldPart)
            string.append(AttributedString(" Toiletten an."))
            return string
        }
    }
}
