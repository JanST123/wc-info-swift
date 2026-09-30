import Foundation
import CoreLocation

struct Toilet: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let owner: String
    let lat: Double
    let lon: Double
    let placeId: String?
    let status: String
    let isQualified: Bool
    let isUnisex: Bool
    let isGenderSeparated: Bool
    let hasWheelchairAccess: Bool
    let hasChangingTable: Bool
    let source: String?
    let address: String?
    let website: String?
    let comment: String?
    let euroKey: String?
    let storageSpace: String?
    let accessibleOutsideOpeningTimes: Bool
    let isPublicAccessible: Bool
    let temporaryClosed: Bool
    let isOpen: Bool?
    let distance: Double?
    let photos: [ToiletPhoto]
    let openTimestamp: Date?
    let closeTimestamp: Date?
    let placeOpeningHours: [GooglePlacesPeriod]?
    let updated: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var isOpen24HoursEveryDay: Bool {
        placeOpeningHours?.isOpen24HoursEveryDay ?? false
    }

    enum CodingKeys: String, CodingKey {
        case id, name, owner, lat, lon
        case placeId = "place_id"
        case status
        case isQualified = "is_qualified"
        case isUnisex = "is_unisex"
        case isGenderSeparated = "is_gender_separated"
        case hasWheelchairAccess = "has_wheelchair_access"
        case hasChangingTable = "has_changing_table"
        case source, address, website, comment
        case euroKey = "euro_key"
        case storageSpace = "storage_space"
        case accessibleOutsideOpeningTimes = "accessible_outside_opening_times"
        case isPublicAccessible = "public_accessible"
        case temporaryClosed = "temporary_closed"
        case isOpen = "is_open"
        case distance, photos
        case openTimestamp = "open_timestamp"
        case closeTimestamp = "close_timestamp"
        case placeOpeningHours = "place_opening_hours"
        case updated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = intId
        } else if let strId = try? container.decode(String.self, forKey: .id), let intVal = Int(strId) {
            id = intVal
        } else {
            id = try container.decode(Int.self, forKey: .id)
        }

        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        owner = (try? container.decode(String.self, forKey: .owner)) ?? ""

        if let dLat = try? container.decode(Double.self, forKey: .lat) {
            lat = dLat
        } else if let strLat = try? container.decode(String.self, forKey: .lat), let dVal = Double(strLat) {
            lat = dVal
        } else {
            lat = try container.decode(Double.self, forKey: .lat)
        }

        if let dLon = try? container.decode(Double.self, forKey: .lon) {
            lon = dLon
        } else if let strLon = try? container.decode(String.self, forKey: .lon), let dVal = Double(strLon) {
            lon = dVal
        } else {
            lon = try container.decode(Double.self, forKey: .lon)
        }

        placeId = try container.decodeIfPresent(String.self, forKey: .placeId)
        status = (try? container.decode(String.self, forKey: .status)) ?? "active"
        isQualified = container.decodeFlexibleBool(forKey: .isQualified)

        isUnisex = container.decodeFlexibleBool(forKey: .isUnisex)
        isGenderSeparated = container.decodeFlexibleBool(forKey: .isGenderSeparated)
        hasWheelchairAccess = container.decodeFlexibleBool(forKey: .hasWheelchairAccess)
        hasChangingTable = container.decodeFlexibleBool(forKey: .hasChangingTable)
        accessibleOutsideOpeningTimes = container.decodeFlexibleBool(forKey: .accessibleOutsideOpeningTimes)
        isPublicAccessible = container.decodeFlexibleBool(forKey: .isPublicAccessible)
        temporaryClosed = container.decodeFlexibleBool(forKey: .temporaryClosed)

        source = try container.decodeIfPresent(String.self, forKey: .source)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        euroKey = try container.decodeIfPresent(String.self, forKey: .euroKey)
        storageSpace = try container.decodeIfPresent(String.self, forKey: .storageSpace)
        isOpen = container.decodeFlexibleBoolIfPresent(forKey: .isOpen)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        photos = (try? container.decode([ToiletPhoto].self, forKey: .photos)) ?? []
        openTimestamp = try container.decodeISO8601IfPresent(forKey: .openTimestamp)
        closeTimestamp = try container.decodeISO8601IfPresent(forKey: .closeTimestamp)

        if let gPeriods = try? container.decode([GooglePlacesPeriod].self, forKey: .placeOpeningHours) {
            placeOpeningHours = gPeriods
        } else if let legacyPeriods = try? container.decode([OpeningHoursPeriod].self, forKey: .placeOpeningHours) {
            placeOpeningHours = legacyPeriods.map { legacy in
                let openPoint = GooglePlacesPoint(day: legacy.open.day, hour: legacy.open.hourValue, minute: legacy.open.minuteValue)
                let closePoint = legacy.close.map { GooglePlacesPoint(day: $0.day, hour: $0.hourValue, minute: $0.minuteValue) }
                return GooglePlacesPeriod(open: openPoint, close: closePoint)
            }
        } else {
            placeOpeningHours = nil
        }

        updated = (try? container.decode(String.self, forKey: .updated)) ?? ""
    }
}

