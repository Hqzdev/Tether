import Combine
import Core
import Networking
import SwiftUI
import UI

/// Main-actor state owner for live proxy and Codex trace snapshots.
@MainActor
final class TraceStore: ObservableObject {
    @Published var session: TraceSession?
    @Published var sessions: [TraceSession] = []
    @Published var currentSessionId: TraceSession.ID?
    @Published var selectedSessionId: TraceSession.ID?
    @Published var nodes: [AgentNode] = []
    @Published var proxyStatus: ProxyConnectionStatus = .connecting

    let client: TraceAPIClient
    let codexObserver: CodexLogObserver
    var pollingTask: Task<Void, Never>?
    var codexBaselineLogId: Int?
    var graphInteractionActive = false
    var refreshAfterInteraction = false
    var deferredSessionList: TraceSessionList?
    var deferredSnapshot: TraceSnapshot?
    var nodeDetails: [AgentNode.ID: AgentNode] = [:]
    var loadingNodeDetailIds: Set<AgentNode.ID> = []

    /// Creates a store backed by the local proxy client and Codex log observer.
    init(
        client: TraceAPIClient? = nil,
        codexObserver: CodexLogObserver = CodexLogObserver()
    ) {
        self.client = client ?? TraceAPIClient()
        self.codexObserver = codexObserver
    }

    /// Starts the periodic refresh loop if it is not already running.
    func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                if self.graphInteractionActive {
                    self.refreshAfterInteraction = true
                    do {
                        try await Task.sleep(for: .milliseconds(180))
                    } catch {
                        break
                    }
                    continue
                }

                await refresh()

