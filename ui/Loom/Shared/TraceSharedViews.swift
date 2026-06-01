import SwiftUI

struct StatusDot: View {
    let status: NodeStatus
    let palette: AgentTracePalette

    var body: some View {
        Circle()
            .fill(palette.color(for: status))
            .frame(width: 8, height: 8)
    }
}

struct DividerLine: View {
    let palette: AgentTracePalette

    var body: some View {
        Rectangle()
            .fill(palette.border)
            .frame(width: 1)
    }
}

struct HorizontalDividerLine: View {
    let palette: AgentTracePalette

    var body: some View {
        Rectangle()
            .fill(palette.border)
            .frame(height: 1)
    }
}

struct StageBackground: View {
    let palette: AgentTracePalette

    var body: some View {
        ZStack {
            palette.stage
        }
        .ignoresSafeArea()
    }
}
