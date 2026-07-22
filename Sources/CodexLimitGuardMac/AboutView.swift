import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(LinearGradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                            .font(.system(size: 54, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 112, height: 112)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Codex Limit Guard").font(.largeTitle.weight(.bold))
                        Text("Native, local-first quota protection for Codex on macOS.")
                            .font(.title3).foregroundStyle(.secondary)
                        Text("Open source · MIT License").font(.caption).foregroundStyle(.tertiary)
                    }
                }

                GroupBox("Privacy by design") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("No telemetry and no analytics", systemImage: "eye.slash.fill")
                        Label("No OpenAI credentials stored by the app", systemImage: "key.slash")
                        Label("Telegram token stored in macOS Keychain", systemImage: "lock.shield.fill")
                        Label("Logs are local and secret-redacted", systemImage: "doc.text.magnifyingglass")
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("How it works") {
                    Text("The guard starts the official Codex app-server over local stdio, reads account/rateLimits/read and account/rateLimits/updated, then applies a deterministic threshold policy. Accessibility is used only to detect and press task-stop controls in exact Codex/ChatGPT GUI applications.")
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
