import Foundation
import CoreLocation

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
}

actor WCInfoAPIService {
    static let shared = WCInfoAPIService()
    private let baseURL = "https://api2.wc-info.de"
    private let decoder: JSONDecoder

    private init() {
        decoder = JSONDecoder()
    }

    func fetchToiletsNearby(latitude: Double, longitude: Double, distance: Int = 25) async throws -> [Toilet] {
        let urlString = "\(baseURL)/toilets/nearby/\(latitude)/\(longitude)?distance=\(distance)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        do {
            return try decoder.decode([Toilet].self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }

    func fetchToiletsInBounds(south: Double, west: Double, north: Double, east: Double) async throws -> [ToiletListItem] {
        let urlString = "\(baseURL)/toilets/bounds/\(south)/\(west)/\(north)/\(east)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        do {
            return try decoder.decode([ToiletListItem].self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
}
