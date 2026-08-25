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
    let isOpen: Bool?
    let distance: Double?
    let photos: [ToiletPhoto]
    let openTimestamp: Date?
    let closeTimestamp: Date?
    let placeOpeningHours: String?
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
        case isOpen = "is_open"
        case distance, photos
        case openTimestamp = "open_timestamp"
        case closeTimestamp = "close_timestamp"
        case placeOpeningHours = "place_opening_hours"
        case updated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        owner = try container.decode(String.self, forKey: .owner)
        lat = try container.decode(Double.self, forKey: .lat)
        lon = try container.decode(Double.self, forKey: .lon)
        placeId = try container.decodeIfPresent(String.self, forKey: .placeId)
        status = try container.decode(String.self, forKey: .status)
        isQualified = try container.decode(Bool.self, forKey: .isQualified)
        isUnisex = try container.decode(Bool.self, forKey: .isUnisex)
        isGenderSeparated = try container.decode(Bool.self, forKey: .isGenderSeparated)
        hasWheelchairAccess = try container.decode(Bool.self, forKey: .hasWheelchairAccess)
        hasChangingTable = try container.decode(Bool.self, forKey: .hasChangingTable)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        isOpen = try container.decodeIfPresent(Bool.self, forKey: .isOpen)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        photos = (try? container.decode([ToiletPhoto].self, forKey: .photos)) ?? []
        openTimestamp = try container.decodeISO8601IfPresent(forKey: .openTimestamp)
        closeTimestamp = try container.decodeISO8601IfPresent(forKey: .closeTimestamp)
        placeOpeningHours = try container.decodeFlexibleStringIfPresent(forKey: .placeOpeningHours)
        updated = try container.decode(String.self, forKey: .updated)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKey key: K) throws -> String? {
        if let string = try decodeIfPresent(String.self, forKey: key), !string.isEmpty {
            return string
        }
        if let array = try decodeIfPresent([String].self, forKey: key), !array.isEmpty {
            return array.joined(separator: "\n")
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
