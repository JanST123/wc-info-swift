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
            filter.types = ["address"]
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

    enum PlacesError: Error {
        case noCoordinate
    }
}
