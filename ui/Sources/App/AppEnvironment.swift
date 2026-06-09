import Networking

public enum AgentTraceAppEnvironment {
    @discardableResult
    @MainActor
    public static func startLocalProxyIfAvailable() -> Bool {
        LocalProxyLauncher.shared.startIfAvailable()
    }
}
