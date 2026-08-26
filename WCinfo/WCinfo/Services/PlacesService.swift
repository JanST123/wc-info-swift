import Foundation
import GooglePlaces
import CoreLocation

@MainActor
final class PlacesService: ObservableObject {
    private let client = GMSPlacesClient.shared()

    func autocomplete(query: String) async throws -> [GMSAutocompletePrediction] {
        let token = GMSAutocompleteSessionToken()
        return try await withCheckedThrowingContinuation { continuation in
            let filter = GMSAutocompleteFilter()
            filter.types = ["geocode", "establishment"]
            client.findAutocompletePredictions(fromQuery: query, filter: filter, sessionToken: token) { results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results ?? [])
                }
            }
        }
    }

    func fetchCoordinates(for placeID: String) async throws -> CLLocationCoordinate2D {
        return try await withCheckedThrowingContinuation { continuation in
            client.fetchPlace(fromPlaceID: placeID, placeFields: [.coordinate], sessionToken: nil) { place, error in
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

        let properties: [GMSPlaceProperty] = [.name, .formattedAddress, .website, .coordinate]
        let request = GMSFetchPlaceRequest(placeID: placeID, placeProperties: properties.map(\.rawValue), sessionToken: nil)

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.client.fetchPlace(with: request) { place, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let place = place {
                    let details = PlaceDetails(
                        placeID: placeID,
                        name: place.name,
                        formattedAddress: place.formattedAddress,
                        website: place.website?.absoluteString,
                        coordinate: place.coordinate
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
