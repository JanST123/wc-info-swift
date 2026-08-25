import Foundation
import MatomoTracker

final class Analytics {
    static let shared = Analytics()
    private var tracker: MatomoTracker?

    private init() {}

    func configure(siteId: String, baseURL: URL) {
        tracker = MatomoTracker(siteId: siteId, baseURL: baseURL)
    }

    func trackScreen(_ name: String) {
        tracker?.track(view: [name])
    }

    func trackEvent(category: String, action: String, name: String? = nil, value: Float? = nil) {
        tracker?.track(eventWithCategory: category, action: action, name: name, value: value)
    }
}
