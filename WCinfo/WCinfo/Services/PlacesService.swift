import Foundation
import GooglePlaces
import CoreLocation

@MainActor
final class PlacesService: ObservableObject {
    private let client = GMSPlacesClient.shared()

    func autocomplete(query: String) async throws -> [GMSAutocompletePlaceSuggestion] {
        let request = GMSAutocompleteRequest(query: query)
        let filter = GMSAutocompleteFilter()
        filter.types = ["geocode", "establishment"]
        request.filter = filter

        return try await withCheckedThrowingContinuation { continuation in
            client.fetchAutocompleteSuggestions(from: request) { suggestions, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let placeSuggestions = (suggestions ?? []).compactMap { $0.placeSuggestion }
                    continuation.resume(returning: placeSuggestions)
                }
            }
        }
    }

    func fetchCoordinates(for placeID: String) async throws -> CLLocationCoordinate2D {
        if let cached = placeDetailsCache[placeID]?.coordinate {
            return cached
        }

        let request = GMSFetchPlaceRequest(
            placeID: placeID,
            placeProperties: [GMSPlaceProperty.coordinate.rawValue],
            sessionToken: nil
        )

        return try await withCheckedThrowingContinuation { continuation in
            client.fetchPlace(with: request) { place, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let coordinate = place?.coordinate {
                    continuation.resume(returning: coordinate)
                } else {
                    continuation.resume(throwing: PlacesError.noCoordinate)
                }
            }
        }
    }

    private var placeDetailsCache: [String: PlaceDetails] = [:]

    func fetchNearbyPlaces(coordinate: CLLocationCoordinate2D, radius: Double = 200.0) async throws -> [NearbyPlaceOption] {
        let restriction = GMSPlaceCircularLocationOption(coordinate, radius)
        let properties: [GMSPlaceProperty] = [
            .name,
            .placeID,
            .formattedAddress,
            .website,
            .coordinate
        ]
        let request = GMSPlaceSearchNearbyRequest(locationRestriction: restriction, placeProperties: properties.map(\.rawValue))
        request.maxResultCount = 20
        request.rankPreference = GMSPlaceSearchNearbyRankPreference.distance

        return try await withCheckedThrowingContinuation { continuation in
            client.searchNearby(with: request) { [weak self] places, error in
                if let error = error {
                    print("[PlacesService] searchNearby error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    var options: [NearbyPlaceOption] = []
                    for place in places ?? [] {
                        guard let placeID = place.placeID, let name = place.name else { continue }
                        self?.placeDetailsCache[placeID] = PlaceDetails(
                            placeID: placeID,
                            name: name,
                            formattedAddress: place.formattedAddress,
                            website: place.website?.absoluteString,
                            coordinate: place.coordinate
                        )
                        options.append(NearbyPlaceOption(
                            id: placeID,
                            name: name,
                            secondaryText: place.formattedAddress
                        ))
                    }
                    continuation.resume(returning: options)
                }
            }
        }
    }

    func fetchPlaceDetails(for placeID: String) async throws -> PlaceDetails {
        if let cached = placeDetailsCache[placeID] {
            return cached
        }

        let properties: [GMSPlaceProperty] = [.name, .formattedAddress, .website, .coordinate, .openingHours]
        let request = GMSFetchPlaceRequest(placeID: placeID, placeProperties: properties.map(\.rawValue), sessionToken: nil)

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.client.fetchPlace(with: request) { place, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let place = place {
                    var parsedPeriods: [GooglePlacesPeriod]? = nil
                    if let gmsPeriods = place.openingHours?.periods, !gmsPeriods.isEmpty {
                        parsedPeriods = gmsPeriods.map { p in
                            let openDay = Int(p.openEvent.day.rawValue)
                            let openPoint = GooglePlacesPoint(day: openDay, hour: Int(p.openEvent.time.hour), minute: Int(p.openEvent.time.minute))
                            var closePoint: GooglePlacesPoint? = nil
                            if let closeEvent = p.closeEvent {
                                let closeDay = Int(closeEvent.day.rawValue)
                                closePoint = GooglePlacesPoint(day: closeDay, hour: Int(closeEvent.time.hour), minute: Int(closeEvent.time.minute))
                            }
                            return GooglePlacesPeriod(open: openPoint, close: closePoint)
                        }
                    }

                    let details = PlaceDetails(
                        placeID: placeID,
                        name: place.name,
                        formattedAddress: place.formattedAddress,
                        website: place.website?.absoluteString,
                        coordinate: place.coordinate,
                        openingHours: parsedPeriods
                    )
                    self?.placeDetailsCache[placeID] = details
                    continuation.resume(returning: details)
                } else {
                    continuation.resume(throwing: PlacesError.noCoordinate)
                }
            }
        }
    }

    enum PlacesError: Error {
        case noCoordinate
    }
}
