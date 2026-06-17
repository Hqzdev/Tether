import Core
import SwiftUI
import UI

/// Scaled canvas containing connection paths and draggable node cards.
///
/// Nodes arrive history-first: the first `historyCount` entries form the
/// read-only history cluster (left column, muted), the rest are live calls
/// (offset to the right). No edge is drawn across the two clusters.
struct GraphCanvas: View {
    private let verticalNodeSpacing: CGFloat = 156
    private let nodeBoundaryInset: CGFloat = 96
    private let historyOpacity: CGFloat = 0.7

    let nodes: [AgentNode]
    let historyCount: Int
    let selectedNode: AgentNode?
    let nodeSize: CGSize
    let contentSize: CGSize
    let positionStore: GraphNodePositionStore
    let nodeSizes: [AgentNode.ID: CGSize]
    let activeDragNodeId: AgentNode.ID?
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
                    let source = NodeSource.of(index: index, historyCount: historyCount)
                    MovableNodeCard(
                        node: NodeCardModel(node: node),
                        nodePosition: positionStore.positionState(for: node.id, defaultPosition: defaultPosition(for: index)),
                        selected: node.id == selectedNode?.id,
                        nodeSize: nodeSizes[node.id] ?? nodeSize,
                        isPerformanceMode: isInteractionActive || source == .history,
                        palette: palette
                    )
                    .equatable()
                    .opacity(source == .history ? historyOpacity : 1)
                    .environment(\.nodeSource, source)
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
            scope: activeDragNodeId.map { .excluding(nodeId: $0) } ?? .all,
            clusterBoundaryIndex: clusterBoundaryIndex,
            palette: palette
        )
        .equatable()

        if let activeDragNodeId {
            LiveGraphConnections(
                nodes: connectionNodes,
                positionStore: positionStore,
                activePosition: positionStore.positionState(
                    for: activeDragNodeId,
                    defaultPosition: defaultPositions[activeDragNodeId] ?? defaultPosition(for: 0)
                ),
                activeNodeId: activeDragNodeId,
                contentSize: contentSize,
                nodeSizes: nodeSizes,
                defaultNodeSize: nodeSize,
                defaultPositions: defaultPositions,
                clusterBoundaryIndex: clusterBoundaryIndex,
                palette: palette
            )
        }
    }

    /// Index of the first live node, where the history→live edge is suppressed.
    /// `nil` when either cluster is empty (there is no boundary to break).
    private var clusterBoundaryIndex: Int? {
        guard historyCount > 0, historyCount < nodes.count else { return nil }
        return historyCount
    }

    private var connectionNodes: [GraphConnectionNode] {
        nodes.map { GraphConnectionNode(id: $0.id, status: $0.status) }
    }

    private var defaultPositions: [AgentNode.ID: CGPoint] {
        Dictionary(uniqueKeysWithValues: nodes.enumerated().map { index, node in
            (node.id, defaultPosition(for: index))
        })
    }

    private var persistedPositions: [AgentNode.ID: CGPoint] {
        Dictionary(uniqueKeysWithValues: nodes.enumerated().map { index, node in
            let base = defaultPosition(for: index)
            return (node.id, positionStore.persistedPosition(for: node.id, defaultPosition: base))
        })
    }

    /// Returns the automatic canvas position for a node index, accounting for the
    /// history (left) and live (right-offset) clusters.
    private func defaultPosition(for index: Int) -> CGPoint {
        GraphClusterLayout.defaultPosition(
            index: index,
            historyCount: historyCount,
            nodeSize: nodeSize,
            inset: nodeBoundaryInset,
            spacing: verticalNodeSpacing
        )
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
