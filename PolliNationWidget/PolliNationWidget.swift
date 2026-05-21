import WidgetKit
import SwiftUI

struct PollenWidgetEntry: TimelineEntry {
    let date: Date
    let report: PollenReport?
}

struct PollenTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PollenWidgetEntry {
        PollenWidgetEntry(date: Date(), report: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (PollenWidgetEntry) -> Void) {
        completion(PollenWidgetEntry(date: Date(), report: SharedStore.loadReport() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PollenWidgetEntry>) -> Void) {
        Task {
            var report = SharedStore.loadReport()
            if let location = SharedStore.loadLocation() {
                report = try? await PollenService().fetchPollen(for: location)
                if let report { SharedStore.save(report: report) }
            }
            let entry = PollenWidgetEntry(date: Date(), report: report)
            let next = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date().addingTimeInterval(7200)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct PollenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: PollenWidgetEntry

    var body: some View {
        ZStack {
            WidgetNeonBackground()

            if let report = entry.report {
                widgetContent(report: report)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text("polli-nation")
                            .font(.headline).italic()
                            .foregroundStyle(.white)
                        Spacer()
                        WidgetLocationCorner(text: "set location")
                    }
                    Spacer()
                    Text("Open the app to use GPS or search a U.S. location.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.70))
                }
                .padding()
            }
        }
        .containerBackground(.black, for: .widget)
    }

    @ViewBuilder
    private func widgetContent(report: PollenReport) -> some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 6) {
                    Text("pollen")
                        .font(.caption2.weight(.black))
                        .tracking(2.2)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.42))
                    Spacer(minLength: 4)
                    WidgetLocationCorner(text: cornerLocation(report.location), compact: true)
                }

                Spacer(minLength: 2)

                if let top = report.dominantMeasurement {
                    Image(systemName: top.kind.symbolName)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(widgetColor(for: top.kind))
                        .shadow(color: widgetColor(for: top.kind).opacity(0.70), radius: 10)

                    Text(top.displayName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)

                    Text(top.category)
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(widgetSeverityColor(for: top.severity))
                        .shadow(color: widgetSeverityColor(for: top.severity).opacity(0.55), radius: 14)
                        .minimumScaleFactor(0.62)

                    Text(top.severity.warningNeeded ? "mask + eyewear" : "manageable")
                        .font(.caption2.weight(.black))
                        .textCase(.uppercase)
                        .foregroundStyle(top.severity.warningNeeded ? WidgetNeon.rose : .white.opacity(0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
            .padding(14)
        default:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("polli-nation")
                            .font(.headline).italic()
                            .foregroundStyle(.white)
                        Text("gov live risk")
                            .font(.caption2.weight(.black))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundStyle(WidgetNeon.green.opacity(0.70))
                    }
                    Spacer()
                    WidgetLocationCorner(text: cornerLocation(report.location))
                }

                ForEach(report.measurements.prefix(family == .systemMedium ? 3 : 6)) { measurement in
                    HStack(spacing: 8) {
                        Image(systemName: measurement.kind.symbolName)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(widgetColor(for: measurement.kind))
                            .frame(width: 20)
                            .shadow(color: widgetColor(for: measurement.kind).opacity(0.55), radius: 8)
                        Text(measurement.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(measurement.category)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(widgetSeverityColor(for: measurement.severity))
                            .shadow(color: widgetSeverityColor(for: measurement.severity).opacity(0.38), radius: 8)
                    }
                    .padding(.vertical, 2)
                }

                if report.highestSeverity.warningNeeded {
                    Text("Wear mask + protective eyewear")
                        .font(.caption2.weight(.black))
                        .textCase(.uppercase)
                        .foregroundStyle(WidgetNeon.rose)
                        .shadow(color: WidgetNeon.rose.opacity(0.38), radius: 10)
                }
            }
            .padding()
        }
    }

    private func cornerLocation(_ location: SavedLocation) -> String {
        let name = location.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let state = location.subtitle
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        if let state, !name.isEmpty { return "\(name), \(state)" }
        return name.isEmpty ? "current" : name
    }

    private func widgetSeverityColor(for severity: Severity) -> Color {
        switch severity {
        case .none: return WidgetNeon.grey
        case .veryLow: return WidgetNeon.green
        case .low: return WidgetNeon.yellow
        case .moderate: return WidgetNeon.orange
        case .high, .veryHigh: return WidgetNeon.rose
        }
    }

    private func widgetColor(for kind: PollenKind) -> Color {
        switch kind {
        case .tree, .alder, .birch, .olive, .oak, .pine, .cottonwood, .ash, .elm, .maple:
            return WidgetNeon.green
        case .grass:
            return WidgetNeon.yellow
        case .weed, .mugwort, .ragweed:
            return WidgetNeon.brown
        case .other:
            return WidgetNeon.blue
        }
    }
}

private enum WidgetNeon {
    static let green = Color(red: 0.224, green: 1.000, blue: 0.078)   // #39FF14
    static let yellow = Color(red: 0.941, green: 0.816, blue: 0.376)  // #F0D060
    static let brown = Color(red: 0.769, green: 0.604, blue: 0.424)   // #C49A6C
    static let blue = Color(red: 0.376, green: 0.816, blue: 0.941)    // #60D0F0
    static let grey = Color(red: 0.784, green: 0.784, blue: 0.784)    // #C8C8C8
    static let rose = Color(red: 1.000, green: 0.180, blue: 0.380)
    static let orange = Color(red: 1.000, green: 0.520, blue: 0.180)
}

private struct WidgetLocationCorner: View {
    var text: String
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 2 : 4) {
            Image(systemName: "location.fill")
                .font(.system(size: compact ? 7 : 9, weight: .black))
            Text(text)
                .font(.system(size: compact ? 9 : 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .foregroundStyle(.white.opacity(0.82))
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 5)
        .background(.black.opacity(0.38), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
        .shadow(color: WidgetNeon.yellow.opacity(0.14), radius: 8)
        .frame(maxWidth: compact ? 84 : 132, alignment: .trailing)
    }
}

private struct WidgetNeonBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color(red: 0.010, green: 0.011, blue: 0.016), Color(red: 0.035, green: 0.025, blue: 0.010)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle().fill(WidgetNeon.green.opacity(0.20)).blur(radius: 28).offset(x: -48, y: -44)
            Circle().fill(WidgetNeon.yellow.opacity(0.19)).blur(radius: 30).offset(x: 58, y: 58)
            Circle().fill(WidgetNeon.brown.opacity(0.12)).blur(radius: 34).offset(x: -10, y: 80)
            Circle().stroke(WidgetNeon.yellow.opacity(0.12), lineWidth: 1).scaleEffect(1.18).blur(radius: 1)
        }
    }
}

struct PolliNationWidget: Widget {
    let kind = "PolliNationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PollenTimelineProvider()) { entry in
            PollenWidgetView(entry: entry)
        }
        .configurationDisplayName("Polli-Nation")
        .description("Government-only pollen-risk widget with location-aware warnings.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
