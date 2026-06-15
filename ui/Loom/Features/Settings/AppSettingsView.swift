import SwiftUI
import UI

/// Desktop settings window used by the workspace overlay.
struct AppSettingsView: View {
    var onClose: (() -> Void)?

    let palette = AgentTracePalette(light: true)
    @State var selectedPane: SettingsPane = .general
    @State var searchText = ""

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(
                selectedPane: $selectedPane,
                searchText: $searchText,
                palette: palette
            )
            .frame(width: 214)
            .background(palette.panel.opacity(0.96))

            VerticalDividerLine(palette: palette)
            settingsDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 920, height: 560)
        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x0f172a).opacity(0.18), radius: 34, x: 0, y: 22)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var settingsDetail: some View {
        ZStack(alignment: .topTrailing) {
            switch selectedPane {
            case .general:
                ProxySettingsView(
                    title: "General desktop settings",
                    subtitle: "Configure how Tether captures local agent traffic.",
                    palette: palette
                )
            case .proxy:
                ProxySettingsView(
                    title: "Proxy settings",
                    subtitle: "Edit upstream URLs, listen port, and local cache behavior.",
                    palette: palette
                )
            default:
                PlaceholderSettingsView(pane: selectedPane, palette: palette)
            }

            if let onClose {
                SettingsCloseButton(palette: palette, onClose: onClose)
            }
        }
    }
}
