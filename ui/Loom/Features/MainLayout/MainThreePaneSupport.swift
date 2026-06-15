import SwiftUI
import UI

/// Adaptive workspace size class.
enum WorkspaceMode {
    case wide
    case medium
    case compact
}

/// Derived layout metrics for the three-pane workspace.
struct AdaptiveWorkspaceLayout {
    let mode: WorkspaceMode
    let sidebarWidth: CGFloat
    let inspectorWidth: CGFloat
    let inspectorHeight: CGFloat

    /// Computes workspace breakpoints and pane sizes from the current window size.
    init(size: CGSize) {
        if size.width >= 1180, size.height >= 560 {
            mode = .wide
        } else if size.width >= 820, size.height >= 500 {
            mode = .medium
        } else {
            mode = .compact
        }

        sidebarWidth = min(max(size.width * 0.24, 240), mode == .wide ? 312 : 286)
        inspectorWidth = min(max(size.width * 0.28, 320), 432)
        inspectorHeight = min(max(size.height * 0.34, 210), 320)
    }
}

/// Compact workspace tabs.
enum CompactSection: String, CaseIterable, Identifiable {
    case calls = "Calls"
    case graph = "Graph"
    case inspector = "Inspector"

    var id: String { rawValue }
}

/// Segmented picker shown in compact workspace mode.
struct CompactSectionPicker: View {
    @Binding var selection: CompactSection
    let palette: AgentTracePalette

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(CompactSection.allCases) { section in
                Text(section.rawValue)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(palette.panelSecondary.opacity(0.70))
    }
}

/// Thin horizontal divider that follows the current trace palette.
struct HorizontalDividerLine: View {
    let palette: AgentTracePalette

    var body: some View {
        Rectangle()
            .fill(palette.borderSoft)
            .frame(height: 1)
    }
}

/// Full-screen dimmer used behind the settings panel.
struct WorkspaceSettingsOverlay: View {
    let palette: AgentTracePalette
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            AppSettingsView(onClose: onDismiss)
                .padding(30)
        }
    }
}
