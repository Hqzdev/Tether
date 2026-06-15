import SwiftUI
import UI

/// Left settings sidebar with search and pane groups.
struct SettingsSidebar: View {
    @Binding var selectedPane: SettingsPane
    @Binding var searchText: String
    let palette: AgentTracePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSearchField(searchText: $searchText, palette: palette)
                .padding(.top, 14)
                .padding(.horizontal, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsPaneGroup(title: "Settings", panes: SettingsPane.settings, selectedPane: $selectedPane, palette: palette)
                    SettingsPaneGroup(title: "Desktop app", panes: SettingsPane.desktop, selectedPane: $selectedPane, palette: palette)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct SettingsSearchField: View {
    @Binding var searchText: String
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.textTertiary)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }
}

private struct SettingsPaneGroup: View {
    let title: String
    let panes: [SettingsPane]
    @Binding var selectedPane: SettingsPane
    let palette: AgentTracePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textTertiary)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            ForEach(panes) { pane in
                SettingsPaneButton(pane: pane, selected: selectedPane == pane, palette: palette) {
                    selectedPane = pane
                }
            }
        }
    }
}
