import AppKit
import ApplicationServices
import Foundation
import CodexLimitGuardCore

final class AccessibilityController {
    private let exactBundleIdentifiers: Set<String> = [
        "com.openai.chat",
        "com.openai.chatgpt",
        "com.openai.codex"
    ]
    private let exactBundleNames: Set<String> = ["ChatGPT.app", "Codex.app"]
    private let stopWords: Set<String> = [
        "stop", "cancel", "interrupt",
        "остановить", "отменить", "прервать"
    ]
    private let idleActionWords: Set<String> = [
        "send", "submit", "run",
        "отправить", "запустить"
    ]
    private let maximumVisitedNodes = 2_500

    var isTrusted: Bool { AXIsProcessTrusted() }

    func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func observe() -> ActivityObservation {
        let apps = targetApplications()
        guard !apps.isEmpty else {
            return ActivityObservation(
                isApplicationRunning: false,
                hasActiveTurnControl: false,
                isInspectionAvailable: isTrusted,
                isIdleStateConfirmed: true
            )
        }
        guard isTrusted else {
            return ActivityObservation(
                isApplicationRunning: true,
                hasActiveTurnControl: false,
                isInspectionAvailable: false,
                isIdleStateConfirmed: false
            )
        }

        let active = apps.contains { findControl(in: $0, matching: stopWords, mustBeEnabled: false) != nil }
        let idle = !active && apps.contains {
            findControl(in: $0, matching: idleActionWords, mustBeEnabled: true) != nil
        }
        return ActivityObservation(
            isApplicationRunning: true,
            hasActiveTurnControl: active,
            isInspectionAvailable: true,
            isIdleStateConfirmed: idle
        )
    }

    @discardableResult
    func requestSoftStop() -> Bool {
        guard isTrusted else { return false }
        for app in targetApplications() {
            if let element = findControl(in: app, matching: stopWords, mustBeEnabled: false),
               AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
                return true
            }
        }
        return sendEscapeToFrontmostTarget()
    }

    @discardableResult
    func closeIdleApplications() -> Int {
        guard isTrusted else { return 0 }
        var closed = 0
        for app in targetApplications() {
            let hasStop = findControl(in: app, matching: stopWords, mustBeEnabled: false) != nil
            let hasIdleAction = findControl(in: app, matching: idleActionWords, mustBeEnabled: true) != nil
            guard !hasStop, hasIdleAction else { continue }
            if app.terminate() { closed += 1 }
        }
        return closed
    }

    @discardableResult
    func emergencyTerminateApplications() -> Int {
        let apps = targetApplications()
        guard !apps.isEmpty else { return 0 }
        for app in apps { _ = app.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            for app in apps where !app.isTerminated { _ = app.forceTerminate() }
        }
        return apps.count
    }

    private func targetApplications() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { app in
            guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
            if let bundle = app.bundleIdentifier, exactBundleIdentifiers.contains(bundle) { return true }
            guard app.bundleIdentifier == nil,
                  let bundleName = app.bundleURL?.lastPathComponent else { return false }
            return exactBundleNames.contains(bundleName)
        }
    }

    private func findControl(
        in app: NSRunningApplication,
        matching words: Set<String>,
        mustBeEnabled: Bool
    ) -> AXUIElement? {
        let root = AXUIElementCreateApplication(app.processIdentifier)
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var cursor = 0
        var visited = 0

        while cursor < queue.count, visited < maximumVisitedNodes {
            let (element, depth) = queue[cursor]
            cursor += 1
            visited += 1

            if isMatchingControl(element, words: words, mustBeEnabled: mustBeEnabled) { return element }
            guard depth < 14 else { continue }
            for child in children(of: element) { queue.append((child, depth + 1)) }
        }
        return nil
    }

    private func isMatchingControl(
        _ element: AXUIElement,
        words: Set<String>,
        mustBeEnabled: Bool
    ) -> Bool {
        let role = stringAttribute(kAXRoleAttribute, element: element)?.lowercased() ?? ""
        guard role.contains("button") || role.contains("control") else { return false }
        if mustBeEnabled, boolAttribute(kAXEnabledAttribute, element: element) != true { return false }

        let values = [
            stringAttribute(kAXTitleAttribute, element: element),
            stringAttribute(kAXDescriptionAttribute, element: element),
            stringAttribute(kAXIdentifierAttribute, element: element),
            stringAttribute(kAXValueAttribute, element: element)
        ]
        return values
            .compactMap { $0?.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .contains { text in words.contains(text) || words.contains(where: { text.contains($0) }) }
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else {
            return []
        }
        return value as? [AXUIElement] ?? []
    }

    private func stringAttribute(_ name: String, element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func boolAttribute(_ name: String, element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? Bool
    }

    private func sendEscapeToFrontmostTarget() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              targetApplications().contains(where: { $0.processIdentifier == app.processIdentifier }),
              let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: false) else {
            return false
        }
        down.postToPid(app.processIdentifier)
        up.postToPid(app.processIdentifier)
        return true
    }
}
