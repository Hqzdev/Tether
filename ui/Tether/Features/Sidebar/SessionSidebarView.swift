import Core
import SwiftUI
import UI

/// Chat-history style session list: a "New session" action above a scrollable
/// list of past sessions, newest first. Selecting a row loads that session's
/// graph; the live session is badged and a hovered row can be deleted.
struct SessionSidebarView: View {
    let sessions: [Session]
    let activeSessionId: Session.ID?
    let liveSessionId: Session.ID?
    let onSelectSession: (Session.ID) -> Void
    let onNewSession: () -> Void
    let onDeleteSession: (Session.ID) -> Void
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 1) {
                    if sessions.isEmpty {
                        SessionSidebarEmptyState(palette: palette)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(sessions) { session in
                            SessionRowView(
                                session: session,
                                selected: session.id == activeSessionId,
                                live: session.id == liveSessionId,
                                onSelect: { onSelectSession(session.id) },
                                onDelete: { onDeleteSession(session.id) },
                                palette: palette
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 196)
            .scrollIndicators(.automatic)
        }
        .background(palette.panelSecondary.opacity(0.52))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            SidebarSectionHeader(
                title: "Sessions",
                detail: sessions.isEmpty ? "0" : "\(sessions.count)",
                palette: palette
            )

            Spacer(minLength: 0)

            Button(action: onNewSession) {
                Label("New", systemImage: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .liquidGlass(
                        palette: palette,
                        cornerRadius: palette.controlRadius,
                        tint: palette.accent.opacity(0.16),
                        interactive: true,
                        strokeOpacity: 0.5
                    )
            }
            .buttonStyle(.plain)
            .help("Start a new session")
            .padding(.trailing, 12)
        }
    }
}

private struct SessionRowView: View {
    let session: Session
    let selected: Bool
    let live: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let palette: AgentTracePalette

    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 9) {
                Image(systemName: live ? "record.circle.fill" : "clock")
                    .font(.system(size: 13))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(live ? palette.green : palette.textTertiary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)

                    Text(session.startedAt)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(palette.textQuaternary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailingAccessory
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
        .onHover { hovering = $0 }
    }

    /// Shows a delete control while hovering, otherwise the call-count badge.
    @ViewBuilder
    private var trailingAccessory: some View {
        if hovering {
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.pink)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Delete session")
        } else {
            CallCountBadge(count: session.callCount, live: live, palette: palette)
        }
    }
}

private struct CallCountBadge: View {
    let count: Int
    let live: Bool
    let palette: AgentTracePalette

    var body: some View {
        Text(live ? "Live" : "\(count)")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(live ? palette.green : palette.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((live ? palette.green : palette.textTertiary).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
    }
}

private struct SessionSidebarEmptyState: View {
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 22, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.textQuaternary)

            VStack(spacing: 3) {
                Text("No sessions yet")
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
