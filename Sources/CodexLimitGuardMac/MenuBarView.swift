import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.14))
                    Image(systemName: model.menuBarSymbol).font(.title2).foregroundStyle(Color.accentColor)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.statusTitle).font(.headline)
                    Text(model.connectionLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(model.menuBarText.replacingOccurrences(of: "%", with: ""))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("% remaining").foregroundStyle(.secondary)
            }

            if let window = model.snapshot?.limitingWindow {
                ProgressView(value: window.remainingPercent, total: 100)
                Text("\(window.displayName) · resets \(window.resetsAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()
            HStack {
                Button("Open dashboard") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "dashboard")
                }
                .buttonStyle(.borderedProminent)
                Button { model.refreshNow() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.bordered)
                Spacer()
                Button { model.isPaused.toggle() } label: {
                    Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button("Stop Codex now") { model.performManualSoftStop() }
                Spacer()
                Button("Quit") { model.quit() }
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 330)
    }
}
