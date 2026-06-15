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
        async let proxySessionsResult = loadProxySessions()
        async let codexResult = loadCodexSnapshot()

        let (sessionList, codex) = await (proxySessionsResult, codexResult)
        let proxySessions = try? sessionList.get()
        let codexSnapshot = try? codex.get()
        var proxySnapshot: TraceSnapshot?
        var proxyError: Error?

        if let proxySessions {
            apply(sessionList: proxySessions)
            let sessionId = selectedSessionId ?? proxySessions.currentSessionId
            let proxyResult = await loadProxySnapshot(sessionId: sessionId)
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
        session = snapshot.session
        nodes = snapshot.nodes
    }
}
