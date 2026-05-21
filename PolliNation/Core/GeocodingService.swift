import Foundation
import MapKit

struct LocationSearchResult: Identifiable, Hashable, Codable {
    var id: Int
    var name: String
    var admin1: String?
    var country: String?
    var latitude: Double
    var longitude: Double

    var savedLocation: SavedLocation {
        let subtitle = [admin1, country].compactMap { $0 }.joined(separator: ", ")
        return SavedLocation(name: name, subtitle: subtitle, latitude: latitude, longitude: longitude)
    }
}

final class GeocodingService {
    func search(_ query: String) async throws -> [LocationSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address, .pointOfInterest]
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
            span: MKCoordinateSpan(latitudeDelta: 55, longitudeDelta: 75)
        )

        let response = try await MKLocalSearch(request: request).start()
        let usResults = response.mapItems.filter { item in
            item.placemark.isoCountryCode == "US" || item.placemark.country == "United States"
        }
        let source = usResults.isEmpty ? response.mapItems : usResults

        return Array(source.prefix(12).enumerated()).map { index, item in
            let placemark = item.placemark
            let name = item.name ?? placemark.locality ?? placemark.postalCode ?? placemark.title ?? "Selected Location"
            let stateOrArea = [placemark.locality, placemark.administrativeArea]
                .compactMap { $0 }
                .removingDuplicateNeighbors()
                .joined(separator: ", ")
            return LocationSearchResult(
                id: index,
                name: name,
                admin1: stateOrArea.isEmpty ? placemark.administrativeArea : stateOrArea,
                country: placemark.country,
                latitude: placemark.coordinate.latitude,
                longitude: placemark.coordinate.longitude
            )
        }
    }
}

private extension Array where Element == String {
    func removingDuplicateNeighbors() -> [String] {
        reduce(into: [String]()) { result, value in
            if result.last != value { result.append(value) }
        }
    }
}
