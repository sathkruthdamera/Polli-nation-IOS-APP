import Foundation

enum AppConstants {
    static let appGroupID = "group.com.pollination.shared"
    static let backgroundRefreshTaskID = "com.pollination.refresh"

    /// Optional production backend URL, e.g. https://srv1663121.hstgr.cloud.
    /// Recommended for production. Backend defaults to Gov Live Mode using NOAA/NWS data.
    static var pollenBackendBaseURL: String {
        stringFromBundle("POLLEN_BACKEND_BASE_URL")
    }

    private static func stringFromBundle(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return "" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("$(") { return "" }
        return trimmed
    }
}
