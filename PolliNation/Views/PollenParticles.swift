import SwiftUI

struct PollenParticles: View {
    private let particles: [PollenParticle] = (0..<54).map { index in
        PollenParticle(
            x: Double.random(in: 0.02...0.98),
            y: Double.random(in: 0.02...0.98),
            radius: Double.random(in: 1.0...4.2),
            speed: Double.random(in: 0.05...0.22),
            phase: Double.random(in: 0...Double.pi * 2),
            opacity: Double.random(in: 0.10...0.42),
            colorIndex: index % 4
        )
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let driftX = sin(time * particle.speed + particle.phase) * 28
                    let driftY = cos(time * (particle.speed * 0.7) + particle.phase) * 34
                    let point = CGPoint(x: size.width * particle.x + driftX, y: size.height * particle.y + driftY)
                    let rect = CGRect(x: point.x, y: point.y, width: particle.radius * 2, height: particle.radius * 2)
                    context.opacity = particle.opacity
                    context.addFilter(.blur(radius: particle.radius * 0.35))
                    context.fill(Path(ellipseIn: rect), with: .color(color(for: particle.colorIndex)))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func color(for index: Int) -> Color {
        switch index {
        case 0: return .pollenGold
        case 1: return .pollenGreen
        case 2: return .pollenCyan
        default: return .pollenMoon
        }
    }
}

private struct PollenParticle {
    let x: Double
    let y: Double
    let radius: Double
    let speed: Double
    let phase: Double
    let opacity: Double
    let colorIndex: Int
}
