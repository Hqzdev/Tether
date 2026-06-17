import SwiftUI
import UI

/// Bottom sidebar action area.
struct SidebarFooter: View {
    let onShowSettings: () -> Void
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 8) {
            SidebarButton(title: "Settings", palette: palette) {
                onShowSettings()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(palette.panelSecondary.opacity(0.38))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }
}

private struct SidebarButton: View {
    let title: String
    var selected = false
    let palette: AgentTracePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "gearshape")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .foregroundStyle(selected ? palette.text : palette.textSecondary)
                .liquidGlass(
                    palette: palette,
                    cornerRadius: palette.controlRadius,
                    tint: selected ? palette.accent.opacity(0.16) : palette.glassTint,
                    interactive: true,
                    strokeOpacity: 0.74
                )
        }
        .buttonStyle(.plain)
    }
}
