import Core
import SwiftUI

public struct StatusDot: View {
    let status: NodeStatus
    let palette: AgentTracePalette
    let size: CGFloat

    public init(status: NodeStatus, palette: AgentTracePalette, size: CGFloat = 8) {
        self.status = status
        self.palette = palette
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(palette.color(for: status))
            .overlay(
                Circle()
                    .stroke(palette.color(for: status).opacity(0.35), lineWidth: max(1, size / 6))
                    .blur(radius: max(0.6, size / 10))
            )
            .frame(width: size, height: size)
    }
}

public struct DividerLine: View {
    let palette: AgentTracePalette

    public init(palette: AgentTracePalette) {
        self.palette = palette
    }

    public var body: some View {
        Rectangle()
            .fill(palette.border)
            .frame(width: 1)
    }
}

public struct HorizontalDividerLine: View {
    let palette: AgentTracePalette

    public init(palette: AgentTracePalette) {
        self.palette = palette
    }

    public var body: some View {
        Rectangle()
            .fill(palette.border)
            .frame(height: 1)
    }
}

public struct StageBackground: View {
    let palette: AgentTracePalette

    public init(palette: AgentTracePalette) {
        self.palette = palette
    }

    public var body: some View {
        ZStack {
            palette.stage
        }
        .ignoresSafeArea()
    }
}
