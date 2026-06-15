import SwiftUI
import UI

/// Small section label with a right-aligned count.
struct SidebarSectionHeader: View {
    let title: String
    let detail: String
    let palette: AgentTracePalette

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)

            Spacer()

            Text(detail)
                .font(.caption2.monospacedDigit())
        }
        .textCase(nil)
        .foregroundStyle(.secondary)
        .fontDesign(.monospaced)
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}
