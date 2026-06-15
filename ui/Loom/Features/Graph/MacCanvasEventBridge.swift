import AppKit
import SwiftUI

/// Bridges macOS scroll-wheel and magnify events into SwiftUI graph gestures.
struct MacCanvasEventBridge: NSViewRepresentable {
    let onScroll: (CGSize) -> Void
    let onMagnify: (CGFloat) -> Void

    /// Creates the coordinator that owns the local NSEvent monitor.
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Creates the hosting NSView used to scope local input events.
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.view = view
        context.coordinator.onScroll = onScroll
        context.coordinator.onMagnify = onMagnify
        context.coordinator.installMonitor()
        return view
    }

    /// Updates event callbacks when SwiftUI refreshes the bridge.
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.view = nsView
        context.coordinator.onScroll = onScroll
        context.coordinator.onMagnify = onMagnify
    }

    /// Removes the local monitor when the NSView leaves the hierarchy.
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    /// Owns the NSEvent monitor for this graph viewport.
    final class Coordinator {
        weak var view: NSView?
        var onScroll: ((CGSize) -> Void)?
        var onMagnify: ((CGFloat) -> Void)?
        private var monitor: Any?

        /// Installs a local monitor for scroll and magnify events inside the bridge view.
        func installMonitor() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self] event in
                guard let self, contains(event: event) else { return event }
                return handle(event)
            }
        }

        /// Removes the local monitor if one is installed.
        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }

            monitor = nil
        }

        /// Converts a supported NSEvent into graph actions or returns it unchanged.
        private func handle(_ event: NSEvent) -> NSEvent? {
            switch event.type {
            case .scrollWheel:
                let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 16
                let delta = CGSize(width: -(event.scrollingDeltaX * multiplier), height: -(event.scrollingDeltaY * multiplier))
                guard delta != .zero else { return event }
                onScroll?(delta)
                return nil
            case .magnify:
                guard event.magnification != 0 else { return event }
                onMagnify?(event.magnification)
                return nil
            default:
                return event
            }
        }

        /// Returns whether the event occurred inside the bridge view bounds.
        private func contains(event: NSEvent) -> Bool {
            guard let view, event.window === view.window else { return false }
            let location = view.convert(event.locationInWindow, from: nil)
            return view.bounds.contains(location)
        }
    }
}
