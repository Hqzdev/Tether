import SwiftUI
import UI

/// Search field used to filter captured calls.
struct SidebarSearchField: View {
    @Binding var searchText: String
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                TextField("Filter calls...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.text)
            }
            .frame(height: 30)
            .padding(.horizontal, 10)
            .liquidGlass(
                palette: palette,
                cornerRadius: palette.controlRadius,
                tint: palette.glassTint,
                interactive: true,
                strokeOpacity: 0.72
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }
}
