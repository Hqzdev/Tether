import Core
import SwiftUI

extension GraphViewport {
    /// Applies the user's invert-scroll preference to a raw scroll delta.
    func scrollDelta(_ delta: CGSize) -> CGSize {
        guard preferences.invertScroll else { return delta }
        return CGSize(width: -delta.width, height: -delta.height)
    }

    /// Rounds a node offset to the snap grid when snap-to-grid is enabled.
    func snappedOffset(_ offset: CGSize) -> CGSize {
        guard preferences.snapToGrid else { return offset }
        let grid: CGFloat = 24
        return CGSize(
            width: (offset.width / grid).rounded() * grid,
            height: (offset.height / grid).rounded() * grid
        )
    }

    /// Applies trackpad or mouse-wheel panning inside the viewport bounds.
    func panBy(_ delta: CGSize, viewportSize: CGSize) {
        panOffset = clampedPan(
            CGSize(width: panOffset.width + delta.width, height: panOffset.height + delta.height),
            viewportSize: viewportSize
        )
    }

    /// Clamps the canvas offset so users can pan around content without losing it.
    func clampedPan(_ offset: CGSize, viewportSize: CGSize) -> CGSize {
        let scaledContentSize = CGSize(width: contentSize.width * zoomScale, height: contentSize.height * zoomScale)
        let minimumX = min(0, viewportSize.width - scaledContentSize.width - panOverscrollPadding)
        let minimumY = min(0, viewportSize.height - scaledContentSize.height - panOverscrollPadding)
        let maximumX = panOverscrollPadding
        let maximumY = panOverscrollPadding

        return CGSize(width: min(max(offset.width, minimumX), maximumX), height: min(max(offset.height, minimumY), maximumY))
    }

    /// Converts a viewport coordinate into unscaled canvas coordinates.
    func contentPoint(for viewportPoint: CGPoint) -> CGPoint {
        let safeZoomScale = max(zoomScale, 0.01)
        return CGPoint(x: (viewportPoint.x - panOffset.width) / safeZoomScale, y: (viewportPoint.y - panOffset.height) / safeZoomScale)
    }

    /// Finds the topmost node containing a canvas coordinate.
    func nodeAndIndex(at contentPoint: CGPoint) -> (node: AgentNode, index: Int)? {
        for indexedNode in Array(nodes.enumerated()).reversed() {
            let node = indexedNode.element
            let origin = position(for: node, at: indexedNode.offset)
            let size = nodeSizes[node.id] ?? nodeSize
            let rect = CGRect(origin: origin, size: size).insetBy(dx: -6, dy: -6)

            if rect.contains(contentPoint) {
                return (node, indexedNode.offset)
            }
        }

        return nil
    }

    /// Returns a node's current canvas origin after persisted and active offsets.
    func position(for node: AgentNode, at index: Int) -> CGPoint {
        let base = defaultPosition(for: node, at: index)
        let offset = activeDrag?.nodeId == node.id ? activeDrag?.offset ?? .zero : nodeOffsets[node.id] ?? .zero
        return CGPoint(x: base.x + offset.width, y: base.y + offset.height)
    }

    /// Returns the automatic vertical timeline position for a node.
    func defaultPosition(for _: AgentNode, at index: Int) -> CGPoint {
        CGPoint(x: nodeBoundaryInset, y: nodeBoundaryInset + CGFloat(index) * verticalNodeSpacing)
    }

    /// Converts screen-space drag translation into canvas-space movement.
    func unscaledTranslation(_ translation: CGSize) -> CGSize {
        let safeZoomScale = max(zoomScale, 0.01)
        return CGSize(width: translation.width / safeZoomScale, height: translation.height / safeZoomScale)
    }

    /// Clamps a dragged node so it remains reachable inside the expanded canvas.
    func movedNodeOffset(nodeId: AgentNode.ID, startOffset: CGSize, translation: CGSize) -> CGSize {
        let proposedOffset = CGSize(width: startOffset.width + translation.width, height: startOffset.height + translation.height)
        guard let indexedNode = nodes.enumerated().first(where: { $0.element.id == nodeId }) else { return proposedOffset }

        let basePosition = defaultPosition(for: indexedNode.element, at: indexedNode.offset)
        let size = nodeSizes[nodeId] ?? nodeSize
        let maximumOriginX = contentSize.width + panOverscrollPadding - size.width - nodeBoundaryInset
        let maximumOriginY = contentSize.height + panOverscrollPadding - size.height - nodeBoundaryInset
        let proposedOrigin = CGPoint(x: basePosition.x + proposedOffset.width, y: basePosition.y + proposedOffset.height)
        let clampedOrigin = CGPoint(
            x: min(max(proposedOrigin.x, nodeBoundaryInset), maximumOriginX),
            y: min(max(proposedOrigin.y, nodeBoundaryInset), maximumOriginY)
        )

        return CGSize(width: clampedOrigin.x - basePosition.x, height: clampedOrigin.y - basePosition.y)
    }
}

/// Transient node drag preview state.
struct ActiveNodeDrag {
    let nodeId: AgentNode.ID
    let offset: CGSize
}

/// Current canvas gesture interaction.
enum ActiveCanvasInteraction {
    case node(nodeId: AgentNode.ID, startOffset: CGSize, hasMoved: Bool)
    case canvas(startOffset: CGSize)
    case resize(nodeId: AgentNode.ID, startSize: CGSize)
}
