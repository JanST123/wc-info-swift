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

    func fetchToiletsNearby(latitude: Double, longitude: Double, distance: Int = 25, filter: String? = nil) async throws -> [Toilet] {
        var urlComponents = URLComponents(string: "\(baseURL)/toilets/nearby/\(latitude)/\(longitude)")
        var queryItems = [URLQueryItem(name: "distance", value: String(distance))]
        if let filter = filter, !filter.isEmpty {
            queryItems.append(URLQueryItem(name: "filter", value: filter))
        }
        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
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

    func fetchToiletsInBounds(south: Double, west: Double, north: Double, east: Double, filter: String? = nil) async throws -> [Toilet] {
        var urlComponents = URLComponents(string: "\(baseURL)/toilets/bounds/\(south)/\(west)/\(north)/\(east)")
        if let filter = filter, !filter.isEmpty {
            urlComponents?.queryItems = [URLQueryItem(name: "filter", value: filter)]
        }

        guard let url = urlComponents?.url else {
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

    func addToilet(_ payload: AddToiletPayload) async throws -> AddToiletResponse {
        guard let url = URL(string: "\(baseURL)/toilet/add") else {
            throw WCInfoAPIError.invalidURL
        }
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(payload)
        let data = try await performRequest(url: url, method: "POST", body: bodyData)
        do {
            return try decoder.decode(AddToiletResponse.self, from: data)
        } catch {
            let rawBody = String(data: data, encoding: .utf8)
            throw WCInfoAPIError.decodingError(underlying: error, responseBody: rawBody)
        }
    }

    func updateToilet(id: Int, payload: UpdateToiletPayload) async throws -> UpdateToiletResponse {
        guard let url = URL(string: "\(baseURL)/toilet/\(id)/update") else {
            throw WCInfoAPIError.invalidURL
        }
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(payload)
        let data = try await performRequest(url: url, method: "PATCH", body: bodyData)
        do {
            return try decoder.decode(UpdateToiletResponse.self, from: data)
        } catch {
            let rawBody = String(data: data, encoding: .utf8)
            throw WCInfoAPIError.decodingError(underlying: error, responseBody: rawBody)
        }
    }

    func addToiletProperties(toiletId: Int, properties: [ToiletPropertyItem]) async throws -> AddToiletPropertiesResponse {
        guard let url = URL(string: "\(baseURL)/toilet/add-properties/\(toiletId)") else {
            throw WCInfoAPIError.invalidURL
        }
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(properties)
        let data = try await performRequest(url: url, method: "POST", body: bodyData)
        do {
            return try decoder.decode(AddToiletPropertiesResponse.self, from: data)
        } catch {
            let rawBody = String(data: data, encoding: .utf8)
            throw WCInfoAPIError.decodingError(underlying: error, responseBody: rawBody)
        }
    }

    func uploadPhoto(imageData: Data, toiletId: Int? = nil, exif: String? = nil, mimeType: String = "image/jpeg", filename: String = "photo.jpg") async throws -> UploadPhotoResponse {
        guard let url = URL(string: "\(baseURL)/upload") else {
            throw WCInfoAPIError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        // 1. Image binary
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // 2. toilet_id (optional)
        if let toiletId {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"toilet_id\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(toiletId)\r\n".data(using: .utf8)!)
        }

        // 3. exif (optional JSON string)
        if let exif, !exif.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"exif\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(exif)\r\n".data(using: .utf8)!)
        }

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let data = try await performRequest(url: url, method: "POST", body: body, customContentType: "multipart/form-data; boundary=\(boundary)")
        do {
            return try decoder.decode(UploadPhotoResponse.self, from: data)
        } catch {
            let rawBody = String(data: data, encoding: .utf8)
            throw WCInfoAPIError.decodingError(underlying: error, responseBody: rawBody)
        }
    }

    private func performRequest(url: URL, method: String = "GET", body: Data? = nil, customContentType: String? = nil, isRetryAfterCSRF: Bool = false) async throws -> Data {
        addBreadcrumb(category: "api", message: "\(method) \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = body
            request.setValue(customContentType ?? "application/json", forHTTPHeaderField: "Content-Type")
        }

        // Attach XSRF-TOKEN if available in cookie storage
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for cookie in cookies where cookie.name == "XSRF-TOKEN" {
                if let decoded = cookie.value.removingPercentEncoding {
                    request.setValue(decoded, forHTTPHeaderField: "X-XSRF-TOKEN")
                }
            }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
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

        // Handle Laravel 419 CSRF mismatch by refreshing session once
        if httpResponse.statusCode == 419 && !isRetryAfterCSRF, let healthURL = URL(string: "\(baseURL)/health") {
            _ = try? await URLSession.shared.data(from: healthURL)
            return try await performRequest(url: url, method: method, body: body, isRetryAfterCSRF: true)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data)
            throw WCInfoAPIError.invalidResponse(statusCode: httpResponse.statusCode, message: message, responseBody: rawBody)
        }

        return data
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let errors = json["errors"] as? [String: Any] {
                for (_, value) in errors {
                    if let messages = value as? [String], let first = messages.first, !first.isEmpty {
                        return first
                    } else if let message = value as? String, !message.isEmpty {
                        return message
                    }
                }
            }
            if let message = json["message"] as? String, !message.isEmpty {
                return message
            }
            if let error = json["error"] as? String, !error.isEmpty {
                return error
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
