import AppKit
import Combine
import Foundation
import CodexLimitGuardCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: RateLimitSnapshot?
    @Published private(set) var level: GuardLevel = .healthy
    @Published private(set) var connectionState: CodexAppServerClient.ConnectionState = .stopped
    @Published private(set) var activity = ActivityObservation(isApplicationRunning: false, hasActiveTurnControl: false)
    @Published private(set) var events: [EventRecord] = []
    @Published private(set) var accessibilityTrusted = false
    @Published var isPaused = false
    @Published var selectedSection: SidebarSection = .overview
    @Published var telegramTokenDraft = ""
    @Published var transientMessage: String?

    let settings = AppSettings()

    private let client = CodexAppServerClient()
    private let accessibility = AccessibilityController()
    private let notifications = NotificationService()
    private let telegram = TelegramNotifier()
    private let keychain = KeychainStore()
    private let eventLogger = EventLogger()
    private let launchAtLogin = LaunchAtLoginController()
    private var machine: GuardStateMachine
    private var activityTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var started = false
    private var lastActionAt: [ActionThrottleKey: Date] = [:]

    init() {
        do {
            machine = try GuardStateMachine(thresholds: settings.thresholds)
        } catch {
            // Defaults are validated by the core package; this branch is defensive.
            machine = GuardStateMachine.validatedDefaults()
        }
        events = eventLogger.loadRecent()
        telegramTokenDraft = (try? keychain.get(account: "telegram.bot-token")) ?? ""
        bindSettings()
        bindClient()
        start()
    }

    func start() {
        guard !started else { return }
        started = true
        notifications.requestAuthorization()
        accessibilityTrusted = accessibility.isTrusted
        client.start(pollingInterval: settings.pollingSeconds)
        startActivityTimer()
        log(.info, "Guard started", "Monitoring all Codex quota windows.")
    }

    func stop() {
        started = false
        activityTimer?.invalidate()
        activityTimer = nil
        client.stop()
        log(.info, "Guard stopped", "Monitoring has been disabled.")
    }

    func refreshNow() {
        client.refreshNow()
        sampleActivityAndEvaluate()
    }

    func requestAccessibilityPermission() {
        accessibility.requestPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.accessibilityTrusted = self.accessibility.isTrusted
        }
    }

    func saveTelegramToken() {
        do {
            let token = telegramTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.isEmpty {
                try keychain.delete(account: "telegram.bot-token")
                transientMessage = "Telegram token removed from Keychain."
            } else {
                try keychain.set(token, account: "telegram.bot-token")
                transientMessage = "Telegram token saved securely in Keychain."
            }
        } catch {
            transientMessage = error.localizedDescription
            log(.error, "Keychain error", error.localizedDescription)
        }
    }

    func testTelegram() {
        Task {
            do {
                let token = try keychain.get(account: "telegram.bot-token") ?? telegramTokenDraft
                try await telegram.send(
                    token: token,
                    chatID: settings.telegramChatID,
                    text: "Codex Limit Guard is connected. Telegram notifications are working."
                )
                transientMessage = "Telegram test sent."
            } catch {
                transientMessage = error.localizedDescription
                log(.error, "Telegram test failed", error.localizedDescription)
            }
        }
    }

    func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLogin.setEnabled(enabled)
            settings.launchAtLogin = launchAtLogin.isEnabled
            transientMessage = enabled ? "Launch at login enabled." : "Launch at login disabled."
        } catch {
            settings.launchAtLogin = launchAtLogin.isEnabled
            transientMessage = "Launch-at-login could not be changed: \(error.localizedDescription)"
            log(.error, "Launch at login", error.localizedDescription)
        }
    }

    func performManualSoftStop() {
        let succeeded = accessibility.requestSoftStop()
        log(succeeded ? .action : .error, "Manual soft stop", succeeded ? "Stop control was activated." : "No accessible Stop control was found.")
    }

    func quit() { NSApp.terminate(nil) }

    var minimumRemaining: Double? { snapshot?.minimumRemainingPercent }
    var menuBarText: String { minimumRemaining.map { "\(Int($0.rounded()))%" } ?? "—" }
    var menuBarSymbol: String {
        switch level {
        case .healthy: return "shield.checkered"
        case .warning: return "shield.lefthalf.filled"
        case .blocking: return "shield.slash"
        case .softStop: return "hand.raised.fill"
        case .hardStop: return "exclamationmark.octagon.fill"
        }
    }

    var connectionLabel: String {
        switch connectionState {
        case .stopped: return "Stopped"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .unavailable: return "Unavailable"
        }
    }

    var statusTitle: String {
        if isPaused { return "Protection paused" }
        switch level {
        case .healthy: return "Quota is healthy"
        case .warning: return "Quota is getting low"
        case .blocking: return "New tasks are blocked"
        case .softStop: return "Soft stop active"
        case .hardStop: return "Emergency stop active"
        }
    }

    private func bindSettings() {
        settings.objectWillChange
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.rebuildPolicy()
                self.client.updatePollingInterval(self.settings.pollingSeconds)
            }
            .store(in: &cancellables)
    }

    private func bindClient() {
        client.onSnapshot = { [weak self] snapshot in
            guard let self else { return }
            self.snapshot = snapshot
            self.evaluate()
        }
        client.onState = { [weak self] state in
            guard let self else { return }
            self.connectionState = state
            if case .unavailable(let detail) = state {
                self.log(.error, "Codex connection unavailable", detail)
            }
        }
        client.onDiagnostic = { [weak self] detail in
            self?.log(.error, "Codex app-server", detail)
        }
    }

    private func rebuildPolicy() {
        do {
            machine = try GuardStateMachine(thresholds: settings.thresholds)
            transientMessage = nil
            evaluate()
        } catch {
            transientMessage = "Threshold order is invalid. Expected: hard ≤ soft ≤ block < recovery ≤ warning."
        }
    }

    private func startActivityTimer() {
        activityTimer?.invalidate()
        activityTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleActivityAndEvaluate() }
        }
        RunLoop.main.add(activityTimer!, forMode: .common)
    }

    private func sampleActivityAndEvaluate() {
        accessibilityTrusted = accessibility.isTrusted
        activity = accessibility.observe()
        evaluate()
    }

    private func evaluate() {
        guard !isPaused else { return }
        guard isSnapshotFresh else { return }
        let evaluation = machine.evaluate(snapshot: snapshot, activity: activity)
        level = evaluation.level
        for action in evaluation.actions { execute(action) }
    }

    private func execute(_ action: GuardAction) {
        switch action {
        case .notify(let level, let remaining):
            let message = notificationText(level: level, remaining: remaining)
            log(level >= .blocking ? .warning : .info, "Quota \(Int(remaining.rounded()))% remaining", message, remaining: remaining)
            sendNotification(title: statusTitle, body: message, critical: level >= .softStop)
        case .markGraceTask:
            log(.info, "Existing task protected", "The task already running at the 15% boundary may finish once.")
        case .armNewTaskBlock:
            log(.action, "New-task block armed", "Any new active Codex task will be stopped until quota recovery.")
        case .closeIdleApplications:
            guard settings.closeIdleApplications, shouldRun(.closeIdle, every: 20) else { return }
            guard accessibilityTrusted else {
                log(.warning, "Idle close skipped", "Accessibility permission is required to prove the target app is idle.")
                return
            }
            let count = accessibility.closeIdleApplications()
            if count > 0 {
                log(.action, "Idle Codex closed", "Closed \(count) idle target application(s) to prevent a new task.")
            }
        case .requestSoftStop(let reason):
            guard shouldRun(.softStop, every: 12) else { return }
            let success = accessibility.requestSoftStop()
            log(success ? .action : .error, "Soft stop requested", success ? reason : "\(reason). Accessibility permission or a matching Stop control is unavailable.")
        case .forceTerminate(let reason):
            guard settings.hardStopEnabled else {
                log(.warning, "Hard stop suppressed", "\(reason). Hard stop is disabled in settings.")
                return
            }
            guard shouldRun(.hardStop, every: 30) else { return }
            let count = accessibility.emergencyTerminateApplications()
            if count > 0 {
                log(.action, "Emergency stop", "\(reason). Termination was requested for \(count) exact target application(s).")
            }
        case .recovered:
            log(.recovered, "Quota recovered", "New tasks are allowed again; warning state may remain until quota exceeds 20%.")
            sendNotification(title: "Codex quota recovered", body: "The task block has been released.", critical: false)
        }
    }

    private var isSnapshotFresh: Bool {
        guard let snapshot else { return false }
        let maximumAge = max(120, settings.pollingSeconds * 3)
        return Date().timeIntervalSince(snapshot.receivedAt) <= maximumAge
    }

    private func shouldRun(_ key: ActionThrottleKey, every interval: TimeInterval) -> Bool {
        let now = Date()
        if let last = lastActionAt[key], now.timeIntervalSince(last) < interval { return false }
        lastActionAt[key] = now
        return true
    }

    private func notificationText(level: GuardLevel, remaining: Double) -> String {
        switch level {
        case .healthy: return "Codex usage is within the configured safety range."
        case .warning: return "Only \(Int(remaining.rounded()))% remains. Finish or shorten current work."
        case .blocking: return "New Codex tasks are blocked. One task already running at the boundary may finish."
        case .softStop: return "The current Codex task is being stopped through Accessibility."
        case .hardStop: return "Codex/ChatGPT is being force-terminated to preserve the remaining quota."
        }
    }

    private func sendNotification(title: String, body: String, critical: Bool) {
        if settings.notificationsEnabled {
            notifications.send(title: title, body: body, critical: critical)
        }
        guard settings.telegramEnabled else { return }
        Task {
            do {
                let token = try keychain.get(account: "telegram.bot-token") ?? ""
                try await telegram.send(token: token, chatID: settings.telegramChatID, text: "\(title)\n\(body)")
            } catch {
                log(.error, "Telegram notification failed", error.localizedDescription)
            }
        }
    }

    private func log(_ kind: EventRecord.Kind, _ title: String, _ detail: String, remaining: Double? = nil) {
        let event = EventRecord(kind: kind, title: title, detail: detail, remainingPercent: remaining)
        events.insert(event, at: 0)
        if events.count > 150 { events.removeLast(events.count - 150) }
        eventLogger.write(event)
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case activity = "Activity"
    case settings = "Settings"
    case about = "About"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.67percent"
        case .activity: return "waveform.path.ecg"
        case .settings: return "slider.horizontal.3"
        case .about: return "info.circle"
        }
    }
}

private enum ActionThrottleKey: Hashable {
    case closeIdle
    case softStop
    case hardStop
}
