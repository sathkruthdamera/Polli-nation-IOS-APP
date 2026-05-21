import Foundation
import CoreLocation

struct SavedLocation: Codable, Hashable {
    var name: String
    var subtitle: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String {
        subtitle.isEmpty ? name : "\(name), \(subtitle)"
    }
}

enum Severity: String, Codable, Comparable {
    case none = "None"
    case veryLow = "Very Low"
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very High"

    var score: Int {
        switch self {
        case .none: return 0
        case .veryLow: return 1
        case .low: return 2
        case .moderate: return 3
        case .high: return 4
        case .veryHigh: return 5
        }
    }

    var warningNeeded: Bool { score >= Severity.moderate.score }

    static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.score < rhs.score }

    static func fromIndex(_ value: Int?) -> Severity {
        switch value ?? 0 {
        case ...0: return .none
        case 1: return .veryLow
        case 2: return .low
        case 3: return .moderate
        case 4: return .high
        default: return .veryHigh
        }
    }

    static func fromPollenGrains(_ value: Double?) -> Severity {
        guard let value else { return .none }
        switch value {
        case ...0: return .none
        case 0..<10: return .veryLow
        case 10..<30: return .low
        case 30..<60: return .moderate
        case 60..<120: return .high
        default: return .veryHigh
        }
    }
}

enum PollenKind: String, Codable, CaseIterable, Hashable {
    case tree = "Tree"
    case grass = "Grass"
    case weed = "Weed"
    case alder = "Alder"
    case birch = "Birch"
    case olive = "Olive"
    case mugwort = "Mugwort"
    case ragweed = "Ragweed"
    case oak = "Oak"
    case pine = "Pine"
    case cottonwood = "Cottonwood"
    case ash = "Ash"
    case elm = "Elm"
    case maple = "Maple"
    case other = "Other"

    var chapterName: String {
        switch self {
        case .tree: return "the canopy"
        case .grass: return "the meadow"
        case .weed: return "the undergrowth"
        default: return rawValue.lowercased()
        }
    }

    var symbolName: String {
        switch self {
        case .tree, .alder, .birch, .olive, .oak, .pine, .cottonwood, .ash, .elm, .maple: return "tree.fill"
        case .grass: return "leaf.fill"
        case .weed, .mugwort, .ragweed: return "camera.macro"
        case .other: return "sparkles"
        }
    }
}

struct PollenMeasurement: Identifiable, Codable, Hashable {
    var id: String
    var kind: PollenKind
    var displayName: String
    var value: Double?
    var index: Int
    var category: String
    var indexDescription: String
    var recommendations: [String]
    var inSeason: Bool

    var severity: Severity { Severity.fromIndex(index) }
    var shortValue: String {
        if let value { return value == floor(value) ? String(Int(value)) : String(format: "%.1f", value) }
        return "UPI \(index)"
    }
}

struct PlantDetail: Identifiable, Codable, Hashable {
    var id: String
    var kind: PollenKind
    var displayName: String
    var inSeason: Bool
    var index: Int
    var category: String
    var season: String?
    var family: String?
    var crossReaction: String?
    var pictureURL: String?
}


struct PollenReport: Codable, Hashable {
    var location: SavedLocation
    var providerName: String
    var regionCode: String?
    var updatedAt: Date
    var forecastDate: Date
    var measurements: [PollenMeasurement]
    var plants: [PlantDetail]
    var notes: [String]

    var dominantMeasurement: PollenMeasurement? {
        measurements.sorted { $0.index > $1.index }.first
    }

    var warningMeasurements: [PollenMeasurement] {
        measurements.filter { $0.severity.warningNeeded }.sorted { $0.index > $1.index }
    }

    var highestSeverity: Severity {
        dominantMeasurement?.severity ?? .none
    }

    var warningText: String {
        guard let top = dominantMeasurement, top.severity.warningNeeded else {
            return "Pollen levels look manageable. Keep tracking if symptoms change."
        }
        return "\(top.severity.rawValue) \(top.displayName.lowercased()) pollen detected. Wear a mask and protective eyewear outdoors."
    }

    static var preview: PollenReport {
        PollenReport(
            location: SavedLocation(name: "Your Location", subtitle: "United States", latitude: 39.8283, longitude: -98.5795),
            providerName: "Preview",
            regionCode: "US",
            updatedAt: Date(),
            forecastDate: Date(),
            measurements: [
                PollenMeasurement(id: "tree", kind: .tree, displayName: "Tree", value: nil, index: 4, category: "High", indexDescription: "Tree pollen is elevated.", recommendations: ["Wear a mask and protective eyewear outdoors."], inSeason: true),
                PollenMeasurement(id: "grass", kind: .grass, displayName: "Grass", value: nil, index: 2, category: "Low", indexDescription: "Grass pollen is low.", recommendations: [], inSeason: true),
                PollenMeasurement(id: "weed", kind: .weed, displayName: "Weed", value: nil, index: 1, category: "Very Low", indexDescription: "Weed pollen is low.", recommendations: [], inSeason: false)
            ],
            plants: [
                PlantDetail(id: "oak", kind: .oak, displayName: "Oak", inSeason: true, index: 4, category: "High", season: "Spring", family: "Fagaceae", crossReaction: nil, pictureURL: nil),
                PlantDetail(id: "ragweed", kind: .ragweed, displayName: "Ragweed", inSeason: false, index: 1, category: "Very Low", season: "Late summer, fall", family: "Asteraceae", crossReaction: nil, pictureURL: nil)
            ],
            notes: ["Preview data"]
        )
    }
}
