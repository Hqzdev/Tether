import Foundation

public struct TraceSnapshot: Codable, Hashable, Sendable {
    public let session: TraceSession?
    public let nodes: [AgentNode]

    public init(session: TraceSession?, nodes: [AgentNode]) {
        self.session = session
        self.nodes = nodes
    }
}

public struct AgentNode: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let depth: Int
    public let stepName: String
    public let timestamp: String
    public let model: String
    public let cost: String
    public let latency: String
    public let latencyMs: Int
    public let barPercent: Double
    public let tokensIn: Int
    public let tokensOut: Int
    public let requestId: String
    public let cacheStatus: String
    public let temperature: Double?
    public let status: NodeStatus
    public let prompt: AgentPrompt
    public let response: AgentResponse
    public let error: AgentError?

    public init(
        id: String,
        depth: Int,
        stepName: String,
        timestamp: String,
        model: String,
        cost: String,
        latency: String,
        latencyMs: Int,
        barPercent: Double,
        tokensIn: Int,
        tokensOut: Int,
        requestId: String,
        cacheStatus: String,
        temperature: Double?,
        status: NodeStatus,
        prompt: AgentPrompt,
        response: AgentResponse,
        error: AgentError?
    ) {
        self.id = id
        self.depth = depth
        self.stepName = stepName
        self.timestamp = timestamp
        self.model = model
        self.cost = cost
        self.latency = latency
        self.latencyMs = latencyMs
        self.barPercent = barPercent
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.requestId = requestId
        self.cacheStatus = cacheStatus
        self.temperature = temperature
        self.status = status
        self.prompt = prompt
        self.response = response
        self.error = error
    }
}

public struct TraceSession: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let trigger: String
    public let startedAt: String

    public init(id: String, title: String, trigger: String, startedAt: String) {
        self.id = id
        self.title = title
        self.trigger = trigger
        self.startedAt = startedAt
    }
}

public struct TraceSessionList: Hashable, Codable, Sendable {
    public let sessions: [TraceSession]
    public let currentSessionId: String?

    public init(sessions: [TraceSession], currentSessionId: String?) {
        self.sessions = sessions
        self.currentSessionId = currentSessionId
    }
}

public struct AgentPrompt: Hashable, Codable, Sendable {
    public let system: String
    public let user: String

    public init(system: String, user: String) {
        self.system = system
        self.user = user
    }
}

public struct AgentResponse: Hashable, Codable, Sendable {
    public let language: ResponseLanguage
    public let text: String

    public init(language: ResponseLanguage, text: String) {
        self.language = language
        self.text = text
    }
}

public struct AgentError: Hashable, Codable, Sendable {
    public let code: String
    public let message: String
    public let detail: String

    public init(code: String, message: String, detail: String) {
        self.code = code
        self.message = message
        self.detail = detail
    }
}

public enum ResponseLanguage: String, Hashable, Codable, Sendable {
    case json
    case text
}

public enum NodeStatus: String, Hashable, Codable, Sendable {
    case success
    case cached
    case running
    case error

    public var label: String {
        rawValue.uppercased()
    }

    public var symbolName: String {
        switch self {
        case .success:
            return "lightbulb.fill"
        case .cached:
            return "externaldrive.fill"
        case .running:
            return "dot.radiowaves.left.and.right"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

public enum InspectorTab: String, CaseIterable, Identifiable, Sendable {
    case prompt
    case response
    case metadata

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .prompt:
            return "Prompt"
        case .response:
            return "Response"
        case .metadata:
            return "Metadata"
        }
    }
}
