import SwiftUI
import UI

/// Visual hierarchy for replay controls.
enum TimeTravelButtonRole {
    case primary
    case secondary
}

/// Native macOS-style button treatment used for time-travel replay controls.
struct TimeTravelButtonStyle: ButtonStyle {
    let role: TimeTravelButtonRole
    let palette: AgentTracePalette

    @Environment(\.isEnabled) private var isEnabled

    /// Renders the replay button with active and inactive color treatments.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .background(backgroundColor(configuration: configuration))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.52)
            .scaleEffect(configuration.isPressed ? 0.995 : 1)
    }

    private var foregroundColor: Color {
        switch role {
        case .primary:
            return Color.white
        case .secondary:
            return palette.text
        }
    }

    private var borderColor: Color {
        switch role {
        case .primary:
            return Color(hex: 0x18181b)
        case .secondary:
            return palette.borderStrong
        }
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        switch role {
        case .primary:
            return configuration.isPressed ? Color(hex: 0x3f3f46) : Color(hex: 0x18181b)
        case .secondary:
            return configuration.isPressed ? palette.panelSecondary : palette.window
        }
    }
}
