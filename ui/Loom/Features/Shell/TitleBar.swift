import SwiftUI

struct TitleBar: View {
    let session: TraceSession?
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("AgentTrace")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)

                if let session {
                    Text(session.id)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.textTertiary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(palette.panelSecondary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(palette.border, lineWidth: 1))
                }
            }

            Spacer(minLength: 12)
        }
        .frame(height: 44)
        .padding(.leading, 88)
        .padding(.trailing, 16)
        .background(
            LinearGradient(
                colors: [palette.titleTop.opacity(0.64), palette.titleBottom.opacity(0.44)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }
}
