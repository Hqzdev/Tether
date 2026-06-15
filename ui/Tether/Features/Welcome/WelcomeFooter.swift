import SwiftUI
import UI

/// Footer copy and launch action for the welcome window.
struct WelcomeFooter: View {
    let palette: AgentTracePalette
    let launchAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Tested with Claude Code and Codex · 100% local · Your keys never leave this Mac")
                .font(.caption)
                .foregroundStyle(palette.textQuaternary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Button(action: launchAction) {
                Label("Launch Proxy Server", systemImage: "play.fill")
                    .frame(width: 260, height: 42)
            }
            .buttonStyle(WelcomePrimaryButtonStyle(palette: palette))
            .padding(.top, 16)

            Text("You can change the port anytime in Settings")
                .font(.caption2)
                .foregroundStyle(palette.textTertiary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WelcomePrimaryButtonStyle: ButtonStyle {
    let palette: AgentTracePalette

    /// Renders the primary welcome action.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [palette.accent, palette.accentTwo, palette.accentThree],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .shadow(color: palette.accent.opacity(configuration.isPressed ? 0.08 : 0.18), radius: 16, y: 8)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}
