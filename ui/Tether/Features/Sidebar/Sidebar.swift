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

            SidebarSessionList(
                sessions: sessions,
                selectedSessionId: selectedSessionId,
                liveSessionId: liveSessionId,
                onSelectSession: onSelectSession,
                palette: palette
            )

            SidebarSearchField(searchText: $searchText, palette: palette)
            SidebarSectionHeader(title: "Calls", detail: "\(filteredNodes.count) of \(nodes.count)", palette: palette)
            SidebarCallList(filteredNodes: filteredNodes, selectedNodeId: selectedNodeId, onSelect: onSelect, palette: palette)
            SidebarFooter(onShowSettings: onShowSettings, palette: palette)
        }
        .background(palette.panel.opacity(0.56))
    }
}

/// Lightweight session picker that avoids recreating a TCA store on every sidebar refresh.
private struct SidebarSessionList: View {
    let sessions: [TraceSession]
    let selectedSessionId: TraceSession.ID?
    let liveSessionId: TraceSession.ID?
    let onSelectSession: (TraceSession.ID) -> Void
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            SidebarSectionHeader(title: "Sessions", detail: sessions.isEmpty ? "0" : "\(sessions.count)", palette: palette)

            ScrollView {
                LazyVStack(spacing: 1) {
                    if sessions.isEmpty {
                        SidebarSessionsEmptyState(palette: palette)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(sessions) { session in
                            SidebarSessionRow(
                                session: session,
                                selected: session.id == selectedSessionId,
                                live: session.id == liveSessionId,
                                onSelect: { onSelectSession(session.id) },
                                palette: palette
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 154)
            .scrollIndicators(.automatic)
        }
        .background(palette.panelSecondary.opacity(0.52))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }
}

private struct SidebarSessionsEmptyState: View {
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 22, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.textQuaternary)

            VStack(spacing: 3) {
                Text("No proxy sessions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)

                Text("Sessions appear here once traffic flows through the proxy.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.textQuaternary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1.5)
                    .frame(maxWidth: 200)
            }
        }
        .padding(.horizontal, 12)
    }
}

private struct SidebarSessionRow: View {
    let session: TraceSession
    let selected: Bool
    let live: Bool
    let onSelect: () -> Void
    let palette: AgentTracePalette

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 9) {
                Image(systemName: live ? "record.circle.fill" : "clock")
                    .font(.system(size: 13))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(live ? palette.green : palette.textTertiary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)

                    Text(session.startedAt)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(palette.textQuaternary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if live {
                    Text("Live")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(palette.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .liquidGlass(
                palette: palette,
                cornerRadius: palette.controlRadius,
                tint: selected ? palette.accent.opacity(0.16) : palette.glassTint.opacity(0.08),
                interactive: true,
                strokeOpacity: selected ? 0.82 : 0.32
            )
            .overlay(alignment: .leading) {
                if selected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(palette.accent)
                        .frame(width: 2.5)
                        .padding(.vertical, 8)
                        .offset(x: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
