import SwiftUI
import UI

private struct WorkspaceSurfaceModifier: ViewModifier {
    let layout: AdaptiveWorkspaceLayout
    let palette: AgentTracePalette

    /// Applies the shared paper surface treatment around the workspace.
    func body(content: Content) -> some View {
        let cornerRadius = layout.mode == .compact ? CGFloat(20) : palette.paperRadius

        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [palette.paperTop, palette.paperBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(palette.border.opacity(0.92), lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x0f172a).opacity(0.07), radius: 28, x: 0, y: 18)
            .padding(.horizontal, layout.mode == .compact ? 8 : 14)
            .padding(.bottom, layout.mode == .compact ? 8 : 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    /// Applies the desktop workspace surface styling.
    func workspaceSurface(layout: AdaptiveWorkspaceLayout, palette: AgentTracePalette) -> some View {
        modifier(WorkspaceSurfaceModifier(layout: layout, palette: palette))
    }
}
