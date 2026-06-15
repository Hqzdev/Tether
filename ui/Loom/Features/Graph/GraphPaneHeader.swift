import SwiftUI
import UI

/// Header row for graph context and aggregate trace metrics.
struct GraphPaneHeader: View {
    let context: String
    let title: String
    let totalLatency: String
    let stepCount: Int
    let agentCount: String
    let statusText: String
    let statusColor: Color
    let palette: AgentTracePalette

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                MetricBox(label: "Total Time", value: totalLatency, valueColor: palette.text, palette: palette)
                MetricBox(label: "Steps", value: "\(stepCount)", valueColor: palette.text, palette: palette)
                MetricBox(label: "Agents", value: agentCount, valueColor: palette.accent, palette: palette)
                MetricBox(label: "Status", value: statusText, valueColor: statusColor, palette: palette)
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(palette.panelSecondary.opacity(0.48))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
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
            cornerRadius: palette.controlRadius,
            tint: palette.glassTint,
            strokeOpacity: 0.84
        )
    }
}
