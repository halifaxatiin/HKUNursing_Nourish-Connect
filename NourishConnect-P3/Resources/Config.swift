import Foundation

/// Settings you fill in once the chat proxy is deployed (see proxy/README.md).
enum Config {
    /// Full address of the deployed proxy, for example
    /// "https://nourish-proxy.your-name.workers.dev/chat". Leave empty until it is deployed.
    /// While empty, the chat tells the user it is not available and the rest of the app still works.
    static let chatEndpoint = "https://nourish-proxy.nourishconnect.workers.dev/chat"

    /// A shared token the proxy checks. It is inside the app, so it is NOT a secret: it only
    /// turns away casual traffic. The real OpenRouter key lives only on the proxy.
    static let appToken = "asdyiweygb123781y23uncy4iut2346u7b289o87n976ert786afdt7AUSytfa6euiygbew78i6u3yb2n"

    static var isChatConfigured: Bool {
        !chatEndpoint.isEmpty && URL(string: chatEndpoint) != nil
    }
}

/// A random id made on first launch and kept on the phone. It lets the proxy count messages per
/// phone per day. It is not linked to a name, a number or any health record.
enum InstallID {
    private static let key = "installID"

    static var value: String {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: key)
        return created
    }
}
