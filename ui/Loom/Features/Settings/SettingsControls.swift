import SwiftUI
import UI

/// Vertical one-pixel divider used in settings split views.
struct VerticalDividerLine: View {
    let palette: AgentTracePalette

    var body: some View {
        Rectangle()
            .fill(palette.border)
            .frame(width: 1)
    }
}

/// Reusable grouped settings section.
struct SettingsSection<Content: View>: View {
    private let title: String
    private let palette: AgentTracePalette
    private let content: Content

    /// Creates a titled settings section around custom row content.
    init(_ title: String, palette: AgentTracePalette, @ViewBuilder content: () -> Content) {
        self.title = title
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .fontWeight(.semibold)
                .foregroundStyle(palette.text)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
    }
}

/// Reusable row layout for a settings control.
struct SettingsRow<Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let palette: AgentTracePalette
    private let content: Content

    /// Creates a settings row with optional subtitle and trailing control.
    init(_ title: String, subtitle: String? = nil, palette: AgentTracePalette, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content
        }
        .frame(minHeight: 70)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.borderSoft)
                .frame(height: 1)
                .padding(.leading, 0)
        }
    }
}
