import AppKit
import SwiftUI

struct GraphPane: View {
    private let nodeSize = CGSize(width: 320, height: 112)
    private let depthSpacing: CGFloat = 380
    private let zoomRange: ClosedRange<CGFloat> = 0.5...1.8

    let session: TraceSession?
    let nodes: [AgentNode]
    let selectedNode: AgentNode?
    let totalLatencyMs: Int
    let onSelect: (AgentNode) -> Void
    let palette: AgentTracePalette

    @State private var nodeOffsets: [AgentNode.ID: CGSize] = [:]
    @State private var zoomScale: CGFloat = 1
    @State private var magnificationStartZoom: CGFloat?

    private var statusText: String {
        guard !nodes.isEmpty else { return "IDLE" }
        if nodes.contains(where: { $0.status == .running }) { return "LIVE" }
        return nodes.contains(where: { $0.status == .error }) ? "FAILED" : "OK"
    }

    private var statusColor: Color {
        statusText == "FAILED" ? palette.pink : statusText == "LIVE" ? palette.amber : statusText == "OK" ? palette.green : palette.textTertiary
    }

    private var headerContext: String {
        let sessionTitle = session?.title ?? "No active session"
        let nodeTitle = selectedNode?.stepName ?? "Waiting for calls"
        return "\(sessionTitle) · \(nodeTitle)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(headerContext)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(selectedNode?.stepName ?? "Trace timeline")
                        .font(.headline)
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    MetricBox(label: "Total Time", value: formatLatency(totalLatencyMs), valueColor: palette.text, palette: palette)
                    MetricBox(label: "Steps", value: "\(nodes.count)", valueColor: palette.text, palette: palette)
                    MetricBox(label: "Status", value: statusText, valueColor: statusColor, palette: palette)
                    ZoomControls(
                        zoomScale: $zoomScale,
                        zoomRange: zoomRange,
                        onReset: { setZoom(1) },
                        palette: palette
                    )
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(palette.panelSecondary.opacity(0.48))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(palette.border)
                    .frame(height: 1)
            }

            GraphViewport(
                nodes: nodes,
                selectedNode: selectedNode,
                nodeSize: nodeSize,
                depthSpacing: depthSpacing,
                nodeOffsets: $nodeOffsets,
                zoomScale: zoomScale,
                magnificationStartZoom: $magnificationStartZoom,
                onSelect: onSelect,
                onZoom: { value, animated in setZoom(value, animated: animated) },
                palette: palette
            )
        }
        .background(palette.window.opacity(0.48))
        .onChange(of: nodes.map(\.id)) { _, ids in
            nodeOffsets = nodeOffsets.filter { ids.contains($0.key) }
        }
    }

    private func formatLatency(_ milliseconds: Int) -> String {
        if milliseconds >= 1000 {
            return String(format: "%.2fs", Double(milliseconds) / 1000.0)
        }

        return "\(milliseconds)ms"
    }

    private func setZoom(_ value: CGFloat, animated: Bool = true) {
        let clampedValue = min(max(value, zoomRange.lowerBound), zoomRange.upperBound)

        if animated {
            withAnimation(.smooth(duration: 0.16)) {
                zoomScale = clampedValue
            }
        } else {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                zoomScale = clampedValue
            }
        }
    }
}

private struct MetricBox: View {
    let label: String
    let value: String
    let valueColor: Color
    let palette: AgentTracePalette

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.title3.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 82, height: 52, alignment: .trailing)
        .padding(.horizontal, 12)
        .liquidGlass(
            palette: palette,
            cornerRadius: 10,
            tint: palette.glassTint,
            strokeOpacity: 0.84
        )
    }
}

private struct ZoomControls: View {
    @Binding var zoomScale: CGFloat

