import Core
import SwiftUI
import UI

/// Small anchor markers that hint where graph edges connect.
struct NodeAnchorMarkers: View {
    let palette: AgentTracePalette

    var body: some View {
        GeometryReader { geometry in
            ForEach(NodeAnchorSide.allCases, id: \.self) { side in
                Circle()
                    .fill(palette.window.opacity(0.96))
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle()
                            .stroke(palette.borderStrong, lineWidth: 1.4)
                    }
                    .position(side.markerPosition(in: geometry.size))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Thin status-colored progress bar inside a node card.
struct ProgressBar: View {
    let value: Double
    let status: NodeStatus
    let palette: AgentTracePalette

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.panelSecondary)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
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

/// Compact metric label used in graph node footers.
struct NodeFootnote: View {
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
