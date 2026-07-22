import XCTest
@testable import CodexLimitGuardCore

final class GuardPolicyTests: XCTestCase {
    private func snapshot(remaining: Double) -> RateLimitSnapshot {
        RateLimitSnapshot(windows: [
            QuotaWindow(
                bucketID: "codex",
                kind: .primary,
                usedPercent: 100 - remaining,
                windowDurationMinutes: 300,
                resetsAt: Date().addingTimeInterval(3600)
            )
        ])
    }

    func testWarnsAtTwentyPercent() throws {
        var machine = try GuardStateMachine()
        let result = machine.evaluate(snapshot: snapshot(remaining: 20), activity: .init(isApplicationRunning: true, hasActiveTurnControl: false))
        XCTAssertEqual(result.level, .warning)
        XCTAssertTrue(result.actions.contains(.notify(level: .warning, remaining: 20)))
    }

    func testAllowsOneExistingTaskAtBlockThreshold() throws {
        var machine = try GuardStateMachine()
        let result = machine.evaluate(snapshot: snapshot(remaining: 15), activity: .init(isApplicationRunning: true, hasActiveTurnControl: true))
        XCTAssertTrue(result.graceTaskInProgress)
        XCTAssertTrue(result.actions.contains(.markGraceTask))
        XCTAssertFalse(result.actions.contains { if case .requestSoftStop = $0 { return true }; return false })
    }

    func testArmsBlockAfterGraceTaskCompletes() throws {
        var machine = try GuardStateMachine()
        _ = machine.evaluate(snapshot: snapshot(remaining: 15), activity: .init(isApplicationRunning: true, hasActiveTurnControl: true))
        let result = machine.evaluate(
            snapshot: snapshot(remaining: 14.5),
            activity: .init(
                isApplicationRunning: true,
                hasActiveTurnControl: false,
                isInspectionAvailable: true,
                isIdleStateConfirmed: true
            )
        )
        XCTAssertTrue(result.newTaskBlockArmed)
        XCTAssertTrue(result.actions.contains(.armNewTaskBlock))
        XCTAssertTrue(result.actions.contains(.closeIdleApplications))
    }

    func testStopsNewTaskWhenBlockArmed() throws {
        var machine = try GuardStateMachine()
        _ = machine.evaluate(snapshot: snapshot(remaining: 15), activity: .init(isApplicationRunning: false, hasActiveTurnControl: false))
        let result = machine.evaluate(snapshot: snapshot(remaining: 14), activity: .init(isApplicationRunning: true, hasActiveTurnControl: true))
        XCTAssertTrue(result.actions.contains { if case .requestSoftStop = $0 { return true }; return false })
    }

    func testSoftStopAtTwelvePercent() throws {
        var machine = try GuardStateMachine()
        let result = machine.evaluate(snapshot: snapshot(remaining: 12), activity: .init(isApplicationRunning: true, hasActiveTurnControl: true))
        XCTAssertEqual(result.level, .softStop)
        XCTAssertTrue(result.actions.contains { if case .requestSoftStop = $0 { return true }; return false })
    }

    func testHardStopAtTenPercent() throws {
        var machine = try GuardStateMachine()
        let result = machine.evaluate(snapshot: snapshot(remaining: 10), activity: .init(isApplicationRunning: true, hasActiveTurnControl: true))
        XCTAssertEqual(result.level, .hardStop)
        XCTAssertTrue(result.actions.contains { if case .forceTerminate = $0 { return true }; return false })
    }

    func testRecoveryUsesHysteresis() throws {
        var machine = try GuardStateMachine()
        _ = machine.evaluate(snapshot: snapshot(remaining: 10), activity: .init(isApplicationRunning: true, hasActiveTurnControl: true))
        let stillBlocked = machine.evaluate(snapshot: snapshot(remaining: 17), activity: .init(isApplicationRunning: false, hasActiveTurnControl: false))
        XCTAssertNotEqual(stillBlocked.level, .healthy)
        let recovered = machine.evaluate(snapshot: snapshot(remaining: 18), activity: .init(isApplicationRunning: false, hasActiveTurnControl: false))
        XCTAssertEqual(recovered.level, .warning)
        XCTAssertTrue(recovered.actions.contains(.recovered))
    }

    func testInvalidThresholdOrderingIsRejected() {
        XCTAssertThrowsError(try GuardStateMachine(thresholds: .init(warningRemaining: 10, blockRemaining: 15)))
    }
    func testWarningNotificationRearmsAfterHealthyRecovery() throws {
        var machine = try GuardStateMachine()
        let idle = ActivityObservation(isApplicationRunning: false, hasActiveTurnControl: false)

        let firstWarning = machine.evaluate(snapshot: snapshot(remaining: 20), activity: idle)
        XCTAssertTrue(firstWarning.actions.contains(.notify(level: .warning, remaining: 20)))

        _ = machine.evaluate(snapshot: snapshot(remaining: 30), activity: idle)
        let secondWarning = machine.evaluate(snapshot: snapshot(remaining: 20), activity: idle)
        XCTAssertTrue(secondWarning.actions.contains(.notify(level: .warning, remaining: 20)))
    }

    func testUnknownInspectionDoesNotCloseApplicationAtBlockThreshold() throws {
        var machine = try GuardStateMachine()
        let unknown = ActivityObservation(
            isApplicationRunning: true,
            hasActiveTurnControl: false,
            isInspectionAvailable: false,
            isIdleStateConfirmed: false
        )

        let result = machine.evaluate(snapshot: snapshot(remaining: 15), activity: unknown)
        XCTAssertTrue(result.actions.contains(.armNewTaskBlock))
        XCTAssertFalse(result.actions.contains(.closeIdleApplications))
    }

    func testConfirmedIdleCanBeClosedAtBlockThreshold() throws {
        var machine = try GuardStateMachine()
        let idle = ActivityObservation(
            isApplicationRunning: true,
            hasActiveTurnControl: false,
            isInspectionAvailable: true,
            isIdleStateConfirmed: true
        )

        let result = machine.evaluate(snapshot: snapshot(remaining: 15), activity: idle)
        XCTAssertTrue(result.actions.contains(.closeIdleApplications))
    }

}
