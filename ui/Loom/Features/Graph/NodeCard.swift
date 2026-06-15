import Core
import SwiftUI
import UI

/// Positions a node card on the canvas without participating in hit testing.
struct MovableNodeCard: View {
    let node: AgentNode
    let selected: Bool
    let basePosition: CGPoint
    let currentOffset: CGSize
    let nodeSize: CGSize
    let isDragging: Bool
    let palette: AgentTracePalette

    var body: some View {
        NodeCard(node: node, selected: selected, size: nodeSize, palette: palette)
            .position(x: basePosition.x + currentOffset.width + nodeSize.width / 2, y: basePosition.y + currentOffset.height + nodeSize.height / 2)
            .scaleEffect(isDragging ? 1.008 : 1)
            .zIndex(isDragging ? 30 : selected ? 10 : 1)
            .contentShape(RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
            .allowsHitTesting(false)
            .transaction { transaction in
                if isDragging {
                    transaction.animation = nil
                }
            }
    }
}

private struct NodeCard: View {
    let node: AgentNode
    let selected: Bool
    let size: CGSize
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            NodeCardHeader(node: node, palette: palette)
            ProgressBar(value: node.barPercent, status: node.status, palette: palette)
                .padding(.top, 9)
            NodeCardFooter(node: node, palette: palette)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .background(NodeCardBackground(selected: selected, palette: palette))
        .clipShape(RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(palette.color(for: node.status))
                .frame(width: 3)
                .padding(.vertical, 10)
        }
        .overlay(NodeCardBorder(selected: selected, palette: palette))
        .shadow(color: selected ? Color(hex: 0x0f172a).opacity(0.10) : .clear, radius: 12, x: 0, y: 6)
        .overlay { NodeAnchorMarkers(palette: palette) }
        .contentShape(RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(6)
        }
    }
}
