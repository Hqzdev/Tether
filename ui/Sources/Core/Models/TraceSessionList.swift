import Foundation

/// Session list response returned by the local proxy.
public struct TraceSessionList: Hashable, Codable, Sendable {
    /// Known sessions ordered for display.
    public let sessions: [TraceSession]

    /// Session that currently receives live proxy traffic.
    public let currentSessionId: String?

    /// Creates the UI-facing session list response.
    public init(sessions: [TraceSession], currentSessionId: String?) {
        self.sessions = sessions
        self.currentSessionId = currentSessionId
    }
}
