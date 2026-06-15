import Core
import Foundation
import Networking

extension TraceStore {
    /// Clears every proxy trace and hides already-observed Codex events.
    func clearTrace() {
        Task {
            await clearAllTraces()
        }
    }

    /// Starts a new proxy session and resets local response edits.
    func startNewSession() {
        Task {
            await createNewSession()
        }
    }

    /// Selects a historical proxy session and refreshes its snapshot.
    func selectSession(_ sessionId: TraceSession.ID) {
        selectedSessionId = sessionId
        Task {
            await refresh()
        }
    }

    /// Requests a manual refresh from menu commands.
    func reload() {
        Task {
            await refresh()
        }
    }

    /// Loads the proxy session list without throwing through async-let boundaries.
    func loadProxySessions() async -> Result<TraceSessionList, Error> {
        do {
            return .success(try await client.sessions())
        } catch {
            return .failure(error)
        }
    }

    /// Loads a proxy trace snapshot without throwing through async-let boundaries.
    func loadProxySnapshot(sessionId: TraceSession.ID?) async -> Result<TraceSnapshot, Error> {
        do {
            return .success(try await client.currentTrace(sessionId: sessionId))
        } catch {
            return .failure(error)
        }
    }

    /// Loads the local Codex snapshot without failing the proxy refresh path.
    func loadCodexSnapshot() async -> Result<TraceSnapshot?, Error> {
        do {
            return .success(try await codexObserver.currentSnapshot(afterLogId: codexBaselineLogId))
        } catch {
            return .failure(error)
        }
    }

    /// Creates a fresh proxy session and uses the current Codex log id as a baseline.
    func createNewSession() async {
        codexBaselineLogId = try? await codexObserver.latestResponseEventId()
        session = nil
        nodes = []

        do {
            let newSession = try await client.createSession()
            selectedSessionId = newSession.id
            currentSessionId = newSession.id
            if !sessions.contains(where: { $0.id == newSession.id }) {
                sessions.insert(newSession, at: 0)
            }
            proxyStatus = .online
            await refresh()
        } catch {
            proxyStatus = .observingCodex("Open Terminal and run codex")
        }
    }

    /// Clears proxy traces and hides previously observed Codex events from the live graph.
    func clearAllTraces() async {
        codexBaselineLogId = try? await codexObserver.latestResponseEventId()
        session = nil
        nodes = []

        do {
            try await client.clearTrace()
            selectedSessionId = nil
            proxyStatus = .online
            await refresh()
        } catch {
            proxyStatus = .observingCodex("Open Terminal and run codex")
        }
    }

    /// Applies session list updates while preserving valid historical selections.
    func apply(sessionList: TraceSessionList) {
        sessions = sessionList.sessions
        currentSessionId = sessionList.currentSessionId

        if let selectedSessionId, sessions.contains(where: { $0.id == selectedSessionId }) {
            return
        }

        selectedSessionId = sessionList.currentSessionId ?? sessions.first?.id
    }
}
