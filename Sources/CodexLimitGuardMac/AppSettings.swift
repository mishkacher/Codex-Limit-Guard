import Combine
import Foundation
import CodexLimitGuardCore

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let warning = "threshold.warning"
        static let block = "threshold.block"
        static let soft = "threshold.soft"
        static let hard = "threshold.hard"
        static let recovery = "threshold.recovery"
        static let polling = "monitor.polling"
        static let telegramChatID = "telegram.chatID"
        static let telegramEnabled = "telegram.enabled"
        static let notificationsEnabled = "notifications.enabled"
        static let closeIdle = "actions.closeIdle"
        static let hardStopEnabled = "actions.hardStop"
        static let launchAtLogin = "launchAtLogin"
    }

    private let defaults: UserDefaults

    @Published var warningRemaining: Double { didSet { defaults.set(warningRemaining, forKey: Key.warning) } }
    @Published var blockRemaining: Double { didSet { defaults.set(blockRemaining, forKey: Key.block) } }
    @Published var softStopRemaining: Double { didSet { defaults.set(softStopRemaining, forKey: Key.soft) } }
    @Published var hardStopRemaining: Double { didSet { defaults.set(hardStopRemaining, forKey: Key.hard) } }
    @Published var recoveryRemaining: Double { didSet { defaults.set(recoveryRemaining, forKey: Key.recovery) } }
    @Published var pollingSeconds: Double { didSet { defaults.set(pollingSeconds, forKey: Key.polling) } }
    @Published var telegramChatID: String { didSet { defaults.set(telegramChatID, forKey: Key.telegramChatID) } }
    @Published var telegramEnabled: Bool { didSet { defaults.set(telegramEnabled, forKey: Key.telegramEnabled) } }
    @Published var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: Key.notificationsEnabled) } }
    @Published var closeIdleApplications: Bool { didSet { defaults.set(closeIdleApplications, forKey: Key.closeIdle) } }
    @Published var hardStopEnabled: Bool { didSet { defaults.set(hardStopEnabled, forKey: Key.hardStopEnabled) } }
    @Published var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        warningRemaining = defaults.object(forKey: Key.warning) as? Double ?? 20
        blockRemaining = defaults.object(forKey: Key.block) as? Double ?? 15
        softStopRemaining = defaults.object(forKey: Key.soft) as? Double ?? 12
        hardStopRemaining = defaults.object(forKey: Key.hard) as? Double ?? 10
        recoveryRemaining = defaults.object(forKey: Key.recovery) as? Double ?? 18
        pollingSeconds = defaults.object(forKey: Key.polling) as? Double ?? 30
        telegramChatID = defaults.string(forKey: Key.telegramChatID) ?? ""
        telegramEnabled = defaults.object(forKey: Key.telegramEnabled) as? Bool ?? false
        notificationsEnabled = defaults.object(forKey: Key.notificationsEnabled) as? Bool ?? true
        closeIdleApplications = defaults.object(forKey: Key.closeIdle) as? Bool ?? true
        hardStopEnabled = defaults.object(forKey: Key.hardStopEnabled) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Key.launchAtLogin) as? Bool ?? false
    }

    var thresholds: GuardThresholds {
        GuardThresholds(
            warningRemaining: warningRemaining,
            blockRemaining: blockRemaining,
            softStopRemaining: softStopRemaining,
            hardStopRemaining: hardStopRemaining,
            recoveryRemaining: recoveryRemaining
        )
    }

    func restoreDefaults() {
        warningRemaining = 20
        blockRemaining = 15
        softStopRemaining = 12
        hardStopRemaining = 10
        recoveryRemaining = 18
        pollingSeconds = 30
        closeIdleApplications = true
        hardStopEnabled = true
    }
}
