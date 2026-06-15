import Core
import SwiftUI
import UI

/// One captured call row in the sidebar list.
struct CallRow: View {
    let node: AgentNode
    let selected: Bool
    let onSelect: () -> Void
    let palette: AgentTracePalette

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 9) {
                StatusDot(status: node.status, palette: palette, size: 12)
                    .padding(.top, 3)
                    .frame(width: 16)
                CallRowBody(node: node, palette: palette)
                CallRowMetrics(node: node, palette: palette)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(selected ? palette.active.opacity(0.60) : palette.glassTint.opacity(0.03))
            .liquidGlass(
                palette: palette,
                cornerRadius: palette.controlRadius,
                tint: selected ? palette.accent.opacity(0.18) : palette.glassTint.opacity(0.08),
                interactive: true,
                strokeOpacity: selected ? 0.82 : 0.32
            )
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(selected ? palette.borderStrong : Color.clear, lineWidth: 1)
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
