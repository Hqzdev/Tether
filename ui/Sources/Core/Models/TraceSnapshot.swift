import Foundation

/// UI-facing snapshot for one trace session and its visible agent nodes.
public struct TraceSnapshot: Codable, Hashable, Sendable {
    /// The proxy or local observer session represented by this snapshot.
    public let session: TraceSession?

    /// Ordered nodes that should be rendered in the trace graph.
    public let nodes: [AgentNode]

    /// Creates a trace snapshot from a session and already-normalized graph nodes.
    public init(session: TraceSession?, nodes: [AgentNode]) {
        self.session = session
        self.nodes = nodes
    }
}
