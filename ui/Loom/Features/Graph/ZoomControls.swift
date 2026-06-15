import SwiftUI
import UI

/// Floating graph zoom controls shown in the lower-right corner.
struct ZoomControls: View {
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
        .padding(.horizontal, 12)
        .frame(height: 40)
        .liquidGlass(
            palette: palette,
            cornerRadius: palette.controlRadius,
            tint: palette.panelSecondary.opacity(0.85),
            strokeOpacity: 0.84
        )
        .shadow(color: Color(hex: 0x0f172a).opacity(0.10), radius: 14, x: 0, y: 7)
    }

    /// Clamps zoom buttons to the same range as the slider.
    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, zoomRange.lowerBound), zoomRange.upperBound)
    }
}
