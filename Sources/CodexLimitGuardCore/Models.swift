import Foundation

public enum QuotaWindowKind: String, Codable, CaseIterable, Sendable {
    case primary
    case secondary
}

public struct QuotaWindow: Codable, Hashable, Identifiable, Sendable {
    public let bucketID: String
    public let bucketName: String?
    public let kind: QuotaWindowKind
    public let usedPercent: Double
    public let windowDurationMinutes: Int
    public let resetsAt: Date
    public let planType: String?

    public init(
        bucketID: String,
        bucketName: String? = nil,
        kind: QuotaWindowKind,
        usedPercent: Double,
        windowDurationMinutes: Int,
        resetsAt: Date,
        planType: String? = nil
    ) {
        self.bucketID = bucketID
        self.bucketName = bucketName
        self.kind = kind
        self.usedPercent = max(0, min(100, usedPercent))
        self.windowDurationMinutes = max(0, windowDurationMinutes)
        self.resetsAt = resetsAt
        self.planType = planType
    }

    public var id: String { "\(bucketID):\(kind.rawValue)" }
    public var remainingPercent: Double { max(0, 100 - usedPercent) }
    public var displayName: String { bucketName?.isEmpty == false ? bucketName! : bucketID }
}

public struct RateLimitSnapshot: Codable, Equatable, Sendable {
    public let windows: [QuotaWindow]
    public let resetCreditsAvailable: Int?
    public let receivedAt: Date

    public init(windows: [QuotaWindow], resetCreditsAvailable: Int? = nil, receivedAt: Date = Date()) {
        self.windows = windows.sorted {
            if $0.remainingPercent == $1.remainingPercent {
                return $0.windowDurationMinutes < $1.windowDurationMinutes
            }
            return $0.remainingPercent < $1.remainingPercent
        }
        self.resetCreditsAvailable = resetCreditsAvailable
        self.receivedAt = receivedAt
    }

    public var limitingWindow: QuotaWindow? { windows.first }
    public var minimumRemainingPercent: Double? { limitingWindow?.remainingPercent }
}

public enum GuardLevel: Int, Codable, Comparable, CaseIterable, Sendable {
    case healthy = 0
    case warning = 1
    case blocking = 2
    case softStop = 3
    case hardStop = 4

    public static func < (lhs: GuardLevel, rhs: GuardLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct GuardThresholds: Codable, Equatable, Sendable {
    public var warningRemaining: Double
    public var blockRemaining: Double
    public var softStopRemaining: Double
    public var hardStopRemaining: Double
    public var recoveryRemaining: Double

    public init(
        warningRemaining: Double = 20,
        blockRemaining: Double = 15,
        softStopRemaining: Double = 12,
        hardStopRemaining: Double = 10,
        recoveryRemaining: Double = 18
    ) {
        self.warningRemaining = warningRemaining
        self.blockRemaining = blockRemaining
        self.softStopRemaining = softStopRemaining
        self.hardStopRemaining = hardStopRemaining
        self.recoveryRemaining = recoveryRemaining
    }

    public func validated() throws -> GuardThresholds {
        guard hardStopRemaining >= 0,
              hardStopRemaining <= softStopRemaining,
              softStopRemaining <= blockRemaining,
              blockRemaining < recoveryRemaining,
              recoveryRemaining <= warningRemaining,
              warningRemaining <= 100 else {
            throw GuardConfigurationError.invalidThresholdOrder
        }
        return self
    }
}

public enum GuardConfigurationError: Error, Equatable {
    case invalidThresholdOrder
}

public struct ActivityObservation: Equatable, Sendable {
    public let isApplicationRunning: Bool
    public let hasActiveTurnControl: Bool
    public let isInspectionAvailable: Bool
    public let isIdleStateConfirmed: Bool

    public init(
        isApplicationRunning: Bool,
        hasActiveTurnControl: Bool,
        isInspectionAvailable: Bool = true,
        isIdleStateConfirmed: Bool = false
    ) {
        self.isApplicationRunning = isApplicationRunning
        self.hasActiveTurnControl = hasActiveTurnControl
        self.isInspectionAvailable = isInspectionAvailable
        self.isIdleStateConfirmed = isIdleStateConfirmed
    }
}

public enum GuardAction: Equatable, Sendable {
    case notify(level: GuardLevel, remaining: Double)
    case markGraceTask
    case armNewTaskBlock
    case closeIdleApplications
    case requestSoftStop(reason: String)
    case forceTerminate(reason: String)
    case recovered
}

public struct GuardEvaluation: Equatable, Sendable {
    public let level: GuardLevel
    public let actions: [GuardAction]
    public let remainingPercent: Double?
    public let graceTaskInProgress: Bool
    public let newTaskBlockArmed: Bool
}
