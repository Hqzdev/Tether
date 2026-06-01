import Foundation

struct TraceSnapshot: Codable, Hashable, Sendable {
    let session: TraceSession?
    let nodes: [AgentNode]
}

struct AgentNode: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let depth: Int
    let stepName: String
    let timestamp: String
    let model: String
    let cost: String
    let latency: String
    let latencyMs: Int
    let barPercent: Double
    let tokensIn: Int
    let tokensOut: Int
    let requestId: String
    let cacheStatus: String
    let temperature: Double?
    let status: NodeStatus
    let prompt: AgentPrompt
    let response: AgentResponse
    let error: AgentError?
}

struct TraceSession: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let trigger: String
    let startedAt: String
}

struct TraceSessionList: Hashable, Codable, Sendable {
    let sessions: [TraceSession]
    let currentSessionId: String?
}

struct AgentPrompt: Hashable, Codable, Sendable {
    let system: String
    let user: String
}

struct AgentResponse: Hashable, Codable, Sendable {
    let language: ResponseLanguage
    let text: String
}

struct AgentError: Hashable, Codable, Sendable {
    let code: String
    let message: String
    let detail: String
}

enum ResponseLanguage: String, Hashable, Codable, Sendable {
    case json
    case text
}

enum NodeStatus: String, Hashable, Codable, Sendable {
    case success
    case cached
    case running
    case error

    var label: String {
        rawValue.uppercased()
    }

    var symbolName: String {
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

enum InspectorTab: String, CaseIterable, Identifiable {
    case prompt
    case response
    case metadata

    var id: String { rawValue }

    var title: String {
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
