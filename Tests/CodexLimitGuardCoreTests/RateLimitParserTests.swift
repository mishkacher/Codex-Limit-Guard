import XCTest
@testable import CodexLimitGuardCore

final class RateLimitParserTests: XCTestCase {
    func testParsesMultiBucketResponseAndSortsByRemaining() throws {
        let json = #"{"id":6,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":25,"windowDurationMins":15,"resetsAt":1730947200}},"rateLimitsByLimitId":{"codex":{"limitId":"codex","primary":{"usedPercent":25,"windowDurationMins":15,"resetsAt":1730947200},"secondary":{"usedPercent":88,"windowDurationMins":10080,"resetsAt":1731552000}},"codex_other":{"limitId":"codex_other","limitName":"Extra","primary":{"usedPercent":42,"windowDurationMins":60,"resetsAt":1730950800}}},"rateLimitResetCredits":{"availableCount":2}}}"#
        let snapshot = try XCTUnwrap(RateLimitParser().parse(line: json))
        XCTAssertEqual(snapshot.windows.count, 3)
        XCTAssertEqual(snapshot.limitingWindow?.kind, .secondary)
        XCTAssertEqual(snapshot.minimumRemainingPercent, 12)
        XCTAssertEqual(snapshot.resetCreditsAvailable, 2)
    }

    func testParsesUpdateNotification() throws {
        let json = #"{"method":"account/rateLimits/updated","params":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":31,"windowDurationMins":15,"resetsAt":1730948100}}}}"#
        let snapshot = try XCTUnwrap(RateLimitParser().parse(line: json))
        XCTAssertEqual(snapshot.windows.first?.remainingPercent, 69)
    }

    func testIgnoresUnrelatedNotification() throws {
        let json = #"{"method":"thread/started","params":{"thread":{"id":"x"}}}"#
        XCTAssertNil(try RateLimitParser().parse(line: json))
    }

    func testRejectsPayloadWithoutWindows() {
        XCTAssertThrowsError(try RateLimitParser().parse(line: #"{"id":6,"result":{}}"#)) { error in
            XCTAssertEqual(error as? RateLimitParserError, .noRateLimitWindows)
        }
    }

    func testClampsPercentages() {
        let window = QuotaWindow(bucketID: "x", kind: .primary, usedPercent: 140, windowDurationMinutes: 1, resetsAt: Date())
        XCTAssertEqual(window.usedPercent, 100)
        XCTAssertEqual(window.remainingPercent, 0)
    }
}
