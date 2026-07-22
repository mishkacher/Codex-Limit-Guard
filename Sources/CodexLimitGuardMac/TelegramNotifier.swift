import Foundation

final class TelegramNotifier {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(token: String, chatID: String, text: String) async throws {
        guard !token.isEmpty, !chatID.isEmpty else { throw TelegramError.missingConfiguration }
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/sendMessage") else {
            throw TelegramError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "chat_id": chatID,
            "text": text,
            "disable_web_page_preview": true
        ])
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TelegramError.requestFailed
        }
    }
}

enum TelegramError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: return "Telegram token or chat ID is missing."
        case .invalidURL: return "Telegram URL is invalid."
        case .requestFailed: return "Telegram rejected the notification request."
        }
    }
}
