import SwiftUI
import GoogleMaps
import GooglePlaces
import Sentry
import MatomoTracker

@main
struct WCinfoApp: App {
    init() {
        let key = Config.googleAPIKey
        GMSServices.provideAPIKey(key)
        GMSPlacesClient.provideAPIKey(key)

        SentrySDK.start { options in
            options.dsn = Config.sentryDSN
            options.debug = false
            options.enableAppHangTracking = true
            options.enableNetworkTracking = true
            options.enableSwizzling = true
        }

        Analytics.shared.configure(
            siteId: Config.matomoSiteID,
            baseURL: Config.matomoTrackingURL
        )

        print("[WCinfo] Google API key loaded: prefix \(key.prefix(8))...")
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .overlay(ErrorBannerView())
        }
    }
}

enum Config {
    private static var plist: [String: Any]? {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }

    static var googleAPIKey: String {
        guard let key = plist?["GoogleAPIKey"] as? String else {
            fatalError("Config.plist mit GoogleAPIKey fehlt")
        }
        return key
    }

    static var apiBaseURL: String? {
        plist?["APIBaseURL"] as? String
    }

    static var sentryDSN: String {
        guard let dsn = plist?["SentryDSN"] as? String, !dsn.isEmpty else {
            fatalError("Config.plist mit SentryDSN fehlt")
        }
        return dsn
    }

    static var matomoTrackingURL: URL {
        guard let host = plist?["MatomoHost"] as? String,
              let url = URL(string: host) else {
            fatalError("Config.plist mit MatomoHost fehlt")
        }
        return url.appendingPathComponent("matomo.php")
    }

    static var matomoSiteID: String {
        guard let siteId = plist?["MatomoSiteID"] as? String, !siteId.isEmpty else {
            fatalError("Config.plist mit MatomoSiteID fehlt")
        }
        return siteId
    }
}
