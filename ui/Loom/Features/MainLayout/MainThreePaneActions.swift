import AppKit
import Core
import Foundation
import UniformTypeIdentifiers

extension MainThreePaneLayoutView {
    /// Starts a new trace session and clears transient UI selections.
    func startNewSession() {
        responseEdits.removeAll()
        selectedNodeId = nil
        traceStore.startNewSession()
    }

    /// Clears all traces and resets transient UI state.
    func clearAllTraces() {
        responseEdits.removeAll()
        selectedNodeId = nil
        traceStore.clearTrace()
    }

    /// Selects a historical session from the sidebar.
    func selectSession(_ sessionId: TraceSession.ID) {
        responseEdits.removeAll()
        selectedNodeId = nil
        traceStore.selectSession(sessionId)
    }

    /// Copies the currently selected inspector content to the pasteboard.
    func copySelection() {
        guard let text = clipboardTextForSelectedNode(), !text.isEmpty else {
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Exports the current trace snapshot as JSON or CSV.
    func exportTraces() {
        let snapshot = TraceSnapshot(session: session, nodes: nodes)
        let panel = NSSavePanel()
        panel.title = "Export Traces"
        panel.nameFieldStringValue = "Tether-\(exportTimestamp()).json"
        panel.allowedContentTypes = [.json, .commaSeparatedText]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                let data = url.pathExtension.lowercased() == "csv"
                    ? csvData(for: snapshot)
                    : try jsonData(for: snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    /// Returns pasteboard text matching the active inspector tab.
    func clipboardTextForSelectedNode() -> String? {
        guard let node = selectedNode else { return nil }

        switch inspectorTab {
        case .prompt:
            return "system:\n\(node.prompt.system)\n\nuser:\n\(node.prompt.user)"
        case .response:
            return responseEdits[node.id] ?? node.response.text
        case .metadata:
            return metadataClipboardText(for: node)
        }
    }

    /// Encodes a snapshot for JSON export.
    func jsonData(for snapshot: TraceSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    /// Encodes a snapshot for CSV export.
    func csvData(for snapshot: TraceSnapshot) -> Data {
        let rows = csvRows(for: snapshot)
        let csv = rows
            .map { row in row.map(escapeCSV).joined(separator: ",") }
            .joined(separator: "\n")

        return Data(csv.utf8)
    }

    /// Escapes a value for RFC4180-style CSV output.
    func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    /// Creates a timestamp suffix for exported trace files.
    func exportTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
