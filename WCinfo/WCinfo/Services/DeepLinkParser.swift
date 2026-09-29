import Foundation

enum WCInfoDeepLink: Equatable {
    case home
    case toilets(placeId: String, placeName: String?, toiletId: Int?, toiletName: String?)
    case urgentNavigation(ToiletFilterSettings)
}

struct DeepLinkParser {
    static func parse(url: URL) -> WCInfoDeepLink? {
        // Handle custom scheme "wcinfo"
        if url.scheme?.lowercased() == "wcinfo" {
            if url.host == "urgent-navigate" || url.path.contains("urgent-navigate") {
                return .urgentNavigation(ToiletFilterSettings(url: url))
            }
        }

        // Normalize URL string to handle cases like "https://wc-info.orgToilets/..." or missing slash after domain
        var urlString = url.absoluteString
        if let regex = try? NSRegularExpression(pattern: "(https?:\\/\\/[^\\/]+?)(Toilets\\/)", options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: urlString.utf16.count)
            urlString = regex.stringByReplacingMatches(in: urlString, options: [], range: range, withTemplate: "$1/$2")
        }

        guard let normalizedURL = URL(string: urlString) else {
            return nil
        }

        // Check if host belongs to wc-info.org or scheme is wcinfo
        let host = normalizedURL.host?.lowercased() ?? ""
        let scheme = normalizedURL.scheme?.lowercased() ?? ""
        let isWCInfoHost = host == "wc-info.org" || host == "www.wc-info.org" || host.hasSuffix(".wc-info.org")
        let isWCInfoScheme = scheme == "wcinfo"

        guard isWCInfoHost || isWCInfoScheme else {
            return nil
        }

        // Path components
        var pathComponents = normalizedURL.pathComponents.filter { $0 != "/" && !$0.isEmpty }

        // If scheme is wcinfo and host is used as first path component (e.g. wcinfo://toilets/...)
        if isWCInfoScheme, let first = normalizedURL.host, !first.isEmpty, first != "wc-info.org" && first != "www.wc-info.org" {
            pathComponents.insert(first, at: 0)
        }

        if pathComponents.isEmpty {
            return .home
        }

        let firstComponent = pathComponents[0].lowercased()
        guard firstComponent == "toilets" else {
            return .home
        }

        guard pathComponents.count > 1 else {
            return .home
        }

        let placeComponent = pathComponents[1]
        let (placeName, placeId) = parsePlaceComponent(placeComponent)

        guard let placeId = placeId, !placeId.isEmpty else {
            return nil
        }

        var toiletId: Int? = nil
        var toiletName: String? = nil

        if pathComponents.count > 2 {
            let toiletComponent = pathComponents[2]
            let (parsedToiletName, parsedToiletId) = parseToiletComponent(toiletComponent)
            toiletName = parsedToiletName
            toiletId = parsedToiletId
        }

        return .toilets(placeId: placeId, placeName: placeName, toiletId: toiletId, toiletName: toiletName)
    }

    private static func parsePlaceComponent(_ component: String) -> (name: String?, placeId: String?) {
        let decoded = component.removingPercentEncoding ?? component
        if decoded.contains("---") {
            let parts = decoded.components(separatedBy: "---")
            let placeId = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines)
            let nameSlug = parts.dropLast().joined(separator: "---")
            let name = nameSlug.replacingOccurrences(of: "-", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return (name.isEmpty ? nil : name, placeId)
        } else {
            return (nil, decoded.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func parseToiletComponent(_ component: String) -> (name: String?, toiletId: Int?) {
        let decoded = component.removingPercentEncoding ?? component
        if decoded.contains("---") {
            let parts = decoded.components(separatedBy: "---")
            let idString = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let toiletId = Int(idString)
            let nameSlug = parts.dropLast().joined(separator: "---")
            let name = nameSlug.replacingOccurrences(of: "-", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return (name.isEmpty ? nil : name, toiletId)
        } else {
            let toiletId = Int(decoded.trimmingCharacters(in: .whitespacesAndNewlines))
            return (nil, toiletId)
        }
    }
}
