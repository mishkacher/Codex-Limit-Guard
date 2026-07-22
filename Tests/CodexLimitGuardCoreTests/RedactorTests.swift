import XCTest
@testable import CodexLimitGuardCore

final class RedactorTests: XCTestCase {
    func testRedactsTelegramToken() {
        let value = SecretRedactor().redact("token=123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef")
        XCTAssertFalse(value.contains("ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
        XCTAssertTrue(value.contains("[REDACTED]"))
    }

    func testRedactsBearerToken() {
        let value = SecretRedactor().redact("Authorization: Bearer abc.def.ghi")
        XCTAssertFalse(value.contains("abc.def.ghi"))
    }
}
