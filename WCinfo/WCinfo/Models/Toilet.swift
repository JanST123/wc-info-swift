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
    let storageSpace: String?
    let accessibleOutsideOpeningTimes: Bool
    let isPublicAccessible: Bool
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

    enum CodingKeys: String, CodingKey {
        case id, name, owner, lat, lon
        case placeId = "place_id"
        case status
        case isQualified = "is_qualified"
        case isUnisex = "is_unisex"
        case isGenderSeparated = "is_gender_separated"
        case hasWheelchairAccess = "has_wheelchair_access"
        case hasChangingTable = "has_changing_table"
        case source, address, website
        case storageSpace = "storage_space"
        case accessibleOutsideOpeningTimes = "accessible_outside_opening_times"
        case isPublicAccessible = "public_accessible"
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

        source = try container.decodeIfPresent(String.self, forKey: .source)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        website = try container.decodeIfPresent(String.self, forKey: .website)
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
            return "\(open.formattedDay) ab \(open.formattedTime)"
        }
    }
}

struct OpeningHoursTime: Codable, Hashable {
    let day: Int
    let time: String

    private static let dayNames = [
        "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"
    ]

    var formattedDay: String {
        guard (0...6).contains(day) else { return "?" }
        return Self.dayNames[day]
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

    enum CodingKeys: String, CodingKey {
        case url
        case urlThumb = "url_thumb"
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
    }
}

struct SearchedLocation: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D

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

    private static let dayNames = [
        "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"
    ]

    public var formattedDay: String {
        guard (0...6).contains(day) else { return "?" }
        return Self.dayNames[day]
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

    public var formatted: String {
        if let close {
            if open.day == close.day {
                return "\(open.formattedDay) \(open.formattedTime) – \(close.formattedTime)"
            } else {
                return "\(open.formattedDay) \(open.formattedTime) – \(close.formattedDay) \(close.formattedTime)"
            }
        } else {
            return "\(open.formattedDay) ab \(open.formattedTime)"
        }
    }
}

public struct PlaceResource: Codable, Hashable {
    public let id: String?
    public let displayName: DisplayNameText?
    public let location: PlaceLocation?
    public let formattedAddress: String?
    public let websiteUri: String?
    public let regularOpeningHours: RegularOpeningHours?
    public let types: [String]?

    public struct DisplayNameText: Codable, Hashable {
        public let text: String?
        public let languageCode: String?
    }

    public struct PlaceLocation: Codable, Hashable {
        public let latitude: Double?
        public let longitude: Double?
    }

    public struct RegularOpeningHours: Codable, Hashable {
        public let openNow: Bool?
        public let periods: [GooglePlacesPeriod]?
        public let weekdayDescriptions: [String]?
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
    public let filename: String
    public let deletedCount: Int
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
