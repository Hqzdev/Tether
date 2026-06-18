import Core
import SwiftUI
import UI

/// Main text content for a sidebar call row.
struct CallRowBody: View {
    let node: CallRowModel
    let palette: AgentTracePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(node.stepName)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(node.status == .error ? palette.pinkText : node.stale ? palette.amber : palette.text)
                .lineLimit(1)

            HStack(spacing: 6) {
                AgentBadge(name: node.agentName, palette: palette)
                ModelBadge(model: "\(node.provider) / \(node.model)", palette: palette)
                if node.stale {
                    Text("STALE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.amber)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(palette.amber.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                }
                Text(node.timestamp)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(palette.textQuaternary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ModelBadge: View {
    let model: String
    let palette: AgentTracePalette

    var body: some View {
        Text(model)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(palette.violet)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(palette.violet.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(palette.violetBorder, lineWidth: 1)
            )
    }
}

/// Right-side cost and latency metrics for a sidebar call row.
struct CallRowMetrics: View {
    let node: CallRowModel
    let palette: AgentTracePalette

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            if node.hasBillableCost {
                Text(node.cost)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
            }

            Text(node.status == .cached ? "0ms" : node.latency.replacingOccurrences(of: " (timeout)", with: ""))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(node.status == .cached ? palette.cyan : palette.textQuaternary)
        }
        .frame(minWidth: 44, alignment: .trailing)
    }
}
