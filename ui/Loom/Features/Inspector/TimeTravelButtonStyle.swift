import SwiftUI
import UI

/// Gradient button style used for time-travel replay controls.
struct TimeTravelButtonStyle: ButtonStyle {
    let active: Bool
    let palette: AgentTracePalette

    /// Renders the replay button with active and inactive color treatments.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(active ? Color(hex: 0x3a2a00) : Color.white)
            .background(
                LinearGradient(
                    colors: active
                        ? [Color(hex: 0xffd27a), Color(hex: 0xf5b94f)]
                        : [palette.accent, palette.accentTwo, palette.accentThree],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(active ? Color(hex: 0xe0a23f) : palette.accent.opacity(0.22), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}
