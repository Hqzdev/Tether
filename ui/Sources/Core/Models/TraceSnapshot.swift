import Foundation

/// UI-facing snapshot for one trace session and its visible agent nodes.
public struct TraceSnapshot: Codable, Hashable, Sendable {
    /// The proxy or local observer session represented by this snapshot.
    public let session: TraceSession?

    /// Ordered nodes that should be rendered in the trace graph.
    public let nodes: [AgentNode]

    /// Node ids marked stale by replay or mocked-output edits.
    public let staleNodeIds: [AgentNode.ID]

    /// Creates a trace snapshot from a session and already-normalized graph nodes.
    public init(
        session: TraceSession?,
        nodes: [AgentNode],
        staleNodeIds: [AgentNode.ID] = []
    ) {
        self.session = session
        self.nodes = nodes
        self.staleNodeIds = staleNodeIds
    }

    enum CodingKeys: String, CodingKey {
        case session
        case nodes
        case staleNodeIds
    }

    /// Decodes older snapshots that predate `staleNodeIds`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        session = try container.decodeIfPresent(TraceSession.self, forKey: .session)
        nodes = try container.decode([AgentNode].self, forKey: .nodes)
        staleNodeIds = try container.decodeIfPresent([AgentNode.ID].self, forKey: .staleNodeIds) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(session, forKey: .session)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(staleNodeIds, forKey: .staleNodeIds)
    }
}
