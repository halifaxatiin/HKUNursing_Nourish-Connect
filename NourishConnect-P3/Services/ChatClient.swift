import Foundation

struct ChatTurn: Equatable {
    enum Role: String {
        case user
        case assistant
    }

    let role: Role
    let text: String
}

enum ChatClientError: Error, Equatable {
    case notConfigured
    case rateLimited
    case network
    case badReply
}

/// Sends a short conversation to the proxy and returns the reply text.
/// The proxy holds the OpenRouter key, adds the safety instructions, and calls DeepSeek.
/// The app never sees the key and never talks to OpenRouter directly.
struct ChatClient {
    var session: URLSession = .shared

    /// At most this many recent turns are sent.
    static let maxTurns = 8
    static let maxTurnLength = 400

    func reply(history: [ChatTurn], context: [String]) async throws -> String {
        guard Config.isChatConfigured, let url = URL(string: Config.chatEndpoint) else {
            throw ChatClientError.notConfigured
        }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.appToken, forHTTPHeaderField: "X-App-Token")
        request.httpBody = try ChatClient.makeBody(history: history, context: context, installID: InstallID.value)

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            throw ChatClientError.network
        }
        let status = (result.1 as? HTTPURLResponse)?.statusCode ?? 0
        return try ChatClient.parseReply(data: result.0, status: status)
    }

    /// Builds the JSON the proxy expects. Pure, so it is unit tested.
    static func makeBody(history: [ChatTurn], context: [String], installID: String) throws -> Data {
        let turns = history.suffix(maxTurns).map { turn -> [String: String] in
            ["role": turn.role.rawValue, "content": String(turn.text.prefix(maxTurnLength))]
        }
        let body: [String: Any] = [
            "messages": turns,
            "context": Array(context.prefix(5)),
            "installId": installID
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    /// Reads the proxy's reply. Pure, so it is unit tested.
    static func parseReply(data: Data, status: Int) throws -> String {
        if status == 429 { throw ChatClientError.rateLimited }
        guard (200..<300).contains(status) else { throw ChatClientError.network }
        guard
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let reply = object["reply"] as? String,
            !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw ChatClientError.badReply }
        return reply
    }
}
