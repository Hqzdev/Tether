import Core
import SwiftUI

/// Where a graph node came from: read-only session history, or a live capture.
enum NodeSource: Equatable {
    case history
    case live

    /// Classifies a node by its position in the history-first ordered node array.
    static func of(index: Int, historyCount: Int) -> NodeSource {
        index < historyCount ? .history : .live
    }
}

/// Shared geometry for the two-cluster trace layout. The history cluster sits in
/// the left column; new live calls form a second column offset to its right so
/// the two never overlap or connect.
enum GraphClusterLayout {
    /// Horizontal gap between the right edge of the history column and the live column.
    static let liveClusterGap: CGFloat = 400

    /// Automatic canvas origin for the node at `index` in a history-first array.
    ///
    /// With no history (`historyCount == 0`) this collapses to the original
    /// single-column timeline, so the live-only view is unaffected.
    static func defaultPosition(
        index: Int,
        historyCount: Int,
        nodeSize: CGSize,
        inset: CGFloat,
        spacing: CGFloat
    ) -> CGPoint {
        let isHistory = index < historyCount
        let intraClusterIndex = isHistory ? index : index - historyCount
        let liveColumnX = historyCount > 0
            ? inset + nodeSize.width + liveClusterGap
            : inset
        let x = isHistory ? inset : liveColumnX
        let y = inset + CGFloat(intraClusterIndex) * spacing
        return CGPoint(x: x, y: y)
    }
}

private struct NodeSourceKey: EnvironmentKey {
    static let defaultValue: NodeSource = .live
}

extension EnvironmentValues {
    /// The source cluster of the node a card is rendering, for muted history styling.
    var nodeSource: NodeSource {
        get { self[NodeSourceKey.self] }
        set { self[NodeSourceKey.self] = newValue }
    }
}
