import SwiftUI

/// Sides used as connection anchors on node cards.
enum NodeAnchorSide: CaseIterable {
    case top
    case bottom
    case left
    case right

    /// Unit direction pointing away from this side.
    var normal: CGSize {
        switch self {
        case .top:
            return CGSize(width: 0, height: -1)
        case .bottom:
            return CGSize(width: 0, height: 1)
        case .left:
            return CGSize(width: -1, height: 0)
        case .right:
            return CGSize(width: 1, height: 0)
        }
    }

    /// Whether this side is top or bottom.
    var isVertical: Bool {
        self == .top || self == .bottom
    }

    /// Returns the point on a node rectangle represented by this side.
    func point(for origin: CGPoint, nodeSize: CGSize) -> CGPoint {
        switch self {
        case .top:
            return CGPoint(x: origin.x + nodeSize.width / 2, y: origin.y)
        case .bottom:
            return CGPoint(x: origin.x + nodeSize.width / 2, y: origin.y + nodeSize.height)
        case .left:
            return CGPoint(x: origin.x, y: origin.y + nodeSize.height / 2)
        case .right:
            return CGPoint(x: origin.x + nodeSize.width, y: origin.y + nodeSize.height / 2)
        }
    }

    /// Returns the marker position within a node card.
    func markerPosition(in size: CGSize) -> CGPoint {
        switch self {
        case .top:
            return CGPoint(x: size.width / 2, y: 0)
        case .bottom:
            return CGPoint(x: size.width / 2, y: size.height)
        case .left:
            return CGPoint(x: 0, y: size.height / 2)
        case .right:
            return CGPoint(x: size.width, y: size.height / 2)
        }
    }
}

/// Concrete source and target anchors for one graph connection.
struct NodeAnchorPair {
    let start: CGPoint
    let end: CGPoint
    let startSide: NodeAnchorSide
    let endSide: NodeAnchorSide
    let distance: CGFloat

    /// Creates an anchor pair directly from concrete points.
    init(start: CGPoint, end: CGPoint, startSide: NodeAnchorSide, endSide: NodeAnchorSide, distance: CGFloat) {
        self.start = start
        self.end = end
        self.startSide = startSide
        self.endSide = endSide
        self.distance = distance
    }

    /// Creates an anchor pair by resolving sides against source and target rectangles.
    init(startSide: NodeAnchorSide, endSide: NodeAnchorSide, sourceOrigin: CGPoint, sourceSize: CGSize, targetOrigin: CGPoint, targetSize: CGSize) {
        let start = startSide.point(for: sourceOrigin, nodeSize: sourceSize)
        let end = endSide.point(for: targetOrigin, nodeSize: targetSize)
        self.init(start: start, end: end, startSide: startSide, endSide: endSide, distance: CGSize(width: end.x - start.x, height: end.y - start.y).length)
    }

    /// Scores readability for this anchor pair; lower is better.
    func score(preferredSides: (start: NodeAnchorSide, end: NodeAnchorSide)) -> CGFloat {
        let delta = CGSize(width: end.x - start.x, height: end.y - start.y)
        let direction = delta.normalized
        let startsAgainstFlow = max(0, -direction.dot(startSide.normal)) * 120
        let endsAgainstFlow = max(0, direction.dot(endSide.normal)) * 120
        let readabilityPenalty: CGFloat = startSide == preferredSides.start && endSide == preferredSides.end ? 0 : 24
        return distance + startsAgainstFlow + endsAgainstFlow + readabilityPenalty
    }
}

extension CGSize {
    /// Euclidean length of the vector.
    var length: CGFloat {
        (width * width + height * height).squareRoot()
    }

    /// Unit vector with a small lower bound to avoid division by zero.
    var normalized: CGSize {
        let safeLength = max(length, 0.001)
        return CGSize(width: width / safeLength, height: height / safeLength)
    }

    /// Dot product with another vector.
    func dot(_ other: CGSize) -> CGFloat {
        width * other.width + height * other.height
    }
}

extension CGPoint {
    /// Center point for a rectangle at this origin.
    func center(in size: CGSize) -> CGPoint {
        CGPoint(x: x + size.width / 2, y: y + size.height / 2)
    }

    /// Offsets this point along a vector by a distance.
    func offset(by direction: CGSize, distance: CGFloat) -> CGPoint {
        CGPoint(x: x + direction.width * distance, y: y + direction.height * distance)
    }
}
