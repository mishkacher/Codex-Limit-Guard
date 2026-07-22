import SwiftUI
import CodexLimitGuardCore

struct StatusRingView: View {
    let remaining: Double?
    let level: GuardLevel
    let title: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 24)
            Circle()
                .trim(from: 0, to: max(0.015, (remaining ?? 0) / 100))
                .stroke(
                    AngularGradient(colors: [accent.opacity(0.45), accent, accent.opacity(0.7)], center: .center),
                    style: StrokeStyle(lineWidth: 24, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.7, dampingFraction: 0.82), value: remaining)
                .shadow(color: accent.opacity(0.24), radius: 14)
            VStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(accent)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(remaining.map { String(Int($0.rounded())) } ?? "—")
                        .font(.system(size: 62, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("%").font(.title2.weight(.semibold)).foregroundStyle(.secondary)
                }
                Text(title).font(.headline).multilineTextAlignment(.center)
                Text("remaining in limiting window")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.08)))
    }

    private var accent: Color {
        switch level {
        case .healthy: return .green
        case .warning: return .yellow
        case .blocking: return .orange
        case .softStop: return .pink
        case .hardStop: return .red
        }
    }

    private var symbol: String {
        switch level {
        case .healthy: return "shield.checkered"
        case .warning: return "exclamationmark.shield.fill"
        case .blocking: return "lock.shield.fill"
        case .softStop: return "hand.raised.fill"
        case .hardStop: return "exclamationmark.octagon.fill"
        }
    }
}
