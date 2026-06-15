import Core
import Networking
import SwiftUI
import UI

/// Main desktop workspace containing sidebar, graph canvas, inspector, and settings overlay.
struct MainThreePaneLayoutView: View {
    @StateObject var traceStore = TraceStore()
    @State var selectedNodeId: AgentNode.ID?
    @State var inspectorTab: InspectorTab = .prompt
    @State var searchText = ""
    @State var responseEdits: [AgentNode.ID: String] = [:]
    @State var compactSection: CompactSection = .graph
    @State var showingClearConfirmation = false
    @State var showingConnectionHelp = false
    @State var showingSettings = false

    var palette: AgentTracePalette {
        AgentTracePalette(light: true)
    }

    var session: TraceSession? {
        traceStore.session
    }

    var nodes: [AgentNode] {
        traceStore.nodes
    }

    var filteredNodes: [AgentNode] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nodes }

        return nodes.filter { node in
            node.stepName.localizedCaseInsensitiveContains(query)
                || node.agentName.localizedCaseInsensitiveContains(query)
                || node.model.localizedCaseInsensitiveContains(query)
                || node.requestId.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedNode: AgentNode? {
        if let selectedNodeId, let node = nodes.first(where: { $0.id == selectedNodeId }) {
            return node
        }

        return nodes.first
    }

    var totalLatencyMs: Int {
        nodes.reduce(0) { $0 + $1.latencyMs }
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = AdaptiveWorkspaceLayout(size: geometry.size)

            ZStack {
                StageBackground(palette: palette)

                VStack(spacing: 0) {
                    TitleBar(session: session, palette: palette)
                    workspace(layout: layout, size: geometry.size)
                        .workspaceSurface(layout: layout, palette: palette)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: showingSettings ? 3 : 0)
                .saturation(showingSettings ? 0.78 : 1)
                .animation(.smooth(duration: 0.16), value: showingSettings)

                if showingSettings {
                    WorkspaceSettingsOverlay(
                        palette: palette,
                        onDismiss: {
                            withAnimation(.smooth(duration: 0.16)) {
                                showingSettings = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(20)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .frame(minWidth: 800, minHeight: 520)
        .onAppear {
            _ = LocalProxyLauncher.shared.startIfAvailable()
            traceStore.startPolling()
        }
        .onDisappear {
            traceStore.stopPolling()
        }
        .onChange(of: traceStore.nodes) { _, newNodes in
            syncSelectedNode(with: newNodes)
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
        .onReceive(NotificationCenter.default.publisher(for: .agentTraceShowSettings)) { _ in
            withAnimation(.smooth(duration: 0.16)) {
                showingSettings = true
            }
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

    /// Keeps the selected node valid as trace snapshots refresh.
    func syncSelectedNode(with newNodes: [AgentNode]) {
        guard !newNodes.isEmpty else {
            selectedNodeId = nil
            return
        }

        if selectedNodeId == nil || !newNodes.contains(where: { $0.id == selectedNodeId }) {
            selectedNodeId = newNodes[0].id
        }
    }
}
