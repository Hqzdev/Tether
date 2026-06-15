import Core
import SwiftUI
import UI

/// Pannable and draggable viewport for the graph canvas.
struct GraphViewport: View {
    let freeformCanvasPadding: CGFloat = 360
    let panOverscrollPadding: CGFloat = 420
    let nodeBoundaryInset: CGFloat = 96
    let minimumCanvasSize = CGSize(width: 2_400, height: 1_600)
    let verticalNodeSpacing: CGFloat = 156

    let nodes: [AgentNode]
    let selectedNode: AgentNode?
    let nodeSize: CGSize
    let depthSpacing: CGFloat
    @Binding var nodeOffsets: [AgentNode.ID: CGSize]
    @Binding var nodeSizes: [AgentNode.ID: CGSize]
    let zoomScale: CGFloat
    let onSelect: (AgentNode) -> Void
    let onZoom: (CGFloat, Bool) -> Void
    let palette: AgentTracePalette

    @State var panOffset: CGSize = .zero
    @State var activeDrag: ActiveNodeDrag?
    @State var activeInteraction: ActiveCanvasInteraction?

    var contentSize: CGSize {
        let movedBounds = nodeBounds
        return CGSize(
            width: max(minimumCanvasSize.width, movedBounds.maxX + freeformCanvasPadding),
            height: max(minimumCanvasSize.height, movedBounds.maxY + freeformCanvasPadding)
        )
    }

    var nodeBounds: CGRect {
        guard !nodes.isEmpty else { return CGRect(origin: .zero, size: nodeSize) }

        return nodes.enumerated().reduce(CGRect.null) { bounds, indexedNode in
            let node = indexedNode.element
            let origin = position(for: node, at: indexedNode.offset)
            let size = nodeSizes[node.id] ?? nodeSize
            return bounds.union(CGRect(origin: origin, size: size))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(palette.window.opacity(0.44))
                    .contentShape(Rectangle())

                GraphCanvas(
                    nodes: nodes,
                    selectedNode: selectedNode,
                    nodeSize: nodeSize,
                    contentSize: contentSize,
                    nodeOffsets: nodeOffsets,
                    nodeSizes: nodeSizes,
                    activeDrag: activeDrag,
                    zoomScale: zoomScale,
                    palette: palette
                )
                .offset(panOffset)
            }
            .clipped()
            .coordinateSpace(name: "graphCanvas")
            .contentShape(Rectangle())
            .highPriorityGesture(canvasInteractionGesture(viewportSize: geometry.size))
            .background(
                MacCanvasEventBridge(
                    onScroll: { delta in panBy(delta, viewportSize: geometry.size) },
                    onMagnify: { delta in onZoom(zoomScale * max(0.2, 1 + delta), false) }
                )
            )
            .onChange(of: zoomScale) { _, _ in
                panOffset = clampedPan(panOffset, viewportSize: geometry.size)
            }
            .onChange(of: nodes.count) { _, _ in
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    panOffset = clampedPan(panOffset, viewportSize: geometry.size)
                }
            }
        }
    }
}