struct OpeningHoursPeriod: Codable, Hashable {
    let close: OpeningHoursTime?
    let open: OpeningHoursTime

    var formatted: String {
        if let close {
            return "\(open.formattedDay) \(open.formattedTime) – \(close.formattedTime)"
        } else {
            let fromTemplate = String(localized: "%@ ab %@")
            return String(format: fromTemplate, open.formattedDay, open.formattedTime)
        }
    }
}

struct OpeningHoursTime: Codable, Hashable {
    let day: Int
    let time: String

    var formattedDay: String {
        guard (0...6).contains(day) else { return "?" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return symbols[day]
    }

    var formattedTime: String {
        guard time.count == 4 else { return time }
        let hour = time.prefix(2)
        let minute = time.suffix(2)
        return "\(hour):\(minute)"
    }

    var hourValue: Int {
        guard time.count == 4, let h = Int(time.prefix(2)) else { return 0 }
        return h
    }

    var minuteValue: Int {
        guard time.count == 4, let m = Int(time.suffix(2)) else { return 0 }
        return m
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleBool(forKey key: K) -> Bool {
        if let boolVal = try? decode(Bool.self, forKey: key) {
            return boolVal
        }
        if let strVal = try? decode(String.self, forKey: key) {
            return strVal == "1" || strVal.lowercased() == "true"
        }
        if let intVal = try? decode(Int.self, forKey: key) {
            return intVal == 1
        }
        return false
    }

    func decodeFlexibleBoolIfPresent(forKey key: K) -> Bool? {
        if let boolVal = try? decodeIfPresent(Bool.self, forKey: key) {
            return boolVal
        }
        if let strVal = try? decodeIfPresent(String.self, forKey: key) {
            return strVal == "1" || strVal.lowercased() == "true"
        }
        if let intVal = try? decodeIfPresent(Int.self, forKey: key) {
            return intVal == 1
        }
        return nil
    }

    func decodeISO8601IfPresent(forKey key: K) throws -> Date? {
        guard let string = try decodeIfPresent(String.self, forKey: key), !string.isEmpty else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

struct ToiletPhoto: Codable, Hashable {
    let url: String
    let urlThumb: String
    var filename: String? = nil

    enum CodingKeys: String, CodingKey {
        case url
        case urlThumb = "url_thumb"
        case filename
    }

    var resolvedFilename: String {
        if let filename, !filename.isEmpty {
            return filename
        }
        if let urlObj = URL(string: url) {
            return urlObj.lastPathComponent
        }
        return ""
    }
}

struct ToiletListItem: Identifiable, Codable {
    let id: Int
    let name: String?
    let owner: String?
    let lat: Double
    let lon: Double
    let placeId: String?
    let status: String
    let isUnisex: Bool
    let isGenderSeparated: Bool
    let hasWheelchairAccess: Bool
    let hasChangingTable: Bool
    let website: String?
    let comment: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, owner, lat, lon
        case placeId = "place_id"
        case status
        case isUnisex = "is_unisex"
        case isGenderSeparated = "is_gender_separated"
        case hasWheelchairAccess = "has_wheelchair_access"
        case hasChangingTable = "has_changing_table"
        case website, comment
    }
}

struct SearchedLocation: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    var initialToiletId: Int? = nil

    init(name: String, coordinate: CLLocationCoordinate2D, initialToiletId: Int? = nil) {
        self.name = name
        self.coordinate = coordinate
        self.initialToiletId = initialToiletId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SearchedLocation, rhs: SearchedLocation) -> Bool {
        lhs.id == rhs.id
    }
}

public struct GooglePlacesPoint: Codable, Hashable, Equatable {
    public var day: Int       // 0: Sunday, 1: Monday, ..., 6: Saturday
    public var hour: Int      // 0..23
    public var minute: Int    // 0..59

    public init(day: Int, hour: Int, minute: Int) {
        self.day = day
        self.hour = hour
        self.minute = minute
    }

    enum CodingKeys: String, CodingKey {
        case day, hour, minute
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let d = try? container.decode(Int.self, forKey: .day) {
            day = d
        } else if let s = try? container.decode(String.self, forKey: .day), let d = Int(s) {
            day = d
        } else {
            day = (try? container.decode(Int.self, forKey: .day)) ?? 0
        }

        if let h = try? container.decode(Int.self, forKey: .hour) {
            hour = h
        } else if let s = try? container.decode(String.self, forKey: .hour), let h = Int(s) {
            hour = h
        } else {
            hour = 0
        }

        if let m = try? container.decode(Int.self, forKey: .minute) {
            minute = m
        } else if let s = try? container.decode(String.self, forKey: .minute), let m = Int(s) {
            minute = m
        } else {
            minute = 0
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(hour, forKey: .hour)
        try container.encode(minute, forKey: .minute)
    }

    public var formattedDay: String {
        guard (0...6).contains(day) else { return "?" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return symbols[day]
    }

    public var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

public struct GooglePlacesPeriod: Codable, Hashable, Equatable {
    public var `open`: GooglePlacesPoint
    public var close: GooglePlacesPoint?

    public init(open: GooglePlacesPoint, close: GooglePlacesPoint? = nil) {
        self.open = open
        self.close = close
    }

    public var is24Hours: Bool {
        guard open.hour == 0, open.minute == 0 else { return false }
        if let close = close {
            return (close.hour == 0 && close.minute == 0) ||
                   (close.hour == 24 && close.minute == 0) ||
                   (close.hour == 23 && close.minute >= 59)
        }
        return true
    }

    public var formatted: String {
        if is24Hours {
            let open24Template = String(localized: "%@ 24 Stunden geöffnet")
            return String(format: open24Template, open.formattedDay)
        } else if let close {
            if open.day == close.day {
                return "\(open.formattedDay) \(open.formattedTime) – \(close.formattedTime)"
            } else {
                return "\(open.formattedDay) \(open.formattedTime) – \(close.formattedDay) \(close.formattedTime)"
            }
        } else {
            let fromTemplate = String(localized: "%@ ab %@")
            return String(format: fromTemplate, open.formattedDay, open.formattedTime)
        }
    }
}

extension Collection where Element == GooglePlacesPeriod {
    public var isOpen24HoursEveryDay: Bool {
        guard !isEmpty else { return false }

        // Google Places API: a single period with no close event indicates open 24/7
        if count == 1, let first = first, first.is24Hours {
            return true
        }

        // Check if all 7 days (0..6) are present and each day is open 24 hours
        let days = Set(map { $0.open.day })
        if days == Set(0...6) && allSatisfy({ $0.is24Hours }) {
            return true
        }

        return false
    }
}

public struct NearestPlacesResponse: Codable {
    public let status: String?
    public let places: [PlaceResource]

    public init(status: String? = nil, places: [PlaceResource]) {
        self.status = status
        self.places = places
    }
}

public struct PlaceResource: Codable, Hashable {
    public let id: String?
    public let displayName: DisplayNameText?
    public let name: String?
    public let location: PlaceLocation?
    public let formattedAddress: String?
    public let websiteUri: String?
    public let regularOpeningHours: RegularOpeningHours?
    public let types: [String]?

    public struct DisplayNameText: Codable, Hashable {
        public let text: String?
        public let languageCode: String?

        public init(text: String?, languageCode: String? = nil) {
            self.text = text
            self.languageCode = languageCode
        }

        enum CodingKeys: String, CodingKey {
            case text
            case languageCode
        }

        public init(from decoder: Decoder) throws {
            if let singleValueContainer = try? decoder.singleValueContainer(),
               let stringValue = try? singleValueContainer.decode(String.self) {
                self.text = stringValue
                self.languageCode = nil
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.text = try container.decodeIfPresent(String.self, forKey: .text)
            self.languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(text, forKey: .text)
            try container.encodeIfPresent(languageCode, forKey: .languageCode)
        }
    }

    public struct PlaceLocation: Codable, Hashable {
        public let latitude: Double?
        public let longitude: Double?

        public init(latitude: Double?, longitude: Double?) {
            self.latitude = latitude
            self.longitude = longitude
        }

        enum CodingKeys: String, CodingKey {
            case latitude, longitude, lat, lng, lon
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let parsedLat = (try? container.decodeIfPresent(Double.self, forKey: .latitude))
                ?? (try? container.decodeIfPresent(Double.self, forKey: .lat))
            let parsedLon = (try? container.decodeIfPresent(Double.self, forKey: .longitude))
                ?? (try? container.decodeIfPresent(Double.self, forKey: .lng))
                ?? (try? container.decodeIfPresent(Double.self, forKey: .lon))
            self.latitude = parsedLat
            self.longitude = parsedLon
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(latitude, forKey: .latitude)
            try container.encodeIfPresent(longitude, forKey: .longitude)
        }
    }

    public struct RegularOpeningHours: Codable, Hashable {
        public let openNow: Bool?
        public let periods: [GooglePlacesPeriod]?
        public let weekdayDescriptions: [String]?

        public init(openNow: Bool? = nil, periods: [GooglePlacesPeriod]? = nil, weekdayDescriptions: [String]? = nil) {
            self.openNow = openNow
            self.periods = periods
            self.weekdayDescriptions = weekdayDescriptions
        }

        enum CodingKeys: String, CodingKey {
            case openNow, periods, weekdayDescriptions
        }

        public init(from decoder: Decoder) throws {
            if let arrayContainer = try? decoder.singleValueContainer(),
               let periodsArray = try? arrayContainer.decode([GooglePlacesPeriod].self) {
                self.openNow = nil
                self.periods = periodsArray
                self.weekdayDescriptions = nil
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.openNow = try container.decodeIfPresent(Bool.self, forKey: .openNow)
            self.periods = try container.decodeIfPresent([GooglePlacesPeriod].self, forKey: .periods)
            self.weekdayDescriptions = try container.decodeIfPresent([String].self, forKey: .weekdayDescriptions)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(openNow, forKey: .openNow)
            try container.encodeIfPresent(periods, forKey: .periods)
            try container.encodeIfPresent(weekdayDescriptions, forKey: .weekdayDescriptions)
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case placeId = "place_id"
        case displayName
        case name
        case location
        case geometry
        case formattedAddress
        case formatted_address
        case address
        case websiteUri
        case website
        case regularOpeningHours
        case openingHours = "opening_hours"
        case placeOpeningHours = "place_opening_hours"
        case types
    }

    private struct GeometryContainer: Codable {
        let location: PlaceLocation?
    }

    public init(
        id: String? = nil,
        displayName: DisplayNameText? = nil,
        name: String? = nil,
        location: PlaceLocation? = nil,
        formattedAddress: String? = nil,
        websiteUri: String? = nil,
        regularOpeningHours: RegularOpeningHours? = nil,
        types: [String]? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.name = name
        self.location = location
        self.formattedAddress = formattedAddress
        self.websiteUri = websiteUri
        self.regularOpeningHours = regularOpeningHours
        self.types = types
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = (try? container.decodeIfPresent(String.self, forKey: .id))
            ?? (try? container.decodeIfPresent(String.self, forKey: .placeId))

        self.displayName = try? container.decodeIfPresent(DisplayNameText.self, forKey: .displayName)
        self.name = try? container.decodeIfPresent(String.self, forKey: .name)

        if let loc = try? container.decodeIfPresent(PlaceLocation.self, forKey: .location) {
            self.location = loc
        } else if let geom = try? container.decodeIfPresent(GeometryContainer.self, forKey: .geometry) {
            self.location = geom.location
        } else {
            self.location = nil
        }

        self.formattedAddress = (try? container.decodeIfPresent(String.self, forKey: .formattedAddress))
            ?? (try? container.decodeIfPresent(String.self, forKey: .formatted_address))
            ?? (try? container.decodeIfPresent(String.self, forKey: .address))

        self.websiteUri = (try? container.decodeIfPresent(String.self, forKey: .websiteUri))
            ?? (try? container.decodeIfPresent(String.self, forKey: .website))

        if let hours = try? container.decodeIfPresent(RegularOpeningHours.self, forKey: .regularOpeningHours) {
            self.regularOpeningHours = hours
        } else if let hours = try? container.decodeIfPresent(RegularOpeningHours.self, forKey: .openingHours) {
            self.regularOpeningHours = hours
        } else if let periods = try? container.decodeIfPresent([GooglePlacesPeriod].self, forKey: .placeOpeningHours) {
            self.regularOpeningHours = RegularOpeningHours(periods: periods)
        } else {
            self.regularOpeningHours = nil
        }

        self.types = try? container.decodeIfPresent([String].self, forKey: .types)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(formattedAddress, forKey: .formattedAddress)
        try container.encodeIfPresent(websiteUri, forKey: .websiteUri)
        try container.encodeIfPresent(regularOpeningHours, forKey: .regularOpeningHours)
        try container.encodeIfPresent(types, forKey: .types)
    }

    public var resolvedPlaceId: String? {
        id
    }

    public var resolvedName: String? {
        if let text = displayName?.text, !text.isEmpty {
            return text
        }
        if let n = name, !n.isEmpty {
            if n.hasPrefix("places/") {
                return nil
            }
            return n
        }
        return nil
    }

    public var resolvedAddress: String? {
        formattedAddress
    }

    public var resolvedWebsite: String? {
        websiteUri
    }

    public var resolvedCoordinate: CLLocationCoordinate2D? {
        if let loc = location, let lat = loc.latitude, let lon = loc.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }

    public var resolvedOpeningHours: [GooglePlacesPeriod]? {
        regularOpeningHours?.periods
    }

    func toNearbyPlaceOption() -> NearbyPlaceOption? {
        guard let placeId = resolvedPlaceId, let name = resolvedName, !name.isEmpty else { return nil }
        return NearbyPlaceOption(id: placeId, name: name, secondaryText: resolvedAddress)
    }

    func toPlaceDetails() -> PlaceDetails? {
        guard let placeId = resolvedPlaceId else { return nil }
        return PlaceDetails(
            placeID: placeId,
            name: resolvedName,
            formattedAddress: resolvedAddress,
            website: resolvedWebsite,
            coordinate: resolvedCoordinate,
            openingHours: resolvedOpeningHours
        )
    }
}

public struct ToiletPropertyItem: Codable, Hashable {
    public let type: String
    public let value: String

    public init(type: String, value: String) {
        self.type = type
        self.value = value
    }

    public init(type: ToiletPropertyType, value: String) {
        self.type = type.rawValue
        self.value = value
    }

    public static func openingHours(_ periods: [GooglePlacesPeriod]) -> ToiletPropertyItem? {
        guard let data = try? JSONEncoder().encode(periods),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return ToiletPropertyItem(type: .placeOpeningHours, value: jsonString)
    }
}

public enum ToiletPropertyType: String, Codable {
    case placeOpeningHours = "place_opening_hours"
    case website
    case address
    case euroKey = "euro_key"
    case storageSpace = "storage_space"
    case accessibleOutsideOpeningTimes = "accessible_outside_opening_times"
    case publicAccessible = "public_accessible"
    case temporaryClosed = "temporary_closed"
    case comment
    case isUnisex = "is_unisex"
    case isGenderSeparated = "is_gender_separated"
    case hasWheelchairAccess = "has_wheelchair_access"
    case hasChangingTable = "has_changing_table"
}

public struct AddToiletPropertiesResponse: Codable {
    public let success: Bool
    public let count: Int
}

public struct UploadPhotoResponse: Codable {
    public let success: Bool
    public let hasGeo: Bool?
    public let placeId: String?
    public let imageUrl: String
    public let filename: String
    public let toiletId: Int

    enum CodingKeys: String, CodingKey {
        case success
        case hasGeo = "hasGeo"
        case placeId = "placeId"
        case imageUrl = "imageUrl"
        case filename
        case toiletId = "toiletId"
    }
}

public struct DeletePhotoResponse: Codable {
    public let success: Bool
}

struct AddToiletPayload: Codable {
    var name: String?
    var owner: String?
    var lat: Double?
    var lon: Double?
    var placeId: String?
    var isUnisex: Bool?
    var isGenderSeparated: Bool?
    var hasWheelchairAccess: Bool?
    var hasChangingTable: Bool?
    var accessibleOutsideOpeningTimes: Bool?
    var publicAccessible: Bool?
    var temporaryClosed: Bool?
    var placeOpeningHours: [GooglePlacesPeriod]?
    var address: String?
    var website: String?
    var comment: String?
    var euroKey: String?
    var storageSpace: String?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case name, owner, lat, lon
        case placeId = "place_id"
        case isUnisex = "is_unisex"
        case isGenderSeparated = "is_gender_separated"
        case hasWheelchairAccess = "has_wheelchair_access"
        case hasChangingTable = "has_changing_table"
        case accessibleOutsideOpeningTimes = "accessible_outside_opening_times"
        case publicAccessible = "public_accessible"
        case temporaryClosed = "temporary_closed"
        case placeOpeningHours = "place_opening_hours"
        case address, website, comment
        case euroKey = "euro_key"
        case storageSpace = "storage_space"
        case status
    }
}

struct AddToiletResponse: Codable {
    let success: Bool
    let id: Int
}

struct UpdateToiletPayload: Codable {
    var name: String?
    var owner: String?
    var lat: Double?
    var lon: Double?
    var placeId: String?
    var isQualified: Bool?
    var isUnisex: Bool?
    var isGenderSeparated: Bool?
    var hasWheelchairAccess: Bool?
    var hasChangingTable: Bool?
    var accessibleOutsideOpeningTimes: Bool?
    var publicAccessible: Bool?
    var temporaryClosed: Bool?
    var placeOpeningHours: [GooglePlacesPeriod]?
    var address: String?
    var website: String?
    var comment: String?
    var euroKey: String?
    var storageSpace: String?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case name, owner, lat, lon
        case placeId = "place_id"
        case isQualified = "is_qualified"
        case isUnisex = "is_unisex"
        case isGenderSeparated = "is_gender_separated"
        case hasWheelchairAccess = "has_wheelchair_access"
        case hasChangingTable = "has_changing_table"
        case accessibleOutsideOpeningTimes = "accessible_outside_opening_times"
        case publicAccessible = "public_accessible"
        case temporaryClosed = "temporary_closed"
        case placeOpeningHours = "place_opening_hours"
        case address, website, comment
        case euroKey = "euro_key"
        case storageSpace = "storage_space"
        case status
    }
}

struct UpdateToiletResponse: Codable {
    let success: Bool
    let id: Int
    //let diff: String?
}

public struct SendToiletFeedbackRequest: Codable {
    public let subject: String
    public let message: String?

    public init(subject: String, message: String? = nil) {
        self.subject = subject
        self.message = message
    }
}

public struct SendToiletFeedbackResponse: Codable {
    public let status: String
    public let message: String

    public init(status: String, message: String) {
        self.status = status
        self.message = message
    }
}

struct NearbyPlaceOption: Identifiable, Hashable {
    let id: String // placeID
    let name: String
    let secondaryText: String?
}

struct PlaceDetails: Hashable {
    let placeID: String
    let name: String?
    let formattedAddress: String?
    let website: String?
    let coordinate: CLLocationCoordinate2D?
    let openingHours: [GooglePlacesPeriod]?

    init(
        placeID: String,
        name: String?,
        formattedAddress: String?,
        website: String?,
        coordinate: CLLocationCoordinate2D?,
        openingHours: [GooglePlacesPeriod]? = nil
    ) {
        self.placeID = placeID
        self.name = name
        self.formattedAddress = formattedAddress
        self.website = website
        self.coordinate = coordinate
        self.openingHours = openingHours
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(placeID)
    }

    static func == (lhs: PlaceDetails, rhs: PlaceDetails) -> Bool {
        lhs.placeID == rhs.placeID
    }
}

// MARK: - URL Slug and Sharing

extension String {
    func toURLSlug() -> String {
        var text = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        let replacements: [(String, String)] = [
            ("ä", "ae"), ("ö", "oe"), ("ü", "ue"),
            ("Ä", "Ae"), ("Ö", "Oe"), ("Ü", "Ue"),
            ("ß", "ss")
        ]
        for (target, replacement) in replacements {
            text = text.replacingOccurrences(of: target, with: replacement)
        }

        if let transformed = text.applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) {
            text = transformed
        }

        var result = ""
        var lastWasHyphen = false

        for scalar in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.append(Character(scalar))
                lastWasHyphen = false
            } else if !lastWasHyphen {
                result.append("-")
                lastWasHyphen = true
            }
        }

        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

extension Toilet {
    var shareURL: URL {
        let placeSegment: String
        if let placeId = placeId?.trimmingCharacters(in: .whitespacesAndNewlines), !placeId.isEmpty {
            let placeName = owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? name : owner
            let placeSlug = placeName.toURLSlug()
            let finalPlaceSlug = placeSlug.isEmpty ? "Nearby" : placeSlug
            placeSegment = "\(finalPlaceSlug)---\(placeId)"
        } else {
            placeSegment = "Nearby---NEARBY"
        }

        let toiletNameOrOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? name : owner
        let toiletSlug = toiletNameOrOwner.toURLSlug()
        let finalToiletSlug = toiletSlug.isEmpty ? "toilet" : toiletSlug
        let toiletSegment = "\(finalToiletSlug)---\(id)"

        let urlString = "https://wc-info.org/Toilets/\(placeSegment)/\(toiletSegment)"
        return URL(string: urlString) ?? URL(string: "https://wc-info.org")!
    }
}
