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

    func fetchNearbyPlaces(coordinate: CLLocationCoordinate2D, hintName: String = "") async throws -> [NearbyPlaceOption] {
        let token = GMSAutocompleteSessionToken()
        let filter = GMSAutocompleteFilter()
        filter.types = ["establishment"]

        let delta = 0.05
        let northEast = CLLocationCoordinate2D(latitude: coordinate.latitude + delta, longitude: coordinate.longitude + delta)
        let southWest = CLLocationCoordinate2D(latitude: coordinate.latitude - delta, longitude: coordinate.longitude - delta)
        filter.locationBias = GMSPlaceRectangularLocationOption(northEast, southWest)

        let query = hintName.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? hintName
        let searchQuery = query.isEmpty ? "Restaurant" : query

        return try await withCheckedThrowingContinuation { continuation in
            client.findAutocompletePredictions(fromQuery: searchQuery, filter: filter, sessionToken: token) { results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let places = (results ?? []).map { prediction in
                        NearbyPlaceOption(
                            id: prediction.placeID,
                            name: prediction.attributedPrimaryText.string,
                            secondaryText: prediction.attributedSecondaryText?.string
                        )
                    }
                    continuation.resume(returning: places)
                }
            }
        }
    }

    func fetchPlaceDetails(for placeID: String) async throws -> PlaceDetails {
        return try await withCheckedThrowingContinuation { continuation in
            let fields: GMSPlaceField = [.name, .formattedAddress, .website, .coordinate]
            client.fetchPlace(fromPlaceID: placeID, placeFields: fields, sessionToken: nil) { place, error in
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
