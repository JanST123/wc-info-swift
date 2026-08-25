import Foundation
import CoreLocation

struct Toilet: Identifiable, Codable {
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
    let openTimestamp: String?
    let closeTimestamp: String?
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
        case updated
    }
}

struct ToiletPhoto: Codable {
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
