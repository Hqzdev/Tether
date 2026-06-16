import Combine
import Core
import Foundation
import Networking
import SwiftUI

/// Main-actor owner of the session-history list. It polls `/api/sessions`
/// independently of `TraceStore` (which polls one session's traces), and drives
/// session loads/creation/rename/delete. The two stores cooperate through a
/// single weak reference rather than shared state.
@MainActor
final class SessionStore: ObservableObject {
    /// Sessions newest-first, as reported by the proxy.
    @Published var sessions: [Session] = []

    /// Session whose history is loaded into the graph. `nil` is the live view.
    @Published var activeSessionId: Session.ID?

    /// Session currently receiving live proxy traffic (for the "Live" marker).
    @Published var liveSessionId: Session.ID?

    /// Last error surfaced while talking to the proxy, for lightweight display.
    @Published var lastErrorMessage: String?

    private let client: TraceAPIClient
    private weak var traceStore: TraceStore?
    private var pollingTask: Task<Void, Never>?

    /// Creates a session store backed by the local proxy client.
    init(client: TraceAPIClient = TraceAPIClient()) {
        self.client = client
    }

    /// Connects the trace store the loaded session graph is pushed into.
    func attach(_ traceStore: TraceStore) {
        self.traceStore = traceStore
    }

    /// Starts the independent 5s session-list refresh loop.
    func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                await self.refreshNow()
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    break
                }
            }
        }
    }

    /// Stops the session-list refresh loop.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Refreshes the session list, preserving the user's active selection.
    func refreshNow() async {
        do {
            let list = try await client.sessionSummaries()
            sessions = list.sessions
            liveSessionId = list.currentSessionId
            lastErrorMessage = nil

            // Drop the active selection if its session was deleted out from under us.
            if let activeSessionId, !list.sessions.contains(where: { $0.id == activeSessionId }) {
                enterLiveView()
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Loads a historical session: routes new traffic into it and shows its graph.
    func loadSession(_ id: Session.ID) async {
        activeSessionId = id

        // Best-effort activation so new calls join this session; loading still
        // proceeds even if the proxy rejects the activate (e.g. transient error).
        _ = try? await client.activateSession(sessionId: id)

        do {
            let snapshot = try await client.sessionTraces(sessionId: id)
            traceStore?.loadHistory(snapshot, sessionId: id)
            lastErrorMessage = nil
        } catch {
            if activeSessionId == id {
                enterLiveView()
            }
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Creates a new empty session, activates it, and shows it as the live target.
    func createNewSession() async {
        do {
            let created = try await client.createSession()
            activeSessionId = created.id
            traceStore?.loadHistory(
                TraceSnapshot(session: created, nodes: []),
                sessionId: created.id
            )
            await refreshNow()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Renames a session and refreshes the list.
    func renameSession(_ id: Session.ID, to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            _ = try await client.renameSession(sessionId: id, name: trimmed)
            await refreshNow()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Soft-deletes a session, returning to the live view when it was active.
    func deleteSession(_ id: Session.ID) async {
        do {
            try await client.deleteSession(sessionId: id)
            if activeSessionId == id {
                enterLiveView()
            }
            await refreshNow()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Returns to the live multi-agent view without a loaded session.
    func enterLiveView() {
        activeSessionId = nil
        traceStore?.enterLiveView()
    }
}
