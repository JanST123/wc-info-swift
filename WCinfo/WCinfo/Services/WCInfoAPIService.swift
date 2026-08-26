import Foundation
import CoreLocation
import Sentry

enum WCInfoAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse(statusCode: Int, message: String?, responseBody: String?)
    case decodingError(underlying: Error, responseBody: String?)
    case networkError(underlying: Error)

    var diagnosticContext: [String: Any] {
        switch self {
        case .invalidURL:
            return ["errorType": "invalidURL"]
        case .invalidResponse(let statusCode, let message, let responseBody):
            var context: [String: Any] = ["errorType": "invalidResponse", "statusCode": statusCode, "message": message ?? "nil"]
            if let responseBody { context["responseBody"] = responseBody }
            return context
        case .decodingError(let underlying, let responseBody):
            var context: [String: Any] = ["errorType": "decodingError", "underlying": String(describing: underlying)]
            if let responseBody { context["responseBody"] = responseBody }
            return context
        case .networkError(let underlying):
            return ["errorType": "networkError", "underlying": String(describing: underlying)]
        }
    }

    var message: String? {
        switch self {
        case .invalidURL:
            return "Ungültige API-Adresse."
        case .invalidResponse(_, let message, _):
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
            let rawBody = String(data: data, encoding: .utf8)
            throw WCInfoAPIError.decodingError(underlying: error, responseBody: rawBody)
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
            let rawBody = String(data: data, encoding: .utf8)
            throw WCInfoAPIError.decodingError(underlying: error, responseBody: rawBody)
        }
    }

    private func performRequest(url: URL) async throws -> Data {
        addBreadcrumb(category: "api", message: "GET \(url.absoluteString)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            addBreadcrumb(category: "api", message: "Network error: \(error.localizedDescription)", level: .error)
            throw WCInfoAPIError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            addBreadcrumb(category: "api", message: "Non-HTTP response", level: .error)
            throw WCInfoAPIError.invalidResponse(statusCode: 0, message: nil, responseBody: nil)
        }

        let rawBody = String(data: data, encoding: .utf8) ?? "<binary>"
        addBreadcrumb(
            category: "api",
            message: "Response \(httpResponse.statusCode) from \(url.absoluteString)",
            data: ["statusCode": httpResponse.statusCode, "bodyPreview": String(rawBody.prefix(2000))]
        )

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data)
            throw WCInfoAPIError.invalidResponse(statusCode: httpResponse.statusCode, message: message, responseBody: rawBody)
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

    private func addBreadcrumb(category: String, message: String, data: [String: Any]? = nil, level: SentryLevel = .info) {
        let crumb = Breadcrumb(level: level, category: category)
        crumb.message = message
        data?.forEach { crumb.data?[$0.key] = $0.value }
        SentrySDK.addBreadcrumb(crumb)
    }
}
