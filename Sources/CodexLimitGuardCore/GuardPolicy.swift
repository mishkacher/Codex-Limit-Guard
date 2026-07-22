import Foundation

public struct GuardStateMachine: Sendable {
    public private(set) var level: GuardLevel = .healthy
    public private(set) var graceTaskInProgress = false
    public private(set) var newTaskBlockArmed = false
    public private(set) var lastNotifiedLevel: GuardLevel?
    public let thresholds: GuardThresholds

    public init(thresholds: GuardThresholds = GuardThresholds()) throws {
        self.thresholds = try thresholds.validated()
    }

    private init(uncheckedThresholds: GuardThresholds) {
        self.thresholds = uncheckedThresholds
    }

    public mutating func evaluate(
        snapshot: RateLimitSnapshot?,
        activity: ActivityObservation
    ) -> GuardEvaluation {
        guard let remaining = snapshot?.minimumRemainingPercent else {
            return GuardEvaluation(
                level: level,
                actions: [],
                remainingPercent: nil,
                graceTaskInProgress: graceTaskInProgress,
                newTaskBlockArmed: newTaskBlockArmed
            )
        }

        var actions: [GuardAction] = []

        if level >= .blocking, remaining >= thresholds.recoveryRemaining {
            level = remaining <= thresholds.warningRemaining ? .warning : .healthy
            graceTaskInProgress = false
            newTaskBlockArmed = false
            lastNotifiedLevel = level == .warning ? .warning : nil
            actions.append(.recovered)
            return result(actions, remaining)
        }

        let target = levelFor(remaining: remaining)
        if level >= .blocking, remaining < thresholds.recoveryRemaining {
            level = max(target, .blocking)
        } else {
            level = target
        }

        if level == .healthy {
            lastNotifiedLevel = nil
        } else if lastNotifiedLevel != level {
            actions.append(.notify(level: level, remaining: remaining))
            lastNotifiedLevel = level
        }

        if level >= .hardStop {
            graceTaskInProgress = false
            newTaskBlockArmed = true
            if activity.isApplicationRunning {
                actions.append(.forceTerminate(reason: "Codex quota reached hard-stop threshold"))
            }
            return result(actions, remaining)
        }

        if level >= .softStop {
            graceTaskInProgress = false
            newTaskBlockArmed = true
            if activity.hasActiveTurnControl {
                actions.append(.requestSoftStop(reason: "Codex quota reached soft-stop threshold"))
            } else if activity.isApplicationRunning, activity.isIdleStateConfirmed {
                actions.append(.closeIdleApplications)
            }
            return result(actions, remaining)
        }

        if level >= .blocking {
            if graceTaskInProgress {
                let completionObserved = !activity.isApplicationRunning ||
                    (activity.isInspectionAvailable && !activity.hasActiveTurnControl)
                if completionObserved {
                    graceTaskInProgress = false
                    newTaskBlockArmed = true
                    actions.append(.armNewTaskBlock)
                    if activity.isApplicationRunning, activity.isIdleStateConfirmed {
                        actions.append(.closeIdleApplications)
                    }
                }
            } else if newTaskBlockArmed {
                if activity.hasActiveTurnControl {
                    actions.append(.requestSoftStop(reason: "New Codex task started while quota block is armed"))
                } else if activity.isApplicationRunning, activity.isIdleStateConfirmed {
                    actions.append(.closeIdleApplications)
                }
            } else if activity.hasActiveTurnControl {
                graceTaskInProgress = true
                actions.append(.markGraceTask)
            } else {
                newTaskBlockArmed = true
                actions.append(.armNewTaskBlock)
                if activity.isApplicationRunning, activity.isIdleStateConfirmed {
                    actions.append(.closeIdleApplications)
                }
            }
        }

        return result(actions, remaining)
    }

    private func levelFor(remaining: Double) -> GuardLevel {
        if remaining <= thresholds.hardStopRemaining { return .hardStop }
        if remaining <= thresholds.softStopRemaining { return .softStop }
        if remaining <= thresholds.blockRemaining { return .blocking }
        if remaining <= thresholds.warningRemaining { return .warning }
        return .healthy
    }

    private func result(_ actions: [GuardAction], _ remaining: Double) -> GuardEvaluation {
        GuardEvaluation(
            level: level,
            actions: actions,
            remainingPercent: remaining,
            graceTaskInProgress: graceTaskInProgress,
            newTaskBlockArmed: newTaskBlockArmed
        )
    }
}

public extension GuardStateMachine {
    /// A non-throwing construction path for the package's compile-time defaults.
    static func validatedDefaults() -> GuardStateMachine {
        GuardStateMachine(uncheckedThresholds: GuardThresholds())
    }
}
