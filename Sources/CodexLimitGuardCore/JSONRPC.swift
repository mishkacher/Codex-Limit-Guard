import Foundation

public struct JSONRPCBuilder: Sendable {
    public let clientName: String
    public let clientTitle: String
    public let clientVersion: String

    public init(
        clientName: String = "codex_limit_guard",
        clientTitle: String = "Codex Limit Guard",
        clientVersion: String = "0.1.0"
    ) {
        self.clientName = clientName
        self.clientTitle = clientTitle
        self.clientVersion = clientVersion
    }

    public func initialize(id: Int = 0) -> [String: Any] {
        [
            "method": "initialize",
            "id": id,
            "params": [
                "clientInfo": [
                    "name": clientName,
                    "title": clientTitle,
                    "version": clientVersion
                ]
            ]
        ]
    }

    public func initialized() -> [String: Any] {
        ["method": "initialized", "params": [:] as [String: Any]]
    }

    public func readRateLimits(id: Int) -> [String: Any] {
        ["method": "account/rateLimits/read", "id": id]
    }

    public func encodedLine(_ object: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        data.append(0x0A)
        return data
    }
}
