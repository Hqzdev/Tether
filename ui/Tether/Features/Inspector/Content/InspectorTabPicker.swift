import Core
import SwiftUI
import UI

/// Liquid-glass segmented control for inspector sections.
struct InspectorTabPicker: View {
    @Binding var tab: InspectorTab
    let palette: AgentTracePalette

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(InspectorTab.allCases) { item in
                let selected = tab == item
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        tab = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? palette.text : palette.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .contentShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                        .background {
                            if selected {
                                Color.clear
                                    .liquidGlass(
                                        palette: palette,
                                        in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous),
                                        tint: palette.glassTintStrong,
                                        interactive: true,
                                        strokeOpacity: 0.82
                                    )
                                    .matchedGeometryEffect(id: "selection", in: pill)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                .fill(palette.panelSecondary.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                        .stroke(palette.glassStrokeSoft, lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity)
    }
}
