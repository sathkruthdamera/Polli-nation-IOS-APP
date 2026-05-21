import Foundation

enum PollenServiceError: LocalizedError {
    case noProviderAvailable(String)
    case emptyResponse
    case malformedURL

    var errorDescription: String? {
        switch self {
        case .noProviderAvailable(let message): return message
        case .emptyResponse: return "The pollen provider returned no usable pollen data for this location."
        case .malformedURL: return "Unable to build pollen API URL."
        }
    }
}

final class PollenService {
    func fetchPollen(for location: SavedLocation) async throws -> PollenReport {
        var errors: [String] = []

        if !AppConstants.pollenBackendBaseURL.isEmpty {
            do { return try await BackendPollenProvider().fetch(location: location) }
            catch { errors.append("Polli-Nation government backend: \(error.localizedDescription)") }
        }

        do { return try await GovernmentPollenProvider().fetch(location: location) }
        catch { errors.append("NOAA/NWS government mode: \(error.localizedDescription)") }

        let message = errors.isEmpty
        ? "No government pollen-risk provider is available."
        : "No government pollen-risk data available for \(location.displayName). \(errors.joined(separator: " "))"
        throw PollenServiceError.noProviderAvailable(message)
    }
}

// MARK: - Polli-Nation VPS backend provider

private final class BackendPollenProvider {
    func fetch(location: SavedLocation) async throws -> PollenReport {
        var base = AppConstants.pollenBackendBaseURL
        if !base.hasSuffix("/") { base += "/" }
        guard var components = URLComponents(string: base + "api/pollen") else {
            throw PollenServiceError.malformedURL
        }
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(location.latitude)),
            URLQueryItem(name: "lon", value: String(location.longitude)),
            URLQueryItem(name: "name", value: location.name),
            URLQueryItem(name: "subtitle", value: location.subtitle)
        ]
        guard let url = components.url else { throw PollenServiceError.malformedURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        try HTTPValidator.validate(response: response, data: data)
        return try JSONDecoder.polliNation.decode(PollenReport.self, from: data)
    }
}


// MARK: - Free U.S. government provider (NOAA/NWS live weather -> pollen-risk estimate)

private final class GovernmentPollenProvider {
    func fetch(location: SavedLocation) async throws -> PollenReport {
        let pointURLString = "https://api.weather.gov/points/\(String(format: "%.4f", location.latitude)),\(String(format: "%.4f", location.longitude))"
        guard let pointURL = URL(string: pointURLString) else { throw PollenServiceError.malformedURL }
        let point: NWSPointResponse = try await fetchJSON(pointURL)
        guard let gridURLString = point.properties.forecastGridData, let gridURL = URL(string: gridURLString) else {
            throw PollenServiceError.noProviderAvailable("NOAA/NWS did not return grid forecast data for this coordinate.")
        }
        let grid: NWSGridResponse = try await fetchJSON(gridURL)
        let props = grid.properties

        let tempC = props.temperature?.firstValue
        let humidity = props.relativeHumidity?.firstValue
        let windKmh = props.windSpeed?.firstValue
        let pop = props.probabilityOfPrecipitation?.firstValue
        let precipMM = props.quantitativePrecipitation?.firstValue
        let sampleDate = props.temperature?.firstDate ?? Date()
        let month = Calendar.current.component(.month, from: sampleDate)
        let modifier = weatherModifier(tempC: tempC, humidity: humidity, windKmh: windKmh, pop: pop, precipMM: precipMM)

        let scores: [(PollenKind, String, Int)] = [
            (.tree, "Tree", clampIndex(seasonalBase(month: month, latitude: location.latitude, kind: "tree") + modifier)),
            (.grass, "Grass", clampIndex(seasonalBase(month: month, latitude: location.latitude, kind: "grass") + modifier)),
            (.weed, "Weed", clampIndex(seasonalBase(month: month, latitude: location.latitude, kind: "weed") + modifier))
        ]

        let measurements = scores.map { item -> PollenMeasurement in
            let severity = Severity.fromIndex(item.2)
            let weatherText = weatherSummary(tempC: tempC, humidity: humidity, windKmh: windKmh, pop: pop)
            return PollenMeasurement(
                id: item.1.lowercased(),
                kind: item.0,
                displayName: item.1,
                value: nil,
                index: item.2,
                category: severity.rawValue,
                indexDescription: "Estimated from live NOAA/NWS forecast data, U.S. seasonality, and local weather conditions. \(weatherText)",
                recommendations: recommendations(for: item.1, index: item.2),
                inSeason: item.2 > 0
            )
        }.sorted { $0.index > $1.index }

        let plants = scores.flatMap { item in
            plantDetails(kindName: item.1, kind: item.0, index: item.2, latitude: location.latitude, longitude: location.longitude)
        }.sorted { $0.index > $1.index }

        let resolvedName = location.name.isEmpty ? (point.properties.relativeLocation?.properties.city ?? "Current Location") : location.name
        let resolvedSubtitle = location.subtitle.isEmpty ? (point.properties.relativeLocation?.properties.state ?? "United States") : location.subtitle

        return PollenReport(
            location: SavedLocation(name: resolvedName, subtitle: resolvedSubtitle, latitude: location.latitude, longitude: location.longitude),
            providerName: "Gov Live Mode • NOAA/NWS pollen-risk estimate",
            regionCode: "US",
            updatedAt: Date(),
            forecastDate: sampleDate,
            measurements: measurements,
            plants: plants,
            notes: [
                "Gov Live Mode uses live NOAA/NWS forecast data for the selected coordinate and estimates pollen risk from season, temperature, humidity, wind, and precipitation.",
                "This is not a laboratory pollen count. There is no single U.S. government API that publishes live measured pollen counts for every U.S. coordinate."
            ]
        )
    }

