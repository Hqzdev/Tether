import Core
import SwiftUI
import UI

/// Scaled canvas containing connection paths and draggable node cards.
struct GraphCanvas: View {
    private let verticalNodeSpacing: CGFloat = 156
    private let nodeBoundaryInset: CGFloat = 96

    let nodes: [AgentNode]
    let selectedNode: AgentNode?
    let nodeSize: CGSize
    let contentSize: CGSize
    let nodeOffsets: [AgentNode.ID: CGSize]
    let nodeSizes: [AgentNode.ID: CGSize]
    let activeDrag: ActiveNodeDrag?
    let isInteractionActive: Bool
    let zoomScale: CGFloat
    let palette: AgentTracePalette

    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        ZStack(alignment: .topLeading) {
            if nodes.isEmpty {
                GraphEmptyState()
                    .frame(width: contentSize.width, height: contentSize.height)
            } else {
                if preferences.showConnections {
                    connectionLayers
                }

                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    MovableNodeCard(
                        node: NodeCardModel(node: node),
                        selected: node.id == selectedNode?.id,
                        basePosition: defaultPosition(for: index),
                        currentOffset: currentOffset(for: node),
                        nodeSize: nodeSizes[node.id] ?? nodeSize,
                        isDragging: activeDrag?.nodeId == node.id,
                        isPerformanceMode: isInteractionActive,
                        palette: palette
                    )
                    .equatable()
                }
            }
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .scaleEffect(zoomScale, anchor: .topLeading)
        .frame(width: contentSize.width * zoomScale, height: contentSize.height * zoomScale, alignment: .topLeading)
    }

    @ViewBuilder
    private var connectionLayers: some View {
        GraphConnections(
            nodes: connectionNodes,
            positions: persistedPositions,
            contentSize: contentSize,
            nodeSizes: nodeSizes,
            defaultNodeSize: nodeSize,
            scope: activeDrag.map { .excluding(nodeId: $0.nodeId) } ?? .all,
            palette: palette
        )
        .equatable()

        if let activeDrag {
            GraphConnections(
                nodes: connectionNodes,
                positions: currentPositions,
                contentSize: contentSize,
                nodeSizes: nodeSizes,
                defaultNodeSize: nodeSize,
                scope: .only(nodeId: activeDrag.nodeId),
                palette: palette
            )
            .equatable()
        }
    }

    private var connectionNodes: [GraphConnectionNode] {
        nodes.map { GraphConnectionNode(id: $0.id, status: $0.status) }
    }

    private var currentPositions: [AgentNode.ID: CGPoint] {
        Dictionary(uniqueKeysWithValues: nodes.enumerated().map { index, node in
            let base = defaultPosition(for: index)
            let offset = currentOffset(for: node)
            return (node.id, CGPoint(x: base.x + offset.width, y: base.y + offset.height))
        })
    }

    private var persistedPositions: [AgentNode.ID: CGPoint] {
        Dictionary(uniqueKeysWithValues: nodes.enumerated().map { index, node in
            let base = defaultPosition(for: index)
            let offset = nodeOffsets[node.id] ?? .zero
            return (node.id, CGPoint(x: base.x + offset.width, y: base.y + offset.height))
        })
    }

    /// Returns the active drag offset or the persisted node offset.
    private func currentOffset(for node: AgentNode) -> CGSize {
        if activeDrag?.nodeId == node.id {
            return activeDrag?.offset ?? .zero
        }

        return nodeOffsets[node.id] ?? .zero
    }

    /// Returns the automatic canvas position for a node index.
    private func defaultPosition(for index: Int) -> CGPoint {
        CGPoint(x: nodeBoundaryInset, y: nodeBoundaryInset + CGFloat(index) * verticalNodeSpacing)
    }
}

private struct GraphEmptyState: View {
    var body: some View {
        ContentUnavailableView(
            "No Traces Yet",
            systemImage: "network",
            description: Text("Run codex in Terminal or send traffic through the proxy")
        )
    }
}
