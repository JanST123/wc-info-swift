import SwiftUI
import GoogleMaps
import GooglePlaces

@main
struct WCinfoApp: App {
    init() {
        let key = Config.googleAPIKey
        GMSServices.provideAPIKey(key)
        GMSPlacesClient.provideAPIKey(key)
        print("[WCinfo] Google API key loaded: prefix \(key.prefix(8))...")
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
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
}
