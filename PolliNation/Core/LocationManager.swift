import Foundation
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus
    }

    func requestCurrentLocation() async throws -> SavedLocation {
        let location = try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let status = manager.authorizationStatus
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else if status == .denied || status == .restricted {
                continuation.resume(throwing: LocationError.permissionDenied)
                self.continuation = nil
                return
            }
            manager.requestLocation()
        }
        return try await reverseGeocode(location)
    }

    func reverseGeocode(_ location: CLLocation) async throws -> SavedLocation {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        let placemark = placemarks.first
        let city = placemark?.locality ?? placemark?.subAdministrativeArea ?? placemark?.administrativeArea ?? "Current Location"
        let region = [placemark?.administrativeArea, placemark?.country].compactMap { $0 }.joined(separator: ", ")
        return SavedLocation(name: city, subtitle: region, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            continuation?.resume(returning: location)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

enum LocationError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Location permission is required to fetch local pollen levels."
        }
    }
}
