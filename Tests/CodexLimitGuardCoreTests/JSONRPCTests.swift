import XCTest
@testable import CodexLimitGuardCore

final class JSONRPCTests: XCTestCase {
    func testInitializationShape() throws {
        let builder = JSONRPCBuilder(clientVersion: "1.2.3")
        let message = builder.initialize()
        XCTAssertEqual(message["method"] as? String, "initialize")
        let params = try XCTUnwrap(message["params"] as? [String: Any])
        let client = try XCTUnwrap(params["clientInfo"] as? [String: Any])
        XCTAssertEqual(client["name"] as? String, "codex_limit_guard")
        XCTAssertEqual(client["version"] as? String, "1.2.3")
    }

    func testEncodedMessagesEndWithNewline() throws {
        let data = try JSONRPCBuilder().encodedLine(["method": "initialized", "params": [:]])
        XCTAssertEqual(data.last, 0x0A)
    }

    func testRateLimitReadMethod() {
        let message = JSONRPCBuilder().readRateLimits(id: 42)
        XCTAssertEqual(message["method"] as? String, "account/rateLimits/read")
        XCTAssertEqual(message["id"] as? Int, 42)
    }
}
