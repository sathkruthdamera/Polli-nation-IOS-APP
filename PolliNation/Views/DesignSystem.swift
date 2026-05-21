import SwiftUI

extension Color {
    static let pollenInk = Color(red: 0.006, green: 0.008, blue: 0.014)
    static let pollenBlack = Color(red: 0.000, green: 0.000, blue: 0.000)
    static let pollenNight = Color(red: 0.018, green: 0.020, blue: 0.032)
    static let pollenMoon = Color(red: 1.000, green: 1.000, blue: 1.000)

    // Neon palette matched to the original 6pollen6 UI.
    static let pollenGreen = Color(red: 0.224, green: 1.000, blue: 0.078)   // #39FF14
    static let pollenGold = Color(red: 0.941, green: 0.816, blue: 0.376)    // #F0D060
    static let pollenBrown = Color(red: 0.769, green: 0.604, blue: 0.424)   // #C49A6C
    static let pollenCyan = Color(red: 0.376, green: 0.816, blue: 0.941)    // #60D0F0
    static let pollenGrey = Color(red: 0.784, green: 0.784, blue: 0.784)    // #C8C8C8
    static let pollenMint = Color(red: 0.620, green: 1.000, blue: 0.760)
    static let pollenRose = Color(red: 1.000, green: 0.180, blue: 0.380)
    static let pollenViolet = Color(red: 0.650, green: 0.310, blue: 1.000)
    static let pollenSky = Color(red: 0.380, green: 0.760, blue: 1.000)

    static func severity(_ severity: Severity) -> Color {
        switch severity {
        case .none: return .pollenGrey
        case .veryLow: return .pollenGreen
        case .low: return .pollenGold
        case .moderate: return Color(red: 1.00, green: 0.52, blue: 0.18)
        case .high: return .pollenRose
        case .veryHigh: return Color(red: 1.00, green: 0.08, blue: 0.50)
        }
    }

    static func pollenKind(_ kind: PollenKind) -> Color {
        switch kind {
        case .tree, .alder, .birch, .olive, .oak, .pine, .cottonwood, .ash, .elm, .maple:
            return .pollenGreen
        case .grass:
            return .pollenGold
        case .weed, .mugwort, .ragweed:
            return .pollenBrown
        case .other:
            return .pollenCyan
        }
    }

    static func chapterGlow(_ kind: PollenKind) -> Color {
        switch kind {
        case .tree, .alder, .birch, .olive, .oak, .pine, .cottonwood, .ash, .elm, .maple: return .pollenGreen
        case .grass: return .pollenGold
        case .weed, .mugwort, .ragweed: return .pollenBrown
        case .other: return .pollenCyan
        }
    }
}

struct AuroraBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(
                    colors: [Color.pollenBlack, Color.pollenInk, Color.pollenNight, Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                RadialGradient(colors: [Color.pollenGreen.opacity(0.30), .clear], center: .center, startRadius: 8, endRadius: 330)
                    .frame(width: 680, height: 680)
                    .offset(x: sin(t / 6.0) * 120 - 210, y: cos(t / 7.0) * 110 - 250)
                    .blur(radius: 30)
                    .blendMode(.screen)

                RadialGradient(colors: [Color.pollenGold.opacity(0.28), .clear], center: .center, startRadius: 9, endRadius: 320)
                    .frame(width: 620, height: 620)
                    .offset(x: cos(t / 5.8) * 128 + 185, y: sin(t / 8.0) * 140 + 220)
                    .blur(radius: 32)
                    .blendMode(.screen)

                RadialGradient(colors: [Color.pollenBrown.opacity(0.18), .clear], center: .center, startRadius: 6, endRadius: 290)
                    .frame(width: 540, height: 540)
                    .offset(x: sin(t / 7.3) * 115 - 40, y: cos(t / 8.6) * 160 + 100)
                    .blur(radius: 44)
                    .blendMode(.screen)

                RadialGradient(colors: [Color.pollenCyan.opacity(0.13), .clear], center: .center, startRadius: 3, endRadius: 260)
                    .frame(width: 520, height: 520)
                    .offset(x: cos(t / 8.5) * 160 - 20, y: sin(t / 9.2) * 170)
                    .blur(radius: 50)
                    .blendMode(.screen)

                LinearGradient(colors: [.black.opacity(0.06), .black.opacity(0.74)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                Canvas { context, size in
                    let path = Path { p in
                        p.move(to: CGPoint(x: 0, y: size.height * 0.21))
                        for x in stride(from: CGFloat(0), through: size.width, by: 8) {
                            let y = size.height * 0.22 + sin(Double(x) / 56.0 + t / 4.6) * 13 + cos(Double(x) / 88.0 + t / 6.0) * 8
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    context.stroke(path, with: .linearGradient(Gradient(colors: [.white.opacity(0.00), .white.opacity(0.18), .white.opacity(0.00)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), lineWidth: 0.8)
                }
                .opacity(0.55)
                .blendMode(.screen)
            }
        }
    }
}

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 34
    var innerPadding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(innerPadding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.white.opacity(0.056))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.62))
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.045), .black.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.26), .white.opacity(0.07), .white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: .pollenGold.opacity(0.08), radius: 40, x: 0, y: 0)
            .shadow(color: .black.opacity(0.48), radius: 30, x: 0, y: 20)
    }
}

