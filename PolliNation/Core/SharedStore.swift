import Foundation

enum SharedStore {
    private static let reportKey = "latestPollenReport"
    private static let locationKey = "savedLocation"
    private static let lastNotificationKey = "lastNotificationKey"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    static func save(report: PollenReport) {
        if let data = try? JSONEncoder.polliNation.encode(report) {
            defaults.set(data, forKey: reportKey)
        }
    }

    static func loadReport() -> PollenReport? {
        guard let data = defaults.data(forKey: reportKey) else { return nil }
        return try? JSONDecoder.polliNation.decode(PollenReport.self, from: data)
    }

    static func save(location: SavedLocation) {
        if let data = try? JSONEncoder.polliNation.encode(location) {
            defaults.set(data, forKey: locationKey)
        }
    }

    static func loadLocation() -> SavedLocation? {
        guard let data = defaults.data(forKey: locationKey) else { return nil }
        return try? JSONDecoder.polliNation.decode(SavedLocation.self, from: data)
    }

    static func markNotificationSent(_ key: String) {
        defaults.set(key, forKey: lastNotificationKey)
    }

    static func lastNotificationSent() -> String? {
        defaults.string(forKey: lastNotificationKey)
    }
}

extension JSONEncoder {
    static var polliNation: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var polliNation: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