    private func fetchJSON<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("PolliNation iOS (contact@example.com)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/geo+json, application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try HTTPValidator.validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func clampIndex(_ value: Double) -> Int { max(0, min(5, Int(value.rounded()))) }

    private func seasonalBase(month: Int, latitude: Double, kind: String) -> Double {
        let south = latitude < 34
        let north = latitude >= 42
        switch kind {
        case "tree":
            switch month {
            case 1: return south ? 1.0 : 0.0
            case 2: return south ? 2.2 : 0.2
            case 3: return south ? 4.4 : 2.0
            case 4: return south ? 4.2 : 4.6
            case 5: return south ? 2.2 : 4.0
            case 6: return north ? 0.8 : 0.3
            case 12: return south ? 1.2 : 0.0
            default: return 0.0
            }
        case "grass":
            switch month {
            case 3: return south ? 1.2 : 0.0
            case 4: return south ? 2.5 : 1.0
            case 5, 6: return 4.2
            case 7: return south ? 3.6 : 3.0
            case 8: return south ? 2.0 : 1.0
            case 9: return south ? 1.2 : 0.3
            default: return 0.0
            }
        case "weed":
            switch month {
            case 6: return south ? 0.8 : 0.2
            case 7: return 1.5
            case 8: return 3.3
            case 9: return 5.0
            case 10: return 4.0
            case 11: return south ? 2.0 : 0.8
            case 12: return south ? 0.8 : 0.0
            default: return 0.0
            }
        default:
            return 0.0
        }
    }

    private func weatherModifier(tempC: Double?, humidity: Double?, windKmh: Double?, pop: Double?, precipMM: Double?) -> Double {
        var modifier = 0.0
        if let tempC {
            let tempF = tempC * 9 / 5 + 32
            if (60...90).contains(tempF) { modifier += 0.45 }
            else if tempF < 35 || tempF > 100 { modifier -= 0.75 }
        }
        if let humidity {
            if (30...55).contains(humidity) { modifier += 0.35 }
            else if humidity >= 78 { modifier -= 0.55 }
        }
        if let windKmh {
            let windMph = windKmh * 0.621371
            if (5...20).contains(windMph) { modifier += 0.55 }
            else if windMph > 28 { modifier -= 0.2 }
        }
        if let pop {
            if pop >= 65 { modifier -= 1.2 }
            else if pop >= 35 { modifier -= 0.55 }
        }
        if let precipMM, precipMM >= 1.0 { modifier -= 1.3 }
        return modifier
    }

    private func weatherSummary(tempC: Double?, humidity: Double?, windKmh: Double?, pop: Double?) -> String {
        var parts: [String] = []
        if let tempC { parts.append("Temp \(Int((tempC * 9 / 5 + 32).rounded()))°F") }
        if let humidity { parts.append("Humidity \(Int(humidity.rounded()))%") }
        if let windKmh { parts.append("Wind \(Int((windKmh * 0.621371).rounded())) mph") }
        if let pop { parts.append("Rain chance \(Int(pop.rounded()))%") }
        return parts.joined(separator: " • ")
    }

    private func recommendations(for kind: String, index: Int) -> [String] {
        guard index >= 3 else { return [] }
        var items = [
            "\(Severity.fromIndex(index).rawValue) \(kind.lowercased()) pollen risk. Wear a mask and protective eyewear outdoors.",
            "Keep windows closed, shower after outdoor exposure, and rinse eyes if irritated."
        ]
        if kind == "Grass" { items.append("Avoid mowing or fresh-cut grass exposure when possible.") }
        if kind == "Weed" { items.append("Ragweed and weed pollen can travel long distances on windy days.") }
        if kind == "Tree" { items.append("Tree pollen often peaks on dry, breezy mornings.") }
        return items
    }

    private func plantDetails(kindName: String, kind: PollenKind, index: Int, latitude: Double, longitude: Double) -> [PlantDetail] {
        let names: [String]
        let season: String
        let family: String
        if kindName == "Tree" {
            season = "Winter to spring, earlier in southern states"
            family = "Regional trees"
            if longitude < -110 { names = ["Juniper / Cedar", "Oak", "Pine"] }
            else if longitude < -95 && latitude < 38 { names = ["Mountain cedar", "Oak", "Elm"] }
            else if latitude > 41 { names = ["Maple", "Birch", "Oak"] }
            else if latitude < 34 { names = ["Oak", "Pine", "Cedar / Juniper"] }
            else { names = ["Oak", "Maple", "Elm"] }
        } else if kindName == "Grass" {
            season = "Late spring to summer"
            family = "Poaceae"
            names = latitude < 36 ? ["Bermuda grass", "Johnson grass", "Ryegrass"] : ["Timothy grass", "Kentucky bluegrass", "Ryegrass"]
        } else {
            season = "Late summer to fall, ragweed peak in early fall"
            family = "Asteraceae / Amaranthaceae"
            names = ["Ragweed", "Pigweed / Amaranth", "Chenopod"]
        }

        return names.enumerated().map { offset, name in
            let plantIndex = max(0, min(5, index - offset))
            return PlantDetail(
                id: name.lowercased().replacingOccurrences(of: " ", with: "-"),
                kind: kind,
                displayName: name,
                inSeason: plantIndex > 0,
                index: plantIndex,
                category: Severity.fromIndex(plantIndex).rawValue,
                season: season,
                family: family,
                crossReaction: nil,
                pictureURL: nil
            )
        }
    }
}

private struct NWSPointResponse: Decodable {
    let properties: NWSPointProperties
}

private struct NWSPointProperties: Decodable {
    let forecastGridData: String?
    let relativeLocation: NWSRelativeLocation?
}

private struct NWSRelativeLocation: Decodable {
    let properties: NWSRelativeLocationProperties
}

private struct NWSRelativeLocationProperties: Decodable {
    let city: String?
    let state: String?
}

private struct NWSGridResponse: Decodable {
    let properties: NWSGridProperties
}

private struct NWSGridProperties: Decodable {
    let temperature: NWSGridSeries?
    let relativeHumidity: NWSGridSeries?
    let windSpeed: NWSGridSeries?
    let probabilityOfPrecipitation: NWSGridSeries?
    let quantitativePrecipitation: NWSGridSeries?
}

private struct NWSGridSeries: Decodable {
    let values: [NWSGridValue]?

    var firstValue: Double? {
        values?.compactMap { $0.value }.first
    }

    var firstDate: Date? {
        guard let raw = values?.compactMap({ $0.validTime }).first else { return nil }
        let start = raw.components(separatedBy: "/").first ?? raw
        return ISO8601DateFormatter().date(from: start)
    }
}

private struct NWSGridValue: Decodable {
    let validTime: String?
    let value: Double?
}

// MARK: - Utilities

enum HTTPValidator {
    static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw PollenServiceError.noProviderAvailable("HTTP \(http.statusCode). \(body.prefix(180))")
        }
    }
}
