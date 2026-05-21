import Foundation
import WidgetKit

@MainActor
final class PollenViewModel: ObservableObject {
    @Published var report: PollenReport?
    @Published var savedLocation: SavedLocation?
    @Published var searchText = ""
    @Published var searchResults: [LocationSearchResult] = []
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?

    let locationManager = LocationManager()
    let notifications = AlertNotificationManager()

    private let pollenService = PollenService()
    private let geocodingService = GeocodingService()

    init() {
        report = SharedStore.loadReport()
        savedLocation = SharedStore.loadLocation()
    }

    func bootstrap() async {
        await notifications.refreshAuthorizationStatus()
        if report == nil, let savedLocation {
            await refresh(location: savedLocation)
        }
    }

    func useCurrentLocation() async {
        isLoading = true
        errorMessage = nil
        do {
            let location = try await locationManager.requestCurrentLocation()
            await refresh(location: location)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func refreshCurrent() async {
        guard let location = savedLocation ?? report?.location else {
            await useCurrentLocation()
            return
        }
        await refresh(location: location)
    }

    func refresh(location: SavedLocation) async {
        isLoading = true
        errorMessage = nil
        do {
            let fresh = try await pollenService.fetchPollen(for: location)
            savedLocation = location
            report = fresh
            SharedStore.save(location: location)
            SharedStore.save(report: fresh)
            await notifications.notifyIfNeeded(for: fresh)
            WidgetCenter.shared.reloadAllTimelines()
            BackgroundRefreshManager.schedule()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func searchLocations() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        do {
            searchResults = try await geocodingService.search(query)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    func select(_ result: LocationSearchResult) async {
        searchText = ""
        searchResults = []
        await refresh(location: result.savedLocation)
    }
}
