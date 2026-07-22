import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        SettingsForm(settings: model.settings)
            .environmentObject(model)
    }
}

private struct SettingsForm: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Protection thresholds") {
                ThresholdRow(title: "Warning", value: $settings.warningRemaining, tint: .yellow, detail: "Send notifications")
                ThresholdRow(title: "Block", value: $settings.blockRemaining, tint: .orange, detail: "Prevent new tasks")
                ThresholdRow(title: "Soft stop", value: $settings.softStopRemaining, tint: .pink, detail: "Press Stop through Accessibility")
                ThresholdRow(title: "Hard stop", value: $settings.hardStopRemaining, tint: .red, detail: "Force-terminate target apps")
                ThresholdRow(title: "Recovery", value: $settings.recoveryRemaining, tint: .green, detail: "Release the new-task block")
                Text("Required order: hard ≤ soft ≤ block < recovery ≤ warning.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Monitoring and actions") {
                LabeledContent("Polling interval") {
                    HStack {
                        Slider(value: $settings.pollingSeconds, in: 10...120, step: 5)
                        Text("\(Int(settings.pollingSeconds))s").monospacedDigit().frame(width: 42)
                    }
                    .frame(width: 260)
                }
                Toggle("Close idle Codex/ChatGPT at the block threshold", isOn: $settings.closeIdleApplications)
                Toggle("Enable emergency hard stop", isOn: $settings.hardStopEnabled)
                Toggle("macOS notifications", isOn: $settings.notificationsEnabled)
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { model.applyLaunchAtLogin($0) }
                ))
            }

            Section("Accessibility") {
                HStack {
                    Label(model.accessibilityTrusted ? "Permission granted" : "Permission required", systemImage: model.accessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundStyle(model.accessibilityTrusted ? .green : .orange)
                    Spacer()
                    Button("Open permission prompt") { model.requestAccessibilityPermission() }
                }
                Text("The app only searches exact Codex/ChatGPT GUI processes for Stop controls. It does not read conversation text.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Telegram") {
                Toggle("Telegram notifications", isOn: $settings.telegramEnabled)
                SecureField("Bot token", text: $model.telegramTokenDraft)
                TextField("Chat ID", text: $settings.telegramChatID)
                HStack {
                    Button("Save token to Keychain") { model.saveTelegramToken() }
                    Button("Send test") { model.testTelegram() }
                        .disabled(settings.telegramChatID.isEmpty)
                }
            }

            HStack {
                Button("Restore defaults") { settings.restoreDefaults() }
                Spacer()
                if let message = model.transientMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(18)
    }
}

private struct ThresholdRow: View {
    let title: String
    @Binding var value: Double
    let tint: Color
    let detail: String

    var body: some View {
        LabeledContent {
            HStack(spacing: 12) {
                Slider(value: $value, in: 1...40, step: 1).tint(tint)
                Text("\(Int(value))%")
                    .font(.body.monospacedDigit())
                    .frame(width: 42, alignment: .trailing)
            }
            .frame(width: 280)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
