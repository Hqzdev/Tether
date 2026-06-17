import Core
import SwiftUI
import UI

/// Draws curved edges between graph node cards.
struct GraphConnections: View, Equatable {
    let nodes: [GraphConnectionNode]
    let positions: [AgentNode.ID: CGPoint]
    let contentSize: CGSize
    let nodeSizes: [AgentNode.ID: CGSize]
    let defaultNodeSize: CGSize
    let scope: GraphConnectionScope
    /// Index of the first live node; the edge into it from history is not drawn.
    var clusterBoundaryIndex: Int?
    let palette: AgentTracePalette

    var body: some View {
        Canvas { context, _ in
            guard nodes.count > 1 else { return }

            for index in 1..<nodes.count {
                drawConnection(at: index, in: context)
            }
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// Draws one edge from the previous node to the current node.
    private func drawConnection(at index: Int, in context: GraphicsContext) {
        // Never bridge the history cluster and the live cluster.
        if clusterBoundaryIndex == index {
            return
        }

        let previous = nodes[index - 1]
        let current = nodes[index]

        guard scope.includes(previousId: previous.id, currentId: current.id) else {
            return
        }

        guard let from = positions[previous.id], let to = positions[current.id] else {
            return
        }

        let fromSize = nodeSizes[previous.id] ?? defaultNodeSize
        let toSize = nodeSizes[current.id] ?? defaultNodeSize
        let anchors = bestAnchorPair(from: from, sourceSize: fromSize, to: to, targetSize: toSize)
        let controlPoints = controlPoints(for: anchors)

        var path = Path()
        path.move(to: anchors.start)
        path.addCurve(to: anchors.end, control1: controlPoints.first, control2: controlPoints.second)

        let edgeColor = palette.color(for: current.status)
        context.stroke(path, with: .color(edgeColor), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        drawEndpoint(at: anchors.end, color: edgeColor, in: context)
    }

    /// Draws the circular endpoint marker for an edge.
    private func drawEndpoint(at point: CGPoint, color: Color, in context: GraphicsContext) {
        let marker = Path(ellipseIn: CGRect(x: point.x - 5.5, y: point.y - 5.5, width: 11, height: 11))
        context.fill(marker, with: .color(palette.window))
        context.stroke(marker, with: .color(color), lineWidth: 2)
    }

    /// Chooses the lowest-penalty pair of source and target anchors.
    private func bestAnchorPair(from sourceOrigin: CGPoint, sourceSize: CGSize, to targetOrigin: CGPoint, targetSize: CGSize) -> NodeAnchorPair {
        let sourceCenter = sourceOrigin.center(in: sourceSize)
        let targetCenter = targetOrigin.center(in: targetSize)
        let centerDelta = CGSize(width: targetCenter.x - sourceCenter.x, height: targetCenter.y - sourceCenter.y)
        let preferredSides = preferredAnchorSides(for: centerDelta)
        var bestPair: NodeAnchorPair?
        var bestScore = CGFloat.infinity

        for startSide in NodeAnchorSide.allCases {
            for endSide in NodeAnchorSide.allCases {
                let pair = NodeAnchorPair(startSide: startSide, endSide: endSide, sourceOrigin: sourceOrigin, sourceSize: sourceSize, targetOrigin: targetOrigin, targetSize: targetSize)
                let score = pair.score(preferredSides: preferredSides)
                if score < bestScore {
                    bestScore = score
                    bestPair = pair
                }
            }
        }

        return bestPair ?? NodeAnchorPair(start: .zero, end: .zero, startSide: .right, endSide: .left, distance: 0)
    }

    /// Prefers horizontal or vertical anchor flow based on center delta.
    private func preferredAnchorSides(for delta: CGSize) -> (start: NodeAnchorSide, end: NodeAnchorSide) {
        if abs(delta.width) >= abs(delta.height) {
            return delta.width >= 0 ? (.right, .left) : (.left, .right)
        }

        return delta.height >= 0 ? (.bottom, .top) : (.top, .bottom)
    }

    /// Builds Bezier control points from the selected anchor pair.
    private func controlPoints(for anchors: NodeAnchorPair) -> (first: CGPoint, second: CGPoint) {
        if anchors.startSide.isVertical && anchors.endSide.isVertical {
            let distance = abs(anchors.end.y - anchors.start.y) * 0.5
            let direction: CGFloat = anchors.end.y >= anchors.start.y ? 1 : -1
            return (CGPoint(x: anchors.start.x, y: anchors.start.y + distance * direction), CGPoint(x: anchors.end.x, y: anchors.end.y - distance * direction))
        }

        let controlDistance = max(28, min(160, anchors.distance * 0.45))
        return (anchors.start.offset(by: anchors.startSide.normal, distance: controlDistance), anchors.end.offset(by: anchors.endSide.normal, distance: controlDistance))
    }
}

/// Redraws only the connection edges touching the active dragged node.
struct LiveGraphConnections: View {
    let nodes: [GraphConnectionNode]
    let positionStore: GraphNodePositionStore
    @ObservedObject var activePosition: GraphNodePosition
    let activeNodeId: AgentNode.ID
    let contentSize: CGSize
    let nodeSizes: [AgentNode.ID: CGSize]
    let defaultNodeSize: CGSize
    let defaultPositions: [AgentNode.ID: CGPoint]
    var clusterBoundaryIndex: Int?
    let palette: AgentTracePalette

    var body: some View {
        GraphConnections(
            nodes: nodes,
            positions: currentPositions,
            contentSize: contentSize,
            nodeSizes: nodeSizes,
            defaultNodeSize: defaultNodeSize,
            scope: .only(nodeId: activeNodeId),
            clusterBoundaryIndex: clusterBoundaryIndex,
            palette: palette
        )
    }

    private var currentPositions: [AgentNode.ID: CGPoint] {
        Dictionary(uniqueKeysWithValues: nodes.map { node in
            let defaultPosition = defaultPositions[node.id] ?? .zero
            let position = node.id == activePosition.id
                ? activePosition.position
                : positionStore.persistedPosition(for: node.id, defaultPosition: defaultPosition)
            return (node.id, position)
        })
    }
}

/// Lightweight connection model that excludes inspector-only node payloads.
struct GraphConnectionNode: Equatable {
    let id: AgentNode.ID
    let status: NodeStatus
}

/// Controls which edges a connection layer draws.
enum GraphConnectionScope: Equatable {
    case all
    case excluding(nodeId: AgentNode.ID)
    case only(nodeId: AgentNode.ID)

    func includes(previousId: AgentNode.ID, currentId: AgentNode.ID) -> Bool {
        switch self {
        case .all:
            return true
        case let .excluding(nodeId):
            return previousId != nodeId && currentId != nodeId
        case let .only(nodeId):
            return previousId == nodeId || currentId == nodeId
        }
    }
}
