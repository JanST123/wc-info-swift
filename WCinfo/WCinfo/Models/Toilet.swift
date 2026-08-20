import Foundation
import CoreLocation

struct Toilet: Identifiable, Codable {
    let id: String
    let name: String
    let owner: String
    let lat: String
    let lon: String
    let placeId: String?
    let nr: String
    let type: String
    let isQualified: Bool
    let source: String?
    let address: String?
    let euroKey: String?
    let openingTimesJSON: String?
    let placeTypes: [String]?
    let photos: [ToiletPhoto]
    let openTimestamp: String?
    let closeTimestamp: String?
    let updated: String

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude = Double(lat), let longitude = Double(lon) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, owner, lat, lon
        case placeId = "place_id"
        case nr, type
        case isQualified = "is_qualified"
        case source, address
        case euroKey = "euro_key"
        case openingTimesJSON = "opening_times_json"
        case placeTypes = "place_types"
        case photos
        case openTimestamp = "open_timestamp"
        case closeTimestamp = "close_timestamp"
        case updated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeStringOrInt(forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        owner = try container.decode(String.self, forKey: .owner)
        lat = try container.decodeStringOrDouble(forKey: .lat)
        lon = try container.decodeStringOrDouble(forKey: .lon)
        placeId = try container.decodeIfPresent(String.self, forKey: .placeId)
        nr = try container.decodeStringOrInt(forKey: .nr)
        type = try container.decode(String.self, forKey: .type)
        isQualified = try container.decode(Bool.self, forKey: .isQualified)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        euroKey = try container.decodeIfPresent(String.self, forKey: .euroKey)
        openingTimesJSON = try container.decodeIfPresent(String.self, forKey: .openingTimesJSON)
        placeTypes = try container.decodeStringArrayIfPresent(forKey: .placeTypes)
        photos = try container.decode([ToiletPhoto].self, forKey: .photos)
        openTimestamp = try container.decodeIfPresent(String.self, forKey: .openTimestamp)
        closeTimestamp = try container.decodeIfPresent(String.self, forKey: .closeTimestamp)
        updated = try container.decode(String.self, forKey: .updated)
    }
}

private extension KeyedDecodingContainer {
    func decodeStringOrInt(forKey key: K) throws -> String {
        if let string = try? decode(String.self, forKey: key) { return string }
        if let int = try? decode(Int.self, forKey: key) { return String(int) }
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected String or Int for \(key)"))
    }

    func decodeStringOrDouble(forKey key: K) throws -> String {
        if let string = try? decode(String.self, forKey: key) { return string }
        if let double = try? decode(Double.self, forKey: key) { return String(double) }
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected String or Double for \(key)"))
    }

    func decodeStringArrayIfPresent(forKey key: K) throws -> [String]? {
        guard contains(key) else { return nil }
        if let array = try? decode([String].self, forKey: key) { return array }
        if let dict = try? decode([String: String].self, forKey: key) { return Array(dict.keys) }
        return nil
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
    let id: String
    let name: String?
    let owner: String?
    let lat: String
    let lon: String
    let placeId: String?
    let nr: String
    let type: String

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude = Double(lat), let longitude = Double(lon) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, owner, lat, lon
        case placeId = "place_id"
        case nr, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeStringOrInt(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        owner = try container.decodeIfPresent(String.self, forKey: .owner)
        lat = try container.decodeStringOrDouble(forKey: .lat)
        lon = try container.decodeStringOrDouble(forKey: .lon)
        placeId = try container.decodeIfPresent(String.self, forKey: .placeId)
        nr = try container.decodeStringOrInt(forKey: .nr)
        type = try container.decode(String.self, forKey: .type)
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