    let zoomRange: ClosedRange<CGFloat>
    let onReset: () -> Void
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 8) {
            Button {
                zoomScale = clamped(zoomScale - 0.1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")

            Slider(value: $zoomScale, in: zoomRange, step: 0.05)
                .frame(width: 92)
                .help("Canvas Zoom")

            Button {
                zoomScale = clamped(zoomScale + 0.1)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In")

            Button {
                onReset()
            } label: {
                Text("\(Int((zoomScale * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 42)
            }
            .help("Reset Zoom")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .frame(height: 52)
        .liquidGlass(
            palette: palette,
            cornerRadius: 10,
            tint: palette.glassTint,
            strokeOpacity: 0.84
        )
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, zoomRange.lowerBound), zoomRange.upperBound)
    }
}

private struct GraphViewport: View {
    private let freeformCanvasPadding: CGFloat = 360
    private let minimumCanvasSize = CGSize(width: 2_400, height: 1_600)

    let nodes: [AgentNode]
    let selectedNode: AgentNode?
    let nodeSize: CGSize
    let depthSpacing: CGFloat
    @Binding var nodeOffsets: [AgentNode.ID: CGSize]
    let zoomScale: CGFloat
    @Binding var magnificationStartZoom: CGFloat?
    let onSelect: (AgentNode) -> Void
    let onZoom: (CGFloat, Bool) -> Void
    let palette: AgentTracePalette

    @State private var panOffset: CGSize = .zero
    @State private var panStartOffset: CGSize?

    private var contentSize: CGSize {
        let maxDepth = nodes.map(\.depth).max() ?? 0
        return CGSize(
            width: max(
                minimumCanvasSize.width,
                freeformCanvasPadding + CGFloat(maxDepth) * depthSpacing + nodeSize.width + freeformCanvasPadding
            ),
            height: max(
                minimumCanvasSize.height,
                freeformCanvasPadding + CGFloat(nodes.count) * 154 + nodeSize.height
            )
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(palette.window.opacity(0.44))
                    .contentShape(Rectangle())
                    .gesture(panGesture(viewportSize: geometry.size))

                GraphCanvas(
                    nodes: nodes,
                    selectedNode: selectedNode,
                    nodeSize: nodeSize,
                    depthSpacing: depthSpacing,
                    contentSize: contentSize,
                    nodeOffsets: $nodeOffsets,
                    zoomScale: zoomScale,
                    onSelect: onSelect,
                    palette: palette
                )
                .offset(panOffset)
            }
            .clipped()
            .coordinateSpace(name: "graphCanvas")
            .background(
                MacCanvasEventBridge(
                    onScroll: { delta in panBy(delta, viewportSize: geometry.size) },
                    onMagnify: { delta in
                        onZoom(zoomScale * max(0.2, 1 + delta), false)
                    }
                )
            )
            .simultaneousGesture(magnifyGesture)
            .onChange(of: zoomScale) { _, _ in
                panOffset = clampedPan(panOffset, viewportSize: geometry.size)
            }
        }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if magnificationStartZoom == nil {
                    magnificationStartZoom = zoomScale
                }

                onZoom((magnificationStartZoom ?? zoomScale) * value.magnification, false)
            }
            .onEnded { value in
                onZoom((magnificationStartZoom ?? zoomScale) * value.magnification, true)
                magnificationStartZoom = nil
            }
    }

    private func panGesture(viewportSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { value in
                if panStartOffset == nil {
                    panStartOffset = panOffset
                }

                let startOffset = panStartOffset ?? panOffset
                panOffset = clampedPan(
                    CGSize(
                        width: startOffset.width + value.translation.width,
                        height: startOffset.height + value.translation.height
                    ),
                    viewportSize: viewportSize
                )
            }
            .onEnded { value in
                let startOffset = panStartOffset ?? panOffset
                panOffset = clampedPan(
                    CGSize(
                        width: startOffset.width + value.translation.width,
                        height: startOffset.height + value.translation.height
                    ),
                    viewportSize: viewportSize
                )
                panStartOffset = nil
            }
    }

    private func panBy(_ delta: CGSize, viewportSize: CGSize) {
        panOffset = clampedPan(
            CGSize(
                width: panOffset.width + delta.width,
                height: panOffset.height + delta.height
            ),
            viewportSize: viewportSize
        )
    }

    private func clampedPan(_ offset: CGSize, viewportSize: CGSize) -> CGSize {
        let scaledContentSize = CGSize(width: contentSize.width * zoomScale, height: contentSize.height * zoomScale)
        let minimumX = min(0, viewportSize.width - scaledContentSize.width)
        let minimumY = min(0, viewportSize.height - scaledContentSize.height)

        return CGSize(
            width: min(max(offset.width, minimumX), 0),
            height: min(max(offset.height, minimumY), 0)
        )
    }
}

private struct MacCanvasEventBridge: NSViewRepresentable {
    let onScroll: (CGSize) -> Void
    let onMagnify: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.view = view
        context.coordinator.onScroll = onScroll
        context.coordinator.onMagnify = onMagnify
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.view = nsView
        context.coordinator.onScroll = onScroll
        context.coordinator.onMagnify = onMagnify
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        weak var view: NSView?
        var onScroll: ((CGSize) -> Void)?
        var onMagnify: ((CGFloat) -> Void)?
        private var monitor: Any?

        func installMonitor() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self] event in
                guard let self, contains(event: event) else { return event }

                switch event.type {
                case .scrollWheel:
                    onScroll?(CGSize(width: -event.scrollingDeltaX, height: -event.scrollingDeltaY))
                    return nil

                case .magnify:
                    onMagnify?(event.magnification)
                    return nil

                default:
                    return event
                }
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }

            monitor = nil
        }

        private func contains(event: NSEvent) -> Bool {
            guard let view, event.window === view.window else { return false }
            let location = view.convert(event.locationInWindow, from: nil)
            return view.bounds.contains(location)
        }
    }
}

