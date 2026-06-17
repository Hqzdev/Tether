import Combine
import Core
import Networking
import SwiftUI
import UI

/// Main-actor state owner for the trace graph. It polls one view at a time —
/// either the live multi-agent stream or a loaded historical session — and
/// splits a loaded session into a read-only history cluster plus any new live
/// calls. Session list ownership lives in `SessionStore`, not here.
@MainActor
final class TraceStore: ObservableObject {
    @Published var session: TraceSession?

    /// Live cluster: calls captured during the current view. In a loaded session
    /// these are calls that arrived after the history was loaded.
    @Published var nodes: [AgentNode] = []

    /// History cluster: the read-only nodes loaded from a historical session.
    @Published var sessionNodes: [AgentNode] = []

    /// Session currently being polled. `nil` means the live multi-agent view.
    @Published var selectedSessionId: TraceSession.ID?

    @Published var proxyStatus: ProxyConnectionStatus = .connecting

    let client: TraceAPIClient
    let codexObserver: CodexLogObserver
    var pollingTask: Task<Void, Never>?
    var codexBaselineLogId: Int?
    var graphInteractionActive = false
    var refreshAfterInteraction = false
    var deferredSnapshot: TraceSnapshot?
    /// Ids that belong to the loaded history cluster, used to keep new calls out of it.
    var historyNodeIds: Set<AgentNode.ID> = []
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

    /// True when a historical session is loaded (rather than the live view).
    var isHistoryView: Bool {
        selectedSessionId != nil
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

    /// Restarts polling so a session switch takes effect on the next tick.
    func restartPolling() {
        stopPolling()
        startPolling()
    }

    /// Refreshes the active view: a single historical session, or the combined
    /// live proxy + Codex stream when no session is loaded.
    func refresh() async {
        guard !graphInteractionActive else {
            refreshAfterInteraction = true
            return
        }

        if isHistoryView {
            await refreshHistory()
        } else {
            await refreshLive()
        }
    }

    /// Polls one loaded historical session and splits it into history + live clusters.
    private func refreshHistory() async {
        let proxyResult = await loadProxySnapshot(sessionId: selectedSessionId)
        guard !shouldDeferRefreshResult() else { return }

        switch proxyResult {
        case .success(let snapshot):
            apply(snapshot: snapshot)
            let liveCount = snapshot.nodes.filter { !historyNodeIds.contains($0.id) }.count
            proxyStatus = liveCount > 0
                ? .observingAgents("\(liveCount) new call\(liveCount == 1 ? "" : "s") this session")
                : .online
        case .failure(let error):
            proxyStatus = .offline(error.localizedDescription)
        }
    }

    /// Polls the live view, combining the current proxy session with local Codex events.
    private func refreshLive() async {
        async let codexResult = loadCodexSnapshot()
        let proxyResult = await loadProxySnapshot(sessionId: nil)
        let codex = await codexResult
        guard !shouldDeferRefreshResult() else { return }

        let proxySnapshot = try? proxyResult.get()
        let codexSnapshot = try? codex.get()
        let proxyError: Error? = {
            if case .failure(let error) = proxyResult { return error }
            return nil
        }()

        if let combinedSnapshot = combinedSnapshot(
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

    /// Loads a historical session as a read-only history cluster and begins
    /// polling it so new calls appear as a separate live cluster.
    func loadHistory(_ snapshot: TraceSnapshot, sessionId: TraceSession.ID) {
        resetDeferredTraceUpdates()
        codexBaselineLogId = nil
        selectedSessionId = sessionId
        historyNodeIds = Set(snapshot.nodes.map(\.id))
        session = snapshot.session
        sessionNodes = snapshot.nodes
        nodes = []
        proxyStatus = .online
        restartPolling()
        Task { [weak self] in
            await self?.refresh()
        }
    }

    /// Returns to the live multi-agent view, clearing any loaded history.
    func enterLiveView() {
        resetDeferredTraceUpdates()
        selectedSessionId = nil
        historyNodeIds = []
        sessionNodes = []
        nodes = []
        session = nil
        proxyStatus = .connecting
        restartPolling()
        Task { [weak self] in
            await self?.refresh()
        }
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
        if let snapshot = deferredSnapshot {
            deferredSnapshot = nil
            commit(snapshot: snapshot)
        }
    }

    /// Commits a snapshot, partitioning into history and live clusters when a
    /// historical session is loaded. Only writes when visible state changes.
    func commit(snapshot: TraceSnapshot) {
        let historyCluster: [AgentNode]
        let liveCluster: [AgentNode]
        if isHistoryView {
            historyCluster = snapshot.nodes
                .filter { historyNodeIds.contains($0.id) }
                .map(hydrated(_:))
            liveCluster = snapshot.nodes
                .filter { !historyNodeIds.contains($0.id) }
                .map(hydrated(_:))
        } else {
            historyCluster = []
            liveCluster = snapshot.nodes.map(hydrated(_:))
        }

        guard session != snapshot.session
            || nodes != liveCluster
            || sessionNodes != historyCluster
        else {
            return
        }

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            session = snapshot.session
            nodes = liveCluster
            sessionNodes = historyCluster
        }
    }

    /// Attaches any lazily loaded inspector payload to a graph summary node.
    private func hydrated(_ node: AgentNode) -> AgentNode {
        guard let detail = nodeDetails[node.id] else { return node }
        return node.hydrated(with: detail)
    }

    /// Drops buffered live updates after an explicit clear or new-session reset.
    func resetDeferredTraceUpdates() {
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
        guard let node = (nodes + sessionNodes).first(where: { $0.id == nodeId }),
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
            hydrateVisibleNode(nodeId, with: detail)
        } catch {
            // Local Codex nodes and stale proxy selections may not have proxy-side details.
        }
    }

    /// Replaces a node in whichever cluster currently holds it with its hydrated form.
    private func hydrateVisibleNode(_ nodeId: AgentNode.ID, with detail: AgentNode) {
        if let index = nodes.firstIndex(where: { $0.id == nodeId }) {
            let hydratedNode = nodes[index].hydrated(with: detail)
            if nodes[index] != hydratedNode {
                nodes[index] = hydratedNode
            }
        }

        if let index = sessionNodes.firstIndex(where: { $0.id == nodeId }) {
            let hydratedNode = sessionNodes[index].hydrated(with: detail)
            if sessionNodes[index] != hydratedNode {
                sessionNodes[index] = hydratedNode
            }
        }
    }

    /// Hydrates every currently visible summary node before full-fidelity export.
    func loadVisibleNodeDetailsIfNeeded() async {
        let nodeIds = (sessionNodes + nodes)
            .filter(\.needsDetailPayload)
            .map(\.id)

        for nodeId in nodeIds {
            await loadNodeDetailIfNeeded(nodeId)
        }
    }
}

extension AgentNode {
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
