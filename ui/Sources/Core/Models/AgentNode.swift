import Foundation

/// A single request, response, tool call, or replay step shown in the trace graph.
public struct AgentNode: Identifiable, Hashable, Codable, Sendable {
    /// Stable node identifier from the proxy or local Codex observer.
    public let id: String

    /// Human-readable agent name, such as Codex or Claude Code.
    public let agentName: String

    /// Vertical graph depth assigned by the snapshot builder.
    public let depth: Int

    /// Short step title shown in the graph and sidebar.
    public let stepName: String

    /// Display timestamp for this node.
    public let timestamp: String

    /// Model identifier reported by the provider or local observer.
    public let model: String

    /// Display-ready cost string for the captured call.
    public let cost: String

    /// Display-ready latency string.
    public let latency: String

    /// Numeric latency in milliseconds for sorting and export.
    public let latencyMs: Int

    /// Relative bar width used by compact graph metrics.
    public let barPercent: Double

    /// Input token count reported for the call.
    public let tokensIn: Int

    /// Output token count reported for the call.
    public let tokensOut: Int

    /// Provider request identifier or a shortened local event id.
    public let requestId: String

    /// Cache state label, such as HIT, MISS, or codex-log.
    public let cacheStatus: String

    /// Optional sampling temperature when known.
    public let temperature: Double?

    /// Node execution status.
    public let status: NodeStatus

    /// Prompt content associated with this node.
    public let prompt: AgentPrompt

    /// Response content associated with this node.
    public let response: AgentResponse

    /// Error information when the node failed.
    public let error: AgentError?

    /// Creates a graph node and derives a legacy agent name when older payloads omit it.
    public init(
        id: String,
        agentName: String? = nil,
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
        self.agentName = agentName ?? Self.defaultAgentName(
            model: model,
            stepName: stepName,
            cacheStatus: cacheStatus
        )
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

    /// Preserves readable agent names for trace payloads produced before `agentName` existed.
    static func defaultAgentName(
        model: String,
        stepName: String,
        cacheStatus: String
    ) -> String {
        let model = model.lowercased()
        let stepName = stepName.lowercased()
        let cacheStatus = cacheStatus.lowercased()

        if cacheStatus == "codex-log" || stepName.contains("codex") {
            return "Codex"
        }

        if model.contains("claude") || stepName.contains("anthropic") {
            return "Claude Code"
        }

        if stepName.contains("openai") {
            return "Codex"
        }

        return "Agent"
    }
}
