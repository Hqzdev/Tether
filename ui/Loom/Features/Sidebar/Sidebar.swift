import ComposableArchitecture
import Core
import SwiftUI
import UI

/// Left pane listing proxy status, sessions, filters, and captured calls.
struct Sidebar: View {
    let nodes: [AgentNode]
    let filteredNodes: [AgentNode]
    let selectedNodeId: AgentNode.ID?
    @Binding var searchText: String
    let proxyStatus: ProxyConnectionStatus
    let sessions: [TraceSession]
    let selectedSessionId: TraceSession.ID?
    let liveSessionId: TraceSession.ID?
    let onSelectSession: (TraceSession.ID) -> Void
    let onSelect: (AgentNode) -> Void
    let onShowSettings: () -> Void
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            SidebarStatusHeader(proxyStatus: proxyStatus, palette: palette)

            SessionListView(
                store: Store(initialState: sessionListState) {
                    SessionListFeature()
                } withDependencies: {
                    $0.sessionSelectionClient.select = { sessionId in
                        await MainActor.run {
                            onSelectSession(sessionId)
                        }
                    }
                },
                palette: palette
            )

            SidebarSearchField(searchText: $searchText, palette: palette)
            SidebarSectionHeader(title: "Calls", detail: "\(filteredNodes.count) of \(nodes.count)", palette: palette)
            SidebarCallList(filteredNodes: filteredNodes, selectedNodeId: selectedNodeId, onSelect: onSelect, palette: palette)
            SidebarFooter(onShowSettings: onShowSettings, palette: palette)
        }
        .background(palette.panel.opacity(0.56))
    }

    private var sessionListState: SessionListFeature.State {
        SessionListFeature.State(
            sessions: sessions,
            selectedSessionId: selectedSessionId,
            liveSessionId: liveSessionId
        )
    }
}