                do {
                    try await Task.sleep(for: .seconds(1.2))
                } catch {
                    break
                }
            }
        }
    }

    /// Stops the periodic refresh loop.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Refreshes proxy sessions, proxy traces, and local Codex logs into one visible snapshot.
    func refresh() async {
        guard !graphInteractionActive else {
            refreshAfterInteraction = true
            return
        }

        async let proxySessionsResult = loadProxySessions()
        async let codexResult = loadCodexSnapshot()

        let (sessionList, codex) = await (proxySessionsResult, codexResult)
        guard !shouldDeferRefreshResult() else { return }

        let proxySessions = try? sessionList.get()
        let codexSnapshot = try? codex.get()
        var proxySnapshot: TraceSnapshot?
        var proxyError: Error?

        if let proxySessions {
            apply(sessionList: proxySessions)
            let sessionId = selectedSessionId ?? proxySessions.currentSessionId
            let proxyResult = await loadProxySnapshot(sessionId: sessionId)
            guard !shouldDeferRefreshResult() else { return }

            proxySnapshot = try? proxyResult.get()
            if case .failure(let error) = proxyResult {
                proxyError = error
            }
        } else if case .failure(let error) = sessionList {
            sessions = []
            currentSessionId = nil
            selectedSessionId = nil
            proxyError = error
        }

        let shouldCombineCodex = selectedSessionId == nil || selectedSessionId == currentSessionId
        if shouldCombineCodex, let combinedSnapshot = combinedSnapshot(
            proxySnapshot: proxySnapshot,
            codexSnapshot: codexSnapshot
        ) {
            apply(snapshot: combinedSnapshot)
            proxyStatus = .observingAgents(agentSummary(for: combinedSnapshot.nodes))
            return
        }

        if let proxySnapshot, !proxySnapshot.nodes.isEmpty {
            apply(snapshot: proxySnapshot)
            proxyStatus = .online
            return
        }

        if let codexSnapshot, !codexSnapshot.nodes.isEmpty {
            apply(snapshot: codexSnapshot)
            proxyStatus = .observingCodex("Watching Terminal Codex automatically")
            return
        }

        if let proxySnapshot {
            apply(snapshot: proxySnapshot)
            proxyStatus = .online
            return
        }

        if let codexSnapshot {
            apply(snapshot: codexSnapshot)
            proxyStatus = .observingCodex("Open Terminal and run codex")
            return
        }

        proxyStatus = .offline(proxyError?.localizedDescription ?? "Start the proxy or run codex in Terminal")
    }

    /// Applies a snapshot to the currently visible graph.
    func apply(snapshot: TraceSnapshot) {
        guard !graphInteractionActive else {
            deferredSnapshot = snapshot
            return
        }

        commit(snapshot: snapshot)
    }

    /// Marks graph gestures so refreshes do not invalidate SwiftUI during drag or pan.
    func setGraphInteractionActive(_ isActive: Bool) {
        guard graphInteractionActive != isActive else { return }

        graphInteractionActive = isActive

        guard !isActive else { return }

        flushDeferredTraceUpdates()

        if refreshAfterInteraction {
            refreshAfterInteraction = false
            Task { [weak self] in
                await self?.refresh()
            }
        }
    }

    /// Applies buffered updates once the current graph gesture ends.
    func flushDeferredTraceUpdates() {
        if let sessionList = deferredSessionList {
            deferredSessionList = nil
            commit(sessionList: sessionList)
        }

        if let snapshot = deferredSnapshot {
            deferredSnapshot = nil
            commit(snapshot: snapshot)
        }
    }

    /// Commits a snapshot only when it changes visible state.
    func commit(snapshot: TraceSnapshot) {
        let hydratedNodes = snapshot.nodes.map { node in
            guard let detail = nodeDetails[node.id] else { return node }
            return node.hydrated(with: detail)
        }

        guard session != snapshot.session || nodes != hydratedNodes else {
            return
        }

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            session = snapshot.session
            nodes = hydratedNodes
        }
    }

    /// Commits session metadata only when it changes visible state.
    func commit(sessionList: TraceSessionList) {
        let nextSelectedSessionId: TraceSession.ID?
        if let selectedSessionId, sessionList.sessions.contains(where: { $0.id == selectedSessionId }) {
            nextSelectedSessionId = selectedSessionId
        } else {
            nextSelectedSessionId = sessionList.currentSessionId ?? sessionList.sessions.first?.id
        }

        guard sessions != sessionList.sessions
            || currentSessionId != sessionList.currentSessionId
            || selectedSessionId != nextSelectedSessionId
        else {
            return
        }

        sessions = sessionList.sessions
        currentSessionId = sessionList.currentSessionId
        selectedSessionId = nextSelectedSessionId
    }

    /// Drops buffered live updates after an explicit clear or new-session reset.
    func resetDeferredTraceUpdates() {
        deferredSessionList = nil
        deferredSnapshot = nil
        refreshAfterInteraction = false
        nodeDetails = [:]
        loadingNodeDetailIds = []
    }

    /// Returns true when an in-flight refresh should yield to active graph input.
    func shouldDeferRefreshResult() -> Bool {
        guard graphInteractionActive else { return false }

        refreshAfterInteraction = true
        return true
    }

    /// Lazily hydrates prompt/response/error payloads for the selected proxy node.
    func loadNodeDetailIfNeeded(_ nodeId: AgentNode.ID) async {
        guard let node = nodes.first(where: { $0.id == nodeId }),
              node.needsDetailPayload,
              nodeDetails[nodeId] == nil,
              !loadingNodeDetailIds.contains(nodeId)
        else {
            return
        }

        loadingNodeDetailIds.insert(nodeId)
        defer {
            loadingNodeDetailIds.remove(nodeId)
        }

        do {
            let detail = try await client.traceNodeDetail(nodeId: nodeId)
            nodeDetails[nodeId] = detail

            guard let index = nodes.firstIndex(where: { $0.id == nodeId }) else {
                return
            }

            let hydratedNode = nodes[index].hydrated(with: detail)
            guard nodes[index] != hydratedNode else { return }
            nodes[index] = hydratedNode
        } catch {
            // Local Codex nodes and stale proxy selections may not have proxy-side details.
        }
    }

    /// Hydrates every currently visible summary node before full-fidelity export.
    func loadVisibleNodeDetailsIfNeeded() async {
        let nodeIds = nodes
            .filter(\.needsDetailPayload)
            .map(\.id)

        for nodeId in nodeIds {
            await loadNodeDetailIfNeeded(nodeId)
        }
    }
}

private extension AgentNode {
    /// Summary payloads intentionally omit inspector-only text fields.
    var needsDetailPayload: Bool {
        cacheStatus != "codex-log"
            && prompt.system.isEmpty
            && prompt.user.isEmpty
            && response.text.isEmpty
    }

    /// Preserves fresh graph summary fields while attaching inspector payloads.
    func hydrated(with detail: AgentNode) -> AgentNode {
        AgentNode(
            id: id,
            agentName: agentName,
            depth: depth,
            stepName: stepName,
            timestamp: timestamp,
            provider: provider,
            model: model,
            cost: cost,
            latency: latency,
            latencyMs: latencyMs,
            barPercent: barPercent,
            tokensIn: tokensIn,
            tokensOut: tokensOut,
            requestId: requestId,
            cacheStatus: cacheStatus,
            temperature: temperature,
            traceId: detail.traceId.isEmpty ? traceId : detail.traceId,
            parentSpanId: detail.parentSpanId ?? parentSpanId,
            toolUseIds: detail.toolUseIds.isEmpty ? toolUseIds : detail.toolUseIds,
            contextInputs: detail.contextInputs.sources.isEmpty && detail.contextInputs.withheld.isEmpty ? contextInputs : detail.contextInputs,
            inputHash: detail.inputHash.isEmpty ? inputHash : detail.inputHash,
            outputHash: detail.outputHash.isEmpty ? outputHash : detail.outputHash,
            stale: stale || detail.stale,
            status: status,
            prompt: detail.prompt,
            response: detail.response,
            error: detail.error
        )
    }
}
