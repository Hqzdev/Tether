import Foundation

/// Structured description of what was assembled into a model call.
public struct AgentContextInputs: Hashable, Codable, Sendable {
    public let sources: [AgentContextSource]
    public let withheld: [String]
    public let inputHash: String

    public init(
        sources: [AgentContextSource] = [],
        withheld: [String] = [],
        inputHash: String = ""
    ) {
        self.sources = sources
        self.withheld = withheld
        self.inputHash = inputHash
    }

    /// Empty context descriptor used for old payloads and local observer nodes.
    public static let empty = AgentContextInputs()

    enum CodingKeys: String, CodingKey {
        case sources
        case withheld
        case inputHash
    }

    /// Decodes `{}` and older malformed context payloads as an empty descriptor.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sources = (try? container.decodeIfPresent([AgentContextSource].self, forKey: .sources)) ?? []
        withheld = (try? container.decodeIfPresent([String].self, forKey: .withheld)) ?? []
        inputHash = (try? container.decodeIfPresent(String.self, forKey: .inputHash)) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sources, forKey: .sources)
        try container.encode(withheld, forKey: .withheld)
        try container.encode(inputHash, forKey: .inputHash)
    }
}

/// One context source shown by the boundary inspector.
public struct AgentContextSource: Hashable, Codable, Sendable, Identifiable {
    public var id: String { "\(kind):\(pathOrId):\(hash)" }

    public let kind: String
    public let pathOrId: String
    public let hash: String
    public let sizeBytes: Int
    public let body: String?

    public init(
        kind: String,
        pathOrId: String,
        hash: String,
        sizeBytes: Int,
        body: String? = nil
    ) {
        self.kind = kind
        self.pathOrId = pathOrId
        self.hash = hash
        self.sizeBytes = sizeBytes
        self.body = body
    }
}

/// Display buckets for context sources.
public enum AgentContextCategory: String, CaseIterable, Identifiable, Sendable {
    case files
    case skills
    case mcpResults
    case memorySearch
    case tools
    case inline
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .files:
            return "Files"
        case .skills:
            return "Skills"
        case .mcpResults:
            return "MCP Results"
        case .memorySearch:
            return "Memory / Search"
        case .tools:
            return "Tool Schemas"
        case .inline:
            return "Inline Segments"
        case .other:
            return "Other"
        }
    }
}

public extension AgentContextSource {
    /// Maps raw proxy source kinds to stable inspector categories.
    var category: AgentContextCategory {
        switch kind.lowercased() {
        case "file":
            return .files
        case "skill":
            return .skills
        case "mcp", "mcp_result":
            return .mcpResults
        case "memory", "search":
            return .memorySearch
        case "tool", "tool_result":
            return .tools
        case "inline":
            return .inline
        default:
            return .other
        }
    }
}
