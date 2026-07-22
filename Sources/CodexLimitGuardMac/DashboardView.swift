import SwiftUI
import CodexLimitGuardCore

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            ZStack {
                MeshBackground(level: model.level)
                Group {
                    switch model.selectedSection {
                    case .overview: OverviewView()
                    case .activity: ActivityView()
                    case .settings: SettingsView()
                    case .about: AboutView()
                    }
                }
                .padding(28)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackground(.hidden, for: .windowToolbar)
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 23, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Codex Limit Guard").font(.headline)
                    Text(model.connectionLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            List(SidebarSection.allCases, selection: $model.selectedSection) { section in
                Label(section.rawValue, systemImage: section.symbol)
                    .tag(section)
                    .padding(.vertical, 5)
            }
            .scrollContentBackground(.hidden)

            VStack(spacing: 10) {
                HStack {
                    Circle()
                        .fill(model.accessibilityTrusted ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(model.accessibilityTrusted ? "Accessibility ready" : "Permission required")
                        .font(.caption)
                    Spacer()
                }
                Button(model.isPaused ? "Resume protection" : "Pause protection") {
                    model.isPaused.toggle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(model.isPaused ? .orange : .accentColor)
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(12)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 280)
    }
}

private struct OverviewView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                HStack(alignment: .top, spacing: 22) {
                    StatusRingView(
                        remaining: model.minimumRemaining,
                        level: model.level,
                        title: model.statusTitle
                    )
                    .frame(width: 300, height: 300)

                    VStack(spacing: 16) {
                        ConnectionCard()
                        ActivityCard()
                        ProtectionCard()
                    }
                    .frame(maxWidth: .infinity)
                }

                QuotaWindowsView()
                HybridLadderView()
                RecentEventsView(limit: 5)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Quota protection").font(.largeTitle.weight(.semibold))
                Text("Live Codex usage, graceful task blocking, and emergency protection.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.refreshNow()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Button {
                model.performManualSoftStop()
            } label: {
                Label("Stop Codex", systemImage: "stop.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

private struct ConnectionCard: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        MetricCard(
            title: "Connection",
            value: model.connectionLabel,
            detail: "Official Codex app-server",
            symbol: "point.3.connected.trianglepath.dotted",
            accent: model.connectionState == .connected ? .green : .orange
        )
    }
}

private struct ActivityCard: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        MetricCard(
            title: "Codex activity",
            value: model.activity.hasActiveTurnControl ? "Task running" : (model.activity.isApplicationRunning ? "Idle" : "Closed"),
            detail: model.accessibilityTrusted ? "Observed through Accessibility" : "Grant Accessibility permission",
            symbol: model.activity.hasActiveTurnControl ? "bolt.horizontal.circle.fill" : "moon.zzz",
            accent: model.activity.hasActiveTurnControl ? .blue : .secondary
        )
    }
}

private struct ProtectionCard: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        MetricCard(
            title: "Protection",
            value: model.isPaused ? "Paused" : "Active",
            detail: "20 · 15 · 12 · 10% policy",
            symbol: model.isPaused ? "pause.circle.fill" : "shield.checkered",
            accent: model.isPaused ? .orange : .green
        )
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.14))
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.title3.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.08)))
    }
}

private struct QuotaWindowsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Quota windows", subtitle: "The window with the least remaining capacity controls protection.")
            if let windows = model.snapshot?.windows, !windows.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                    ForEach(windows) { window in
                        QuotaWindowCard(window: window, limiting: window.id == model.snapshot?.limitingWindow?.id)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Waiting for Codex usage")
                        .font(.headline)
                    Text("Sign in to Codex and keep the CLI available in PATH.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}

private struct QuotaWindowCard: View {
    let window: QuotaWindow
    let limiting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(window.displayName).font(.headline)
                    Text(window.kind.rawValue.capitalized + " · " + durationText(window.windowDurationMinutes))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if limiting {
                    Text("LIMITING")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.16), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(Int(window.remainingPercent.rounded()))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("% remaining").foregroundStyle(.secondary)
            }
            ProgressView(value: window.remainingPercent, total: 100)
                .tint(progressColor(window.remainingPercent))
            Text("Resets \(window.resetsAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(limiting ? Color.orange.opacity(0.45) : .white.opacity(0.07), lineWidth: limiting ? 1.5 : 1))
    }

    private func durationText(_ minutes: Int) -> String {
        if minutes >= 10_080 { return "\(minutes / 10_080) week" + (minutes >= 20_160 ? "s" : "") }
        if minutes >= 1_440 { return "\(minutes / 1_440) day" + (minutes >= 2_880 ? "s" : "") }
        if minutes >= 60 { return "\(minutes / 60)h" }
        return "\(minutes)m"
    }

    private func progressColor(_ remaining: Double) -> Color {
        if remaining <= 10 { return .red }
        if remaining <= 15 { return .orange }
        if remaining <= 20 { return .yellow }
        return .green
    }
}

private struct HybridLadderView: View {
    private let steps: [(String, String, String, Color)] = [
        ("20%", "Warn", "macOS + Telegram notification", .yellow),
        ("15%", "Block", "Allow one existing task, then prevent new work", .orange),
        ("12%", "Soft stop", "Press Stop through Accessibility, then Escape", .pink),
        ("10%", "Emergency", "Force-terminate only Codex/ChatGPT GUI apps", .red)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Hybrid stop ladder", subtitle: "Escalation is deliberate, reversible, and limited to exact target applications.")
            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(step.3.opacity(0.17))
                            Text(step.0).font(.headline.monospacedDigit()).foregroundStyle(step.3)
                        }
                        .frame(width: 58, height: 58)
                        Text(step.1).font(.headline)
                        Text(step.2).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            .frame(maxWidth: 170)
                    }
                    .frame(maxWidth: .infinity)
                    if index < steps.count - 1 {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(22)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

private struct RecentEventsView: View {
    @EnvironmentObject private var model: AppModel
    let limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Recent activity", subtitle: "Tokens and secrets are redacted before events are written to disk.")
            VStack(spacing: 0) {
                ForEach(Array(model.events.prefix(limit))) { event in
                    EventRow(event: event)
                    if event.id != model.events.prefix(limit).last?.id { Divider().opacity(0.35) }
                }
                if model.events.isEmpty {
                    Text("No guard events yet.").foregroundStyle(.secondary).padding(24)
                }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

struct ActivityView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "Activity log", subtitle: "Local, redacted history of warnings, actions, and recoveries.")
            List(model.events) { event in
                EventRow(event: event)
                    .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
        }
    }
}

private struct EventRow: View {
    let event: EventRecord
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title).font(.subheadline.weight(.semibold))
                Text(event.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Text(event.timestamp, style: .time).font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }

    private var symbol: String {
        switch event.kind {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .action: return "bolt.shield.fill"
        case .error: return "xmark.octagon.fill"
        case .recovered: return "arrow.up.heart.fill"
        }
    }
    private var color: Color {
        switch event.kind {
        case .info: return .blue
        case .warning: return .orange
        case .action: return .purple
        case .error: return .red
        case .recovered: return .green
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title2.weight(.semibold))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

private struct MeshBackground: View {
    let level: GuardLevel
    var body: some View {
        LinearGradient(
            colors: [accent.opacity(0.13), Color.clear, Color.accentColor.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .background(.regularMaterial)
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
}
