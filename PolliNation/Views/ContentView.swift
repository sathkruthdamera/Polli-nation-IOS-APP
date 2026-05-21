import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PollenViewModel()
    @State private var showingSearch = false
    @State private var didBootstrap = false

    var body: some View {
        ZStack {
            AuroraBackground()
            PollenParticles()

            if let report = viewModel.report {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        HeroSection(report: report, viewModel: viewModel, showingSearch: $showingSearch)
                            .containerRelativeFrame(.vertical)

                        ProtectionSection(report: report)
                            .containerRelativeFrame(.vertical)

                        ForEach(Array(report.measurements.enumerated()), id: \.element.id) { index, measurement in
                            ChapterSection(
                                chapter: "signal \(index + 1)",
                                title: measurement.kind.chapterName,
                                color: color(for: measurement.kind),
                                measurement: measurement
                            )
                            .containerRelativeFrame(.vertical)
                        }

                        if !report.plants.isEmpty {
                            SpeciesBreakdownView(plants: report.plants)
                                .containerRelativeFrame(.vertical)
                        }

                        ProviderNotesView(report: report)
                            .containerRelativeFrame(.vertical)
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .ignoresSafeArea(edges: .bottom)
            } else {
                StartZenView(viewModel: viewModel, showingSearch: $showingSearch)
            }

            if viewModel.isLoading {
                LoadingOverlay()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if !didBootstrap {
                didBootstrap = true
                await viewModel.bootstrap()
            }
        }
        .sheet(isPresented: $showingSearch) {
            LocationSearchView(viewModel: viewModel)
        }
    }

    private func color(for kind: PollenKind) -> Color {
        Color.chapterGlow(kind)
    }
}

private struct HeroSection: View {
    var report: PollenReport
    @ObservedObject var viewModel: PollenViewModel
    @Binding var showingSearch: Bool

    private var dominant: PollenMeasurement? { report.dominantMeasurement }

    var body: some View {
        VStack(spacing: 20) {
            HeroTopBar(report: report, viewModel: viewModel)
                .padding(.top, 64)
                .padding(.horizontal, 22)

            Spacer(minLength: 4)

            VStack(spacing: 7) {
                Text("live pollen aura for")
                    .font(.caption.weight(.bold))
                    .tracking(4.2)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.36))
                Text(report.location.name.lowercased())
                    .font(.system(size: 64, weight: .thin, design: .serif).italic())
                    .minimumScaleFactor(0.50)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .shadow(color: Color.severity(report.highestSeverity).opacity(0.48), radius: 18)
                    .shadow(color: Color.severity(report.highestSeverity).opacity(0.26), radius: 48)
                Text(report.location.subtitle)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.44))
                    .lineLimit(1)
            }
            .padding(.horizontal, 22)

            BreathingOrb(
                severity: report.highestSeverity,
                title: dominant?.displayName ?? "pollen",
                subtitle: dominant.map { "\($0.index)/5 • \($0.category)" } ?? "no active signal"
            )
            .padding(.top, -6)

            if !report.measurements.isEmpty {
                HStack(spacing: 10) {
                    ForEach(report.measurements.prefix(3)) { measurement in
                        LiquidMetricTile(measurement: measurement)
                    }
                }
                .padding(.horizontal, 16)
            }

            WarningCard(report: report)
                .padding(.horizontal, 22)

            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.useCurrentLocation() }
                } label: {
                    Label("Use GPS", systemImage: "location.fill")
                }
                .buttonStyle(ZenButtonStyle(tint: .pollenGreen))

                Button { showingSearch = true } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .buttonStyle(ZenButtonStyle(tint: .pollenGold))
            }
            .padding(.horizontal, 22)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.pollenRose.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
            }

            Button {
                Task { await viewModel.notifications.requestAuthorization() }
            } label: {
                Label(viewModel.notifications.isAuthorized ? "Warnings enabled" : "Enable mask + eyewear warnings", systemImage: viewModel.notifications.isAuthorized ? "bell.badge.fill" : "bell.fill")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.top, 2)
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Text("swipe")
                    .font(.caption2.weight(.bold))
                    .tracking(7)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.26))
                Image(systemName: "chevron.down")
                    .foregroundStyle(.white.opacity(0.28))
            }
            .padding(.bottom, 28)
        }
    }
}

private struct HeroTopBar: View {
    var report: PollenReport
    @ObservedObject var viewModel: PollenViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("BrandMark")
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.13)))
                .shadow(color: .pollenGold.opacity(0.20), radius: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text("polli-nation")
                    .font(.system(size: 28, weight: .regular, design: .serif).italic())
                    .foregroundStyle(.white)
                Text(report.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2.weight(.bold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.42))
            }
            Spacer()
            Button { Task { await viewModel.refreshCurrent() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.headline.weight(.bold))
                    .frame(width: 46, height: 46)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.12)))
            }
            .foregroundStyle(.white)
        }
    }
}

private struct ProtectionSection: View {
    var report: PollenReport

    var body: some View {
        VStack(spacing: 28) {
            ZenSectionTitle(
                eyebrow: "care layer",
                title: "what to wear outside",
                subtitle: "The app turns live pollen levels into simple mask, eyewear, and window guidance."
            )
            .padding(.horizontal, 24)

            ProtectionPlanCard(report: report)
                .padding(.horizontal, 22)

            VStack(spacing: 12) {
                ForEach(report.warningMeasurements.prefix(3)) { measurement in
                    HStack(spacing: 12) {
                        GlowIcon(systemName: measurement.kind.symbolName, tint: Color.severity(measurement.severity), size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(measurement.displayName) pollen")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(measurement.category)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.50))
                        }
                        Spacer()
                        ZenPill(text: "protect", systemImage: "shield.fill", tint: .pollenRose)
                    }
                    .padding(14)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.10)))
                    .padding(.horizontal, 22)
                }

                if report.warningMeasurements.isEmpty {
                    Text("No high pollen signals right now. Keep notifications enabled for changes.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 620)
    }
}

private struct StartZenView: View {
    @ObservedObject var viewModel: PollenViewModel
    @Binding var showingSearch: Bool

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image("BrandMark")
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.14)))
                .shadow(color: .pollenGold.opacity(0.24), radius: 24)

            VStack(spacing: 8) {
                Text("polli-nation")
                    .font(.system(size: 48, weight: .regular, design: .serif).italic())
                    .foregroundStyle(.white)
                Text("free gov live pollen-risk for your location")
                    .font(.caption.weight(.bold))
                    .tracking(3.4)
                    .textCase(.uppercase)
                    .foregroundStyle(.pollenGreen.opacity(0.78))
                    .shadow(color: .pollenGreen.opacity(0.30), radius: 12)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            BreathingOrb(severity: .low, title: "ready", subtitle: "use gps or search anywhere in the usa")
                .padding(.top, 4)

            VStack(spacing: 12) {
                Button {
                    Task { await viewModel.useCurrentLocation() }
                } label: {
                    Label("Use GPS", systemImage: "location.fill")
                }
                .buttonStyle(ZenButtonStyle(tint: .pollenGreen))

                Button { showingSearch = true } label: {
                    Label("Search city, ZIP, or address", systemImage: "magnifyingglass")
                }
                .buttonStyle(ZenButtonStyle(tint: .pollenGold))
            }
            .padding(.horizontal, 28)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.pollenRose.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            Spacer()
        }
    }
}

private struct LoadingOverlay: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.white)
            Text("refreshing")
                .font(.caption2.weight(.bold))
                .tracking(2.8)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.50))
        }
        .padding(20)
        .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.10)))
    }
}

#Preview {
    ContentView()
}
