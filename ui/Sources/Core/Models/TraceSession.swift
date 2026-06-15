import Foundation

/// Metadata for a proxy or local-observer trace session.
public struct TraceSession: Identifiable, Hashable, Codable, Sendable {
    /// Stable session identifier.
    public let id: String

    /// Human-readable session title.
    public let title: String

    /// Source or trigger that created the session.
    public let trigger: String

    /// Display-ready start time.
    public let startedAt: String

    /// Creates session metadata shown in the title bar and session picker.
    public init(id: String, title: String, trigger: String, startedAt: String) {
        self.id = id
        self.title = title
        self.trigger = trigger
        self.startedAt = startedAt
    }
}
