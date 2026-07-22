import Foundation
import CodexLimitGuardCore

struct EventRecord: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case info
        case warning
        case action
        case error
        case recovered
    }

    let id: UUID
    let timestamp: Date
    let kind: Kind
    let title: String
    let detail: String
    let remainingPercent: Double?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: Kind,
        title: String,
        detail: String,
        remainingPercent: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.title = title
        self.detail = detail
        self.remainingPercent = remainingPercent
    }
}
