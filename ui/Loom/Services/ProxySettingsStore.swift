import Foundation

struct ProxySettings: Equatable {
    var port: Int
    var openAIUpstreamURL: String
    var anthropicUpstreamURL: String
    var localCacheEnabled: Bool

    var listenAddress: String {
        "127.0.0.1:\(port)"
    }

    var proxyBaseURL: URL {
        URL(string: "http://127.0.0.1:\(port)") ?? ProxySettingsStore.defaults.proxyBaseURL
    }
}

enum ProxySettingsStore {
    static let defaults = ProxySettings(
        port: 8080,
        openAIUpstreamURL: "https://api.openai.com",
        anthropicUpstreamURL: "https://api.anthropic.com",
        localCacheEnabled: true
    )

    private enum Key {
        static let port = "agenttrace.proxy.port"
        static let openAIUpstreamURL = "agenttrace.proxy.openAIUpstreamURL"
        static let anthropicUpstreamURL = "agenttrace.proxy.anthropicUpstreamURL"
        static let localCacheEnabled = "agenttrace.proxy.localCacheEnabled"
    }

    static var current: ProxySettings {
        let defaultsStore = UserDefaults.standard
        return ProxySettings(
            port: defaultsStore.object(forKey: Key.port) as? Int ?? defaults.port,
            openAIUpstreamURL: defaultsStore.string(forKey: Key.openAIUpstreamURL) ?? defaults.openAIUpstreamURL,
            anthropicUpstreamURL: defaultsStore.string(forKey: Key.anthropicUpstreamURL) ?? defaults.anthropicUpstreamURL,
            localCacheEnabled: defaultsStore.object(forKey: Key.localCacheEnabled) as? Bool ?? defaults.localCacheEnabled
        )
    }

    static func save(_ settings: ProxySettings) {
        let defaultsStore = UserDefaults.standard
        defaultsStore.set(settings.port, forKey: Key.port)
        defaultsStore.set(settings.openAIUpstreamURL, forKey: Key.openAIUpstreamURL)
        defaultsStore.set(settings.anthropicUpstreamURL, forKey: Key.anthropicUpstreamURL)
        defaultsStore.set(settings.localCacheEnabled, forKey: Key.localCacheEnabled)
        defaultsStore.set(settings.proxyBaseURL.absoluteString, forKey: "agenttrace.proxyBaseURL")
    }
}

enum ProxySettingsValidationError: LocalizedError {
    case invalidPort
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .invalidPort:
            return "Port must be between 1 and 65535."
        case .invalidURL(let label):
            return "\(label) upstream URL must be a valid HTTP or HTTPS URL."
        }
    }
}
