import SwiftUI
import UI

/// Help sheet explaining how local agents connect to Tether.
struct ConnectionHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let palette = AgentTracePalette(light: true)

    var body: some View {
        ZStack {
            StageBackground(palette: palette)

            VStack(alignment: .leading, spacing: 24) {
                ConnectionHelpHeader(palette: palette)
                VStack(alignment: .leading, spacing: 12) {
                    HelpRow(systemImage: "1.circle", title: "Open Terminal", detail: "Run codex from any terminal session.", palette: palette)
                    HelpRow(systemImage: "2.circle", title: "Keep Tether Open", detail: "The workspace updates as new agent calls arrive.", palette: palette)
                    HelpRow(systemImage: "3.circle", title: "Use Proxy Settings", detail: "Configure port, upstream URLs, and cache from Settings.", palette: palette)
                }
                ConnectionHelpFooter(palette: palette, dismiss: dismiss)
            }
            .padding(24)
            .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: palette.paperRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.paperRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .padding(12)
        }
        .frame(width: 480)
        .preferredColorScheme(.light)
    }
}
