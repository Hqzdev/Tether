import Core
import Foundation

extension MainThreePaneLayoutView {
    /// Builds CSV rows with a stable header matching exported trace fields.
    func csvRows(for snapshot: TraceSnapshot) -> [[String]] {
        var rows = [
            [
                "session_id",
                "session_title",
                "node_id",
                "agent",
                "step",
                "timestamp",
                "model",
                "status",
                "latency_ms",
                "tokens_in",
                "tokens_out",
                "request_id",
                "prompt",
                "response"
            ]
        ]

        for node in snapshot.nodes {
            rows.append([
                snapshot.session?.id ?? "",
                snapshot.session?.title ?? "",
                node.id,
                node.agentName,
                node.stepName,
                node.timestamp,
                node.model,
                node.status.rawValue,
                "\(node.latencyMs)",
                "\(node.tokensIn)",
                "\(node.tokensOut)",
                node.requestId,
                node.prompt.user,
                node.response.text
            ])
        }

        return rows
    }

    /// Builds the metadata text block copied from the inspector.
    func metadataClipboardText(for node: AgentNode) -> String {
        """
        id: \(node.id)
        agent: \(node.agentName)
        model: \(node.model)
        requestId: \(node.requestId)
        status: \(node.status.label)
        latency: \(node.latency)
        tokensIn: \(node.tokensIn)
        tokensOut: \(node.tokensOut)
        cacheStatus: \(node.cacheStatus)
        """
    }
}
