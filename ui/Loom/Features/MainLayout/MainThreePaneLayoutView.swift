import AppKit
import ComposableArchitecture
import Core
import Networking
import SwiftUI
import UI
import UniformTypeIdentifiers

struct MainThreePaneLayoutView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("agenttrace.themeMode") private var themeModeRaw = AgentTraceThemeMode.system.rawValue

    @StateObject private var traceStore = TraceStore()
    @State private var selectedNodeId: AgentNode.ID?
    @State private var inspectorTab: InspectorTab = .prompt
    @State private var searchText = ""
    @State private var responseEdits: [AgentNode.ID: String] = [:]
    @State private var compactSection: CompactSection = .graph
    @State private var showingClearConfirmation = false
    @State private var showingConnectionHelp = false

    private var themeMode: AgentTraceThemeMode {
        AgentTraceThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var palette: AgentTracePalette {
        AgentTracePalette(light: themeMode.isLight(systemColorScheme: systemColorScheme))
    }

    private var session: TraceSession? {
        traceStore.session
    }

    private var nodes: [AgentNode] {
        traceStore.nodes
    }

    private var filteredNodes: [AgentNode] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nodes }

        return nodes.filter { node in
            node.stepName.localizedCaseInsensitiveContains(query)
                || node.model.localizedCaseInsensitiveContains(query)
                || node.requestId.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedNode: AgentNode? {
        if let selectedNodeId, let node = nodes.first(where: { $0.id == selectedNodeId }) {
            return node
        }

        return nodes.first
    }

    private var totalLatencyMs: Int {
        nodes.reduce(0) { $0 + $1.latencyMs }
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = AdaptiveWorkspaceLayout(size: geometry.size)

            ZStack {
                StageBackground(palette: palette)

                VStack(spacing: 0) {
                    TitleBar(
                        session: session,
                        palette: palette
                    )

                    workspace(layout: layout, size: geometry.size)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.window.opacity(0.62))
            }
        }
        .ignoresSafeArea()
        .frame(minWidth: 800, minHeight: 520)
        .onAppear {
            _ = LocalProxyLauncher.shared.startIfAvailable()
            traceStore.startPolling()
        }
        .onDisappear {
            traceStore.stopPolling()
        }
        .onChange(of: traceStore.nodes) { _, newNodes in
            guard !newNodes.isEmpty else {
                selectedNodeId = nil
                return
            }

            if selectedNodeId == nil || !newNodes.contains(where: { $0.id == selectedNodeId }) {
                selectedNodeId = newNodes[0].id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceNewSession)) { _ in
            startNewSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceExportTraces)) { _ in
            exportTraces()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceCopySelection)) { _ in
            copySelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceClearAllTraces)) { _ in
            showingClearConfirmation = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceShowInspector)) { _ in
            compactSection = .inspector
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceShowGraph)) { _ in
            compactSection = .graph
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceReload)) { _ in
            traceStore.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceShowOnboarding)) { _ in
            showingConnectionHelp = true
        }
        .alert("Clear All Traces?", isPresented: $showingClearConfirmation) {
            Button("Clear All Traces", role: .destructive) {
                clearAllTraces()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently clears all proxy sessions and hides existing Terminal Codex events until new activity arrives.")
        }
        .sheet(isPresented: $showingConnectionHelp) {
            ConnectionHelpSheet()
        }
    }

    @ViewBuilder
    private func workspace(layout: AdaptiveWorkspaceLayout, size: CGSize) -> some View {
        switch layout.mode {
        case .wide:
            HStack(spacing: 0) {
                sidebarPane()
                    .frame(width: layout.sidebarWidth)

                DividerLine(palette: palette)

                graphPane()
                    .frame(minWidth: 360, maxWidth: .infinity)

                DividerLine(palette: palette)

                inspectorPane()
                    .frame(width: layout.inspectorWidth)
            }

        case .medium:
            HStack(spacing: 0) {
                sidebarPane()
                    .frame(width: layout.sidebarWidth)

                DividerLine(palette: palette)

                VStack(spacing: 0) {
                    graphPane()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HorizontalDividerLine(palette: palette)

                    inspectorPane()
                        .frame(height: layout.inspectorHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .compact:
            VStack(spacing: 0) {
                CompactSectionPicker(selection: $compactSection, palette: palette)

                HorizontalDividerLine(palette: palette)

                switch compactSection {
                case .calls:
                    sidebarPane()
                case .graph:
                    graphPane()
                case .inspector:
                    inspectorPane()
                }
            }
        }
    }

    private func sidebarPane() -> some View {
        Sidebar(
            nodes: nodes,
            filteredNodes: filteredNodes,
            selectedNodeId: selectedNode?.id,
            searchText: $searchText,
            proxyStatus: traceStore.proxyStatus,
            sessions: traceStore.sessions,
            selectedSessionId: traceStore.selectedSessionId,
            liveSessionId: traceStore.currentSessionId,
            onSelectSession: selectSession,
            onSelect: { selectedNodeId = $0.id },
            palette: palette
        )
    }

    private func graphPane() -> some View {
        GraphPane(
            session: session,
            nodes: nodes,
            selectedNode: selectedNode,
            totalLatencyMs: totalLatencyMs,
            onSelect: { selectedNodeId = $0.id },
            palette: palette
        )
    }

    private func inspectorPane() -> some View {
        InspectorPane(
            node: selectedNode,
            tab: $inspectorTab,
            responseEdits: $responseEdits,
            palette: palette
        )
    }

    private func startNewSession() {
        responseEdits.removeAll()
        selectedNodeId = nil
        traceStore.startNewSession()
    }

    private func clearAllTraces() {
        responseEdits.removeAll()
        selectedNodeId = nil
        traceStore.clearTrace()
    }

    private func selectSession(_ sessionId: TraceSession.ID) {
        responseEdits.removeAll()
        selectedNodeId = nil
        traceStore.selectSession(sessionId)
    }

    private func copySelection() {
        guard let text = clipboardTextForSelectedNode(), !text.isEmpty else {
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func clipboardTextForSelectedNode() -> String? {
        guard let node = selectedNode else { return nil }

        switch inspectorTab {
        case .prompt:
            return """
            system:
            \(node.prompt.system)

            user:
            \(node.prompt.user)
            """
        case .response:
            return responseEdits[node.id] ?? node.response.text
        case .metadata:
            return """
            id: \(node.id)
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

    private func exportTraces() {
        let snapshot = TraceSnapshot(session: session, nodes: nodes)
        let panel = NSSavePanel()
        panel.title = "Export Traces"
        panel.nameFieldStringValue = "AgentTrace-\(exportTimestamp()).json"
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

    private func jsonData(for snapshot: TraceSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    private func csvData(for snapshot: TraceSnapshot) -> Data {
        var rows = [
            [
                "session_id",
                "session_title",
                "node_id",
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

        let csv = rows
            .map { row in row.map(escapeCSV).joined(separator: ",") }
            .joined(separator: "\n")

        return Data(csv.utf8)
    }

    private func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func exportTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

private enum WorkspaceMode {
    case wide
    case medium
    case compact
}

private struct AdaptiveWorkspaceLayout {
    let mode: WorkspaceMode
    let sidebarWidth: CGFloat
    let inspectorWidth: CGFloat
    let inspectorHeight: CGFloat

    init(size: CGSize) {
        if size.width >= 1180, size.height >= 560 {
            mode = .wide
        } else if size.width >= 820, size.height >= 500 {
            mode = .medium
        } else {
            mode = .compact
        }

        sidebarWidth = min(max(size.width * 0.24, 240), mode == .wide ? 312 : 286)
        inspectorWidth = min(max(size.width * 0.28, 320), 432)
        inspectorHeight = min(max(size.height * 0.34, 210), 320)
    }
}

private enum CompactSection: String, CaseIterable, Identifiable {
    case calls = "Calls"
    case graph = "Graph"
    case inspector = "Inspector"

    var id: String { rawValue }
}

private struct CompactSectionPicker: View {
    @Binding var selection: CompactSection
    let palette: AgentTracePalette

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(CompactSection.allCases) { section in
                Text(section.rawValue)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(palette.panelSecondary.opacity(0.56))
    }
}

private struct ConnectionHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 16) {
                Image(systemName: "terminal")
                    .font(.largeTitle)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text("How to Connect an Agent")
                        .font(.title)
                        .fontWeight(.semibold)

                    Text("AgentTrace watches local Codex sessions and proxy traffic on this Mac.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HelpRow(systemImage: "1.circle", title: "Open Terminal", detail: "Run codex from any terminal session.")
                HelpRow(systemImage: "2.circle", title: "Keep AgentTrace Open", detail: "The workspace updates as new agent calls arrive.")
                HelpRow(systemImage: "3.circle", title: "Use Proxy Settings", detail: "Configure port, upstream URLs, and cache from Settings.")
            }

            HStack {
                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(.windowBackground)
    }
}

private struct HelpRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MainThreePaneLayoutView_Previews: PreviewProvider {
    static var previews: some View {
        MainThreePaneLayoutView()
    }
}
