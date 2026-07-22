import Foundation
import OSLog
import CodexLimitGuardCore

final class EventLogger {
    private let logger = Logger(subsystem: "dev.mishkacher.CodexLimitGuard", category: "guard")
    private let redactor = SecretRedactor()
    private let queue = DispatchQueue(label: "dev.mishkacher.codex-limit-guard.event-log")
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Codex Limit Guard", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("events.jsonl")
    }

    func write(_ event: EventRecord) {
        let safeTitle = redactor.redact(event.title)
        let safeDetail = redactor.redact(event.detail)
        logger.info("\(safeTitle, privacy: .public): \(safeDetail, privacy: .public)")

        var safe = event
        safe = EventRecord(
            id: event.id,
            timestamp: event.timestamp,
            kind: event.kind,
            title: safeTitle,
            detail: safeDetail,
            remainingPercent: event.remainingPercent
        )

        queue.async { [fileURL] in
            guard let data = try? JSONEncoder.guardEncoder.encode(safe) else { return }
            var line = data
            line.append(0x0A)
            if FileManager.default.fileExists(atPath: fileURL.path),
               let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: line)
            } else {
                try? line.write(to: fileURL, options: .atomic)
            }
        }
    }

    func loadRecent(limit: Int = 120) -> [EventRecord] {
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n")
            .suffix(limit)
            .compactMap { try? JSONDecoder.guardDecoder.decode(EventRecord.self, from: Data($0.utf8)) }
            .reversed()
    }
}

private extension JSONEncoder {
    static var guardEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var guardDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
