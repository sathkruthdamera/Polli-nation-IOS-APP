import SwiftUI

struct SeverityBadge: View {
    var severity: Severity

    var body: some View {
        Text(severity.rawValue)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.severity(severity).opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(Color.severity(severity).opacity(0.30)))
            .foregroundStyle(Color.severity(severity))
    }
}

struct PollenMeasurementCard: View {
    var measurement: PollenMeasurement

    var body: some View {
        let tint = Color.severity(measurement.severity)
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    GlowIcon(systemName: measurement.kind.symbolName, tint: tint, size: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(measurement.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(measurement.inSeason ? "active in the air" : "quiet / out of season")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    SeverityBadge(severity: measurement.severity)
                }

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(measurement.shortValue)
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(measurement.value == nil ? "signal" : "grains/m³")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.09))
                        Capsule()
                            .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.42)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(10, proxy.size.width * CGFloat(measurement.index) / 5.0))
                            .shadow(color: tint.opacity(0.45), radius: 12)
                    }
                }
                .frame(height: 11)

                Text(measurement.indexDescription)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(4)

                if !measurement.recommendations.isEmpty {
                    SoftDivider()
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(measurement.recommendations.prefix(2), id: \.self) { item in
                            Label(item, systemImage: "sparkle.magnifyingglass")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }
                }
            }
        }
    }
}

struct WarningCard: View {
    var report: PollenReport

    var body: some View {
        let isWarning = report.highestSeverity.warningNeeded
        let tint: Color = isWarning ? .pollenRose : .pollenGreen
        GlassCard(cornerRadius: 30) {
            HStack(alignment: .top, spacing: 14) {
                GlowIcon(systemName: isWarning ? "exclamationmark.triangle.fill" : "checkmark.seal.fill", tint: tint, size: 48)
                VStack(alignment: .leading, spacing: 8) {
                    Text(isWarning ? "protection ritual" : "air looks gentle")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(report.warningText)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.68))
                        .lineSpacing(2)
                    HStack(spacing: 8) {
                        if isWarning {
                            ZenPill(text: "mask", systemImage: "facemask.fill", tint: .pollenRose)
                            ZenPill(text: "eyewear", systemImage: "eyeglasses", tint: .pollenGold)
                        } else {
                            ZenPill(text: "manageable", systemImage: "wind", tint: .pollenGreen)
                        }
                    }
                }
                Spacer()
            }
        }
    }
}

struct ProtectionPlanCard: View {
    var report: PollenReport

    private var top: PollenMeasurement? { report.dominantMeasurement }

    var body: some View {
        let warning = report.highestSeverity.warningNeeded
        GlassCard(cornerRadius: 32) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("today's zen protocol")
                            .font(.caption2.weight(.bold))
                            .tracking(3.2)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.40))
                        Text(warning ? "Protect before stepping out" : "Breathe easy, keep tracking")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    GlowIcon(systemName: warning ? "shield.lefthalf.filled" : "leaf.circle.fill", tint: warning ? .pollenRose : .pollenGreen, size: 46)
                }

                SoftDivider()

                VStack(spacing: 10) {
                    ProtocolRow(icon: "facemask.fill", title: "Mask", value: warning ? "Recommended outdoors" : "Optional")
                    ProtocolRow(icon: "eyeglasses", title: "Eye wear", value: warning ? "Recommended for wind + commute" : "Optional")
                    ProtocolRow(icon: "window.vertical.closed", title: "Windows", value: warning ? "Keep closed during peak hours" : "Open with caution")
                    ProtocolRow(icon: top?.kind.symbolName ?? "leaf", title: "Main pollen", value: top.map { "\($0.displayName) • \($0.category)" } ?? "No signal yet")
                }
            }
        }
    }
}

private struct ProtocolRow: View {
    var icon: String
    var title: String
    var value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.80))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.50))
                .multilineTextAlignment(.trailing)
        }
    }
}

struct ChapterSection: View {
    var chapter: String
    var title: String
    var color: Color
    var measurement: PollenMeasurement

    var body: some View {
        VStack(spacing: 34) {
            VStack(spacing: 11) {
                Text(chapter)
                    .font(.caption2.weight(.bold))
                    .tracking(5)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.24))
                NeonText(text: title, color: color)
            }
            PollenMeasurementCard(measurement: measurement)
                .frame(maxWidth: 430)
        }
        .frame(maxWidth: .infinity, minHeight: 620)
        .padding(.horizontal, 22)
    }
}

struct SpeciesBreakdownView: View {
    var plants: [PlantDetail]

    var body: some View {
        VStack(spacing: 24) {
            ZenSectionTitle(
                eyebrow: "species map",
                title: "the breakdown",
                subtitle: "Plants and pollens most responsible for today's atmosphere."
            )

            LazyVStack(spacing: 12) {
                ForEach(plants.prefix(14)) { plant in
                    PlantGlassRow(plant: plant)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
}

private struct PlantGlassRow: View {
    var plant: PlantDetail

    var body: some View {
        let severity = Severity.fromIndex(plant.index)
        let tint = Color.severity(severity)
        GlassCard(cornerRadius: 24, innerPadding: 12) {
            HStack(spacing: 14) {
                AsyncImage(url: plant.pictureURL.flatMap(URL.init(string:))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: plant.kind.symbolName)
                            .font(.headline)
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.20)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(plant.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text([plant.season, plant.family].compactMap { $0 }.joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
                Spacer()
                SeverityBadge(severity: severity)
            }
        }
    }
}

struct ProviderNotesView: View {
    var report: PollenReport

    var body: some View {
        VStack(spacing: 22) {
            ZenSectionTitle(
                eyebrow: "source signal",
                title: "live data path",
                subtitle: "The app uses only free U.S. government NOAA/NWS live forecast data for pollen-risk estimates."
            )
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Label(report.providerName, systemImage: "antenna.radiowaves.left.and.right")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Location: \(report.location.displayName)")
                        .foregroundStyle(.white.opacity(0.62))
                    Text("Forecast date: \(report.forecastDate.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(.white.opacity(0.62))
                    if !report.notes.isEmpty {
                        SoftDivider()
                        ForEach(report.notes, id: \.self) { note in
                            Text("• \(note)")
                                .foregroundStyle(.white.opacity(0.50))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 22)
        }
        .padding(.vertical, 60)
    }
}
