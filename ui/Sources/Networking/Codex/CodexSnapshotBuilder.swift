import Core
import Foundation

extension CodexLogObserver {
    /// Loads the latest Codex thread and converts its response events into a trace snapshot.
    nonisolated static func loadSnapshot(afterLogId baselineLogId: Int?) throws -> TraceSnapshot? {
        guard CodexDatabase.allDatabasesExist else {
            return nil
        }

        guard let thread = try latestThread(from: CodexDatabase.statePath) else {
            return nil
        }

        let events = try responseEvents(for: thread.id, from: CodexDatabase.logsPath, afterLogId: baselineLogId)
        let nodes = makeNodes(from: events, thread: thread)
        let session = TraceSession(
            id: thread.id,
            title: title(for: thread),
            trigger: "Terminal Codex",
            startedAt: formatClock(seconds: thread.createdAt ?? thread.updatedAt ?? 0)
        )

        return TraceSnapshot(session: session, nodes: nodes)
    }

    /// Returns a compact user-facing title for a Codex thread.
    nonisolated static func title(for thread: CodexThreadRow) -> String {
        let source = thread.title ?? thread.preview ?? thread.firstUserMessage ?? "Codex Terminal Session"
        return truncate(firstLine(source), limit: 86)
    }

    /// Returns the prompt text shown in the inspector for a Codex thread.
    nonisolated static func promptText(for thread: CodexThreadRow) -> String {
        let prompt = thread.preview ?? thread.firstUserMessage ?? thread.title ?? "Terminal Codex session"
        return truncate(prompt.trimmingCharacters(in: .whitespacesAndNewlines), limit: 4_000)
    }
}