struct NeonText: View {
    var text: String
    var color: Color
    var size: CGFloat = 58

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .regular, design: .serif).italic())
            .minimumScaleFactor(0.55)
            .multilineTextAlignment(.center)
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.95), radius: 10)
            .shadow(color: color.opacity(0.55), radius: 28)
            .shadow(color: color.opacity(0.30), radius: 64)
    }
}

struct ZenPill: View {
    var text: String
    var systemImage: String
    var tint: Color = .white

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(tint.opacity(0.98))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(tint.opacity(0.105), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.30), lineWidth: 1))
            .shadow(color: tint.opacity(0.24), radius: 13)
    }
}

struct ZenButtonStyle: ButtonStyle {
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [tint.opacity(configuration.isPressed ? 0.30 : 0.20), .white.opacity(configuration.isPressed ? 0.07 : 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
            .overlay(Capsule().stroke(.white.opacity(0.13)))
            .shadow(color: tint.opacity(configuration.isPressed ? 0.10 : 0.20), radius: 18, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.76), value: configuration.isPressed)
    }
}

struct SoftDivider: View {
    var body: some View {
        LinearGradient(colors: [.clear, .white.opacity(0.20), .clear], startPoint: .leading, endPoint: .trailing)
            .frame(height: 1)
    }
}

struct ZenSectionTitle: View {
    var eyebrow: String
    var title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Text(eyebrow)
                .font(.caption2.weight(.bold))
                .tracking(4.8)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.36))
            Text(title)
                .font(.system(size: 42, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .white.opacity(0.12), radius: 24)
            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.56))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }
}

struct GlowIcon: View {
    var systemName: String
    var tint: Color
    var size: CGFloat = 46

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: size * 0.34, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.34, style: .continuous).stroke(tint.opacity(0.34)))
            .shadow(color: tint.opacity(0.46), radius: 20, x: 0, y: 0)
    }
}

struct BreathingOrb: View {
    var severity: Severity
    var title: String
    var subtitle: String

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = (sin(t * 1.35) + 1) / 2
            let tint = Color.severity(severity)
            ZStack {
                ForEach(0..<4, id: \.self) { ring in
                    Circle()
                        .stroke(tint.opacity(0.22 - Double(ring) * 0.035), lineWidth: 1.2)
                        .scaleEffect(0.70 + CGFloat(ring) * 0.18 + CGFloat(pulse) * 0.045)
                        .blur(radius: CGFloat(ring) * 0.7)
                }

                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(0.42), tint.opacity(0.16), .white.opacity(0.035), .clear], center: .center, startRadius: 8, endRadius: 130))
                    .frame(width: 244, height: 244)
                    .blur(radius: 2)
                    .scaleEffect(0.98 + CGFloat(pulse) * 0.035)

                Circle()
                    .fill(.ultraThinMaterial.opacity(0.72))
                    .frame(width: 178, height: 178)
                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                    .shadow(color: tint.opacity(0.36), radius: 34)

                VStack(spacing: 7) {
                    Text(title)
                        .font(.caption2.weight(.bold))
                        .tracking(3.8)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.48))
                    Text(severity.rawValue)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 28)
                }
            }
            .frame(width: 292, height: 292)
            .accessibilityElement(children: .combine)
        }
    }
}

struct LiquidMetricTile: View {
    var measurement: PollenMeasurement

    var body: some View {
        let tint = Color.severity(measurement.severity)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                GlowIcon(systemName: measurement.kind.symbolName, tint: tint, size: 36)
                Spacer()
                Text("\(measurement.index)/5")
                    .font(.caption.weight(.black))
                    .foregroundStyle(tint)
            }
            Text(measurement.displayName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(measurement.category)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(1)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.92), tint.opacity(0.42)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, proxy.size.width * CGFloat(measurement.index) / 5.0))
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.055))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.10)))
        )
    }
}
