import SwiftUI
import UI

/// Sidebar header showing current proxy or observer status.
struct SidebarStatusHeader: View {
    let proxyStatus: ProxyConnectionStatus
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: proxyStatus.symbolName)
                    .font(.callout)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(proxyStatus.color(palette))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(proxyStatus.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(proxyStatus.color(palette))
                    Text(proxyStatus.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 46)
            .liquidGlass(
                palette: palette,
                cornerRadius: palette.controlRadius,
                tint: proxyStatus.backgroundTint(palette),
                strokeOpacity: 0.84
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}
