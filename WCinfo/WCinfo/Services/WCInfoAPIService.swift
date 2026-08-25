import Foundation
import CoreLocation

enum WCInfoAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse(statusCode: Int, message: String?)
    case decodingError(underlying: Error)
    case networkError(underlying: Error)

    var message: String? {
        switch self {
        case .invalidURL:
            return "Ungültige API-Adresse."
        case .invalidResponse(_, let message):
            return message
        case .decodingError:
            return "Die Server-Antwort konnte nicht verarbeitet werden."
        case .networkError(let underlying):
            return underlying.localizedDescription
        }
    }

    var errorDescription: String? {
        message
    }
}

actor WCInfoAPIService {
    static let shared = WCInfoAPIService()
    private let decoder: JSONDecoder

    private init() {
        decoder = JSONDecoder()
    }

    private var baseURL: String {
        #if targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        if let url = Config.apiBaseURL, !url.isEmpty {
            return url
        }
        return "https://api2.wc-info.de"
        #endif
    }

    func fetchToiletsNearby(latitude: Double, longitude: Double, distance: Int = 25) async throws -> [Toilet] {
        guard let url = URL(string: "\(baseURL)/toilets/nearby/\(latitude)/\(longitude)?distance=\(distance)") else {
            throw WCInfoAPIError.invalidURL
        }
        let data = try await performRequest(url: url)
        do {
            return try decoder.decode([Toilet].self, from: data)
        } catch {
            throw WCInfoAPIError.decodingError(underlying: error)
        }
    }

    func fetchToiletsInBounds(south: Double, west: Double, north: Double, east: Double) async throws -> [ToiletListItem] {
        guard let url = URL(string: "\(baseURL)/toilets/bounds/\(south)/\(west)/\(north)/\(east)") else {
            throw WCInfoAPIError.invalidURL
        }
        let data = try await performRequest(url: url)
        do {
            return try decoder.decode([ToiletListItem].self, from: data)
        } catch {
            throw WCInfoAPIError.decodingError(underlying: error)
        }
    }

    private func performRequest(url: URL) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw WCInfoAPIError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WCInfoAPIError.invalidResponse(statusCode: 0, message: nil)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data)
            throw WCInfoAPIError.invalidResponse(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = json["message"] as? String, !message.isEmpty {
                return message
            }
            if let messages = json["message"] as? [String], let first = messages.first, !first.isEmpty {
                return first
            }
        }
        return nil
    }
}