private struct GraphCanvas: View {
    let nodes: [AgentNode]
    let selectedNode: AgentNode?
    let nodeSize: CGSize
    let depthSpacing: CGFloat
    let contentSize: CGSize
    @Binding var nodeOffsets: [AgentNode.ID: CGSize]
    let zoomScale: CGFloat
    let onSelect: (AgentNode) -> Void
    let palette: AgentTracePalette

    @State private var activeDrag: ActiveNodeDrag?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if nodes.isEmpty {
                GraphEmptyState()
                    .frame(width: contentSize.width, height: contentSize.height)
            } else {
                GraphConnections(
                    nodes: nodes,
                    positions: positions,
                    nodeSize: nodeSize,
                    palette: palette
                )

                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    MovableNodeCard(
                        node: node,
                        selected: node.id == selectedNode?.id,
                        basePosition: defaultPosition(for: node, at: index),
                        storedOffset: nodeOffsets[node.id] ?? .zero,
                        currentOffset: currentOffset(for: node),
                        nodeSize: nodeSize,
                        contentSize: contentSize,
                        zoomScale: zoomScale,
                        onSelect: { onSelect(node) },
                        onDragChanged: { activeDrag = ActiveNodeDrag(nodeId: node.id, offset: $0) },
                        onDragEnded: {
                            nodeOffsets[node.id] = $0
                            activeDrag = nil
                        },
                        palette: palette
                    )
                }
            }
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .scaleEffect(zoomScale, anchor: .topLeading)
        .frame(width: contentSize.width * zoomScale, height: contentSize.height * zoomScale, alignment: .topLeading)
    }

    private var positions: [AgentNode.ID: CGPoint] {
        Dictionary(uniqueKeysWithValues: nodes.enumerated().map { index, node in
            let base = defaultPosition(for: node, at: index)
            let offset = currentOffset(for: node)
            return (
                node.id,
                CGPoint(x: base.x + offset.width, y: base.y + offset.height)
            )
        })
    }

    private func currentOffset(for node: AgentNode) -> CGSize {
        if activeDrag?.nodeId == node.id {
            return activeDrag?.offset ?? .zero
        }

        return nodeOffsets[node.id] ?? .zero
    }

    private func defaultPosition(for node: AgentNode, at index: Int) -> CGPoint {
        CGPoint(
            x: 36 + CGFloat(node.depth) * depthSpacing,
            y: 30 + CGFloat(index) * 138
        )
    }
}

private struct ActiveNodeDrag {
    let nodeId: AgentNode.ID
    let offset: CGSize
}

private struct GraphConnections: View {
    let nodes: [AgentNode]
    let positions: [AgentNode.ID: CGPoint]
    let nodeSize: CGSize
    let palette: AgentTracePalette

    var body: some View {
        Canvas { context, _ in
            guard nodes.count > 1 else { return }

            for index in 1..<nodes.count {
                let previous = nodes[index - 1]
                let current = nodes[index]

                guard let from = positions[previous.id], let to = positions[current.id] else {
                    continue
                }

                let start = CGPoint(x: from.x + nodeSize.width, y: from.y + nodeSize.height / 2)
                let end = CGPoint(x: to.x, y: to.y + nodeSize.height / 2)
                let controlDistance = max(44, abs(end.x - start.x) * 0.45)

                var path = Path()
                path.move(to: start)
                path.addCurve(
                    to: end,
                    control1: CGPoint(x: start.x + controlDistance, y: start.y),
                    control2: CGPoint(x: end.x - controlDistance, y: end.y)
                )

                context.stroke(path, with: .color(palette.borderStrong), lineWidth: 1.5)
                context.fill(
                    Path(ellipseIn: CGRect(x: end.x - 4.5, y: end.y - 4.5, width: 9, height: 9)),
                    with: .color(palette.window)
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: end.x - 4.5, y: end.y - 4.5, width: 9, height: 9)),
                    with: .color(palette.borderStrong),
                    lineWidth: 1.5
                )
            }
        }
        .allowsHitTesting(false)
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

private struct MovableNodeCard: View {
    @State private var dragStartOffset: CGSize?

    let node: AgentNode
    let selected: Bool
    let basePosition: CGPoint
    let storedOffset: CGSize
    let currentOffset: CGSize
    let nodeSize: CGSize
    let contentSize: CGSize
    let zoomScale: CGFloat
    let onSelect: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void
    let palette: AgentTracePalette

    private var isDragging: Bool {
        dragStartOffset != nil
    }

