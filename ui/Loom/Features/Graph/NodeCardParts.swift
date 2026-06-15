import Core
import SwiftUI
import UI

/// Header row for a graph node card.
struct NodeCardHeader: View {
    let node: AgentNode
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 9) {
            StatusDot(status: node.status, palette: palette)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.stepName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(nil)

                HStack(spacing: 6) {
                    AgentBadge(name: node.agentName, palette: palette)
                    Text("\(node.model) - \(node.requestId)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(palette.textQuaternary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(node.status.label)
                .font(.system(size: 9.5, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(palette.color(for: node.status))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(palette.background(for: node.status))
                .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
        }
    }
}

/// Footer row for latency, cost, and token counts.
struct NodeCardFooter: View {
    let node: AgentNode
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 10) {
            NodeFootnote(label: "lat", text: node.latency, palette: palette)
            NodeFootnote(label: "cost", text: node.cost, palette: palette)

            Spacer(minLength: 0)

            Text("\(node.tokensIn) down \(node.tokensOut) up tok")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(palette.textTertiary)
                .lineLimit(nil)
        }
        .padding(.top, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(palette.border)
        }
        .padding(.top, 10)
    }
}

/// Background fill for a node card.
struct NodeCardBackground: View {
    let selected: Bool
    let palette: AgentTracePalette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.nodeTop.opacity(0.62), palette.nodeBottom.opacity(0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if selected {
                palette.accentBackground.opacity(0.85)
            }
        }
    }
}

/// Border treatment for selected and inactive node cards.
struct NodeCardBorder: View {
    let selected: Bool
    let palette: AgentTracePalette

    var body: some View {
        RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
            .stroke(selected ? palette.accent : palette.borderStrong, lineWidth: selected ? 2 : 1)
    }
}
