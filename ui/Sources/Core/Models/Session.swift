import Foundation

/// A persisted capture session shown in the session-history sidebar.
///
/// Decoded from the proxy's session DTO with `convertFromSnakeCase`, so
/// `created_at`/`call_count` map onto `createdAt`/`callCount`.
public struct Session: Identifiable, Hashable, Codable, Sendable {
    /// Stable session identifier (a proxy-side UUID string).
    public let id: String

    /// Display name, derived from the first user prompt or set by the user.
    public let name: String

    /// Creation time in epoch milliseconds, used for newest-first ordering.
    public let createdAt: Int64

    /// Number of captured calls recorded against this session.
    public let callCount: Int

    /// Display-ready start time (local `HH:MM:SS`).
    public let startedAt: String

    /// Creates session-history metadata for the sidebar list.
    public init(id: String, name: String, createdAt: Int64, callCount: Int, startedAt: String) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.callCount = callCount
        self.startedAt = startedAt
    }
}

/// The proxy's session-list response: every live session plus the id of the one
/// currently receiving traffic.
public struct SessionList: Hashable, Codable, Sendable {
    /// Sessions ordered newest-first by the proxy.
    public let sessions: [Session]

    /// Session that currently receives live proxy traffic, when known.
    public let currentSessionId: String?

    /// Creates a decoded session-list response.
    public init(sessions: [Session], currentSessionId: String?) {
        self.sessions = sessions
        self.currentSessionId = currentSessionId
    }
}