    var body: some View {
        NodeCard(node: node, selected: selected, action: onSelect, palette: palette)
            .frame(width: nodeSize.width, height: nodeSize.height)
            .position(
                x: basePosition.x + currentOffset.width + nodeSize.width / 2,
                y: basePosition.y + currentOffset.height + nodeSize.height / 2
            )
            .scaleEffect(isDragging ? 1.015 : 1)
            .shadow(
                color: isDragging ? palette.accent.opacity(palette.light ? 0.18 : 0.30) : .clear,
                radius: isDragging ? 18 : 0,
                x: 0,
                y: isDragging ? 10 : 0
            )
            .zIndex(isDragging ? 30 : selected ? 10 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .highPriorityGesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named("graphCanvas"))
                    .onChanged { value in
                        if dragStartOffset == nil {
                            dragStartOffset = storedOffset
                            onSelect()
                        }

                        let startOffset = dragStartOffset ?? storedOffset
                        let translation = unscaledTranslation(value.translation)
                        let nextOffset = clampedOffset(
                            CGSize(
                                width: startOffset.width + translation.width,
                                height: startOffset.height + translation.height
                            )
                        )

                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) {
                            onDragChanged(nextOffset)
                        }
                    }
                    .onEnded { value in
                        let startOffset = dragStartOffset ?? storedOffset
                        let translation = unscaledTranslation(value.translation)
                        let finalOffset = clampedOffset(
                            CGSize(
                                width: startOffset.width + translation.width,
                                height: startOffset.height + translation.height
                            )
                        )

                        onDragEnded(finalOffset)
                        dragStartOffset = nil
                    }
            )
            .animation(.smooth(duration: 0.12), value: isDragging)
            .animation(.smooth(duration: 0.12), value: selected)
    }

    private func unscaledTranslation(_ translation: CGSize) -> CGSize {
        let safeZoomScale = max(zoomScale, 0.01)

        return CGSize(
            width: translation.width / safeZoomScale,
            height: translation.height / safeZoomScale
        )
    }

    private func clampedOffset(_ offset: CGSize) -> CGSize {
        let edgePadding: CGFloat = 24
        let minimumX = edgePadding - basePosition.x
        let minimumY = edgePadding - basePosition.y
        let maximumX = contentSize.width - nodeSize.width - edgePadding - basePosition.x
        let maximumY = contentSize.height - nodeSize.height - edgePadding - basePosition.y

        return CGSize(
            width: clamp(offset.width, minimum: minimumX, maximum: maximumX),
            height: clamp(offset.height, minimum: minimumY, maximum: maximumY)
        )
    }

    private func clamp(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(value, minimum), maximum)
    }
}

private struct NodeCard: View {
    let node: AgentNode
    let selected: Bool
    let action: () -> Void
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                StatusDot(status: node.status, palette: palette)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.stepName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)

                    Text("\(node.model) - \(node.requestId)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(palette.textQuaternary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(node.status.label)
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(palette.color(for: node.status))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(palette.background(for: node.status))
                    .clipShape(Capsule())
            }

            ProgressBar(value: node.barPercent, status: node.status, palette: palette)
                .padding(.top, 9)

            HStack(spacing: 10) {
                NodeFootnote(label: "lat", text: node.latency, palette: palette)
                NodeFootnote(label: "cost", text: node.cost, palette: palette)

                Spacer(minLength: 0)

                Text("\(node.tokensIn) down \(node.tokensOut) up tok")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(palette.border)
                    .frame(height: 1)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(width: 320, height: 112)
        .background(
            LinearGradient(
                colors: [palette.nodeTop.opacity(0.62), palette.nodeBottom.opacity(0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(palette.color(for: node.status))
                .frame(width: 3)
                .padding(.vertical, 12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            palette.glassHighlight.opacity(0.82),
                            selected ? palette.accent.opacity(0.9) : palette.border.opacity(0.74),
                            palette.glassStrokeSoft
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: selected ? .black.opacity(palette.light ? 0.10 : 0.24) : .clear, radius: 10, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? palette.accentBackground : .clear, lineWidth: 3)
                .padding(-3)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: action)
    }
}

private struct ProgressBar: View {
    let value: Double
    let status: NodeStatus
    let palette: AgentTracePalette

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.panelSecondary)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [palette.dimColor(for: status), palette.color(for: status)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * min(max(value, 0), 100) / 100)
            }
        }
        .frame(height: 3)
    }
}

private struct NodeFootnote: View {
    let label: String
    let text: String
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(palette.textQuaternary)
            Text(text)
                .fontWeight(.semibold)
                .foregroundStyle(palette.textSecondary)
        }
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(palette.textTertiary)
        .lineLimit(1)
    }
}
