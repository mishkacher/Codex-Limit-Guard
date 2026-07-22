import Foundation

public enum RateLimitParserError: Error, Equatable {
    case invalidJSON
    case missingPayload
    case noRateLimitWindows
}

public struct RateLimitParser: Sendable {
    public init() {}

    public func parse(line: String, receivedAt: Date = Date()) throws -> RateLimitSnapshot? {
        guard let data = line.data(using: .utf8) else { throw RateLimitParserError.invalidJSON }
        return try parse(data: data, receivedAt: receivedAt)
    }

    public func parse(data: Data, receivedAt: Date = Date()) throws -> RateLimitSnapshot? {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RateLimitParserError.invalidJSON
        }

        if let method = root["method"] as? String, method != "account/rateLimits/updated" {
            return nil
        }

        let payload: [String: Any]?
        if let result = root["result"] as? [String: Any] {
            payload = result
        } else if let params = root["params"] as? [String: Any] {
            payload = params
        } else {
            payload = nil
        }

        guard let payload else {
            if root["error"] != nil { return nil }
            throw RateLimitParserError.missingPayload
        }

        var windows: [QuotaWindow] = []
        var seen = Set<String>()

        if let multi = payload["rateLimitsByLimitId"] as? [String: Any] {
            for (fallbackID, value) in multi {
                guard let bucket = value as? [String: Any] else { continue }
                appendBucket(bucket, fallbackID: fallbackID, into: &windows, seen: &seen)
            }
        }

        if let legacy = payload["rateLimits"] as? [String: Any] {
            appendBucket(legacy, fallbackID: "codex", into: &windows, seen: &seen)
        }

        guard !windows.isEmpty else { throw RateLimitParserError.noRateLimitWindows }

        let resetCredits: Int?
        if let credits = payload["rateLimitResetCredits"] as? [String: Any] {
            resetCredits = number(credits["availableCount"]).map(Int.init)
        } else {
            resetCredits = nil
        }

        return RateLimitSnapshot(
            windows: windows,
            resetCreditsAvailable: resetCredits,
            receivedAt: receivedAt
        )
    }

    private func appendBucket(
        _ bucket: [String: Any],
        fallbackID: String,
        into windows: inout [QuotaWindow],
        seen: inout Set<String>
    ) {
        let bucketID = (bucket["limitId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedID = bucketID?.isEmpty == false ? bucketID! : fallbackID
        let name = bucket["limitName"] as? String
        let planType = bucket["planType"] as? String

        appendWindow(bucket["primary"], bucketID: resolvedID, name: name, planType: planType, kind: .primary, into: &windows, seen: &seen)
        appendWindow(bucket["secondary"], bucketID: resolvedID, name: name, planType: planType, kind: .secondary, into: &windows, seen: &seen)
    }

    private func appendWindow(
        _ value: Any?,
        bucketID: String,
        name: String?,
        planType: String?,
        kind: QuotaWindowKind,
        into windows: inout [QuotaWindow],
        seen: inout Set<String>
    ) {
        guard let dict = value as? [String: Any],
              let used = number(dict["usedPercent"]),
              let duration = number(dict["windowDurationMins"]),
              let reset = number(dict["resetsAt"]) else { return }

        let key = "\(bucketID):\(kind.rawValue):\(Int(reset))"
        guard seen.insert(key).inserted else { return }

        windows.append(QuotaWindow(
            bucketID: bucketID,
            bucketName: name,
            kind: kind,
            usedPercent: used,
            windowDurationMinutes: Int(duration),
            resetsAt: Date(timeIntervalSince1970: reset),
            planType: planType
        ))
    }

    private func number(_ value: Any?) -> Double? {
        switch value {
        case let value as Double: return value
        case let value as Int: return Double(value)
        case let value as NSNumber: return value.doubleValue
        case let value as String: return Double(value)
        default: return nil
        }
    }
}
