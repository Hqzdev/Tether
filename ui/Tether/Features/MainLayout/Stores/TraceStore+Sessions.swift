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

    /// Requests a manual refresh from menu commands.
    func reload() {
        Task {
            await refresh()
        }
    }

    /// Loads a proxy trace snapshot without throwing through async-let boundaries.
    func loadProxySnapshot(sessionId: TraceSession.ID?) async -> Result<TraceSnapshot, Error> {
        do {
            return .success(try await client.currentTraceSummary(sessionId: sessionId))
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

    /// Clears proxy traces, returns to the live view, and hides previously observed
    /// Codex events until new activity arrives.
    func clearAllTraces() async {
        codexBaselineLogId = try? await codexObserver.latestResponseEventId()
        resetDeferredTraceUpdates()
        selectedSessionId = nil
        historyNodeIds = []
        sessionNodes = []
        session = nil
        nodes = []

        do {
            try await client.clearTrace()
            proxyStatus = .online
            await refresh()
        } catch {
            proxyStatus = .observingCodex("Open Terminal and run codex")
        }
    }
}
