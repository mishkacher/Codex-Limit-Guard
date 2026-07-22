import AppKit
import SwiftUI

@main
struct CodexLimitGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Codex Limit Guard", id: "dashboard") {
            DashboardView()
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 620)
                .onAppear { model.start() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1080, height: 720)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.menuBarSymbol)
                Text(model.menuBarText)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 620, height: 590)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
