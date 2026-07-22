import Foundation

public struct SecretRedactor: Sendable {
    public init() {}

    public func redact(_ text: String) -> String {
        var value = text
        let patterns = [
            #"\b\d{7,12}:[A-Za-z0-9_-]{20,}\b"#,
            #"\b(sk|sess|pat)-[A-Za-z0-9_-]{12,}\b"#,
            #"(?i)(authorization\s*:\s*bearer\s+)[A-Za-z0-9._-]+"#
        ]
        for pattern in patterns {
            value = replacing(pattern: pattern, in: value)
        }
        return value
    }

    private func replacing(pattern: String, in value: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: "[REDACTED]")
    }
}
