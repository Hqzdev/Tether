import Core
import SwiftUI
import UI

/// Footer controls for editing a node response before replay.
struct InspectorReplayFooter: View {
    @Binding var editing: Bool
    @Binding var draft: String
    @Binding var tab: InspectorTab
    let node: AgentNode
    let responseText: String
    @Binding var responseEdits: [AgentNode.ID: String]
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 7) {
            if editing {
                Button {
                    responseEdits[node.id] = draft
                    editing = false
                } label: {
                    Text("Save Mocked Response & Replay")
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                }
                .buttonStyle(TimeTravelButtonStyle(active: true, palette: palette))

                Text("downstream steps will re-run against your edit - cancel")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(palette.textQuaternary)
                    .onTapGesture {
                        editing = false
                    }
            } else {
                Button {
                    draft = responseText
                    editing = true
                    tab = .response
                } label: {
                    Text("Time-Travel - Edit Response")
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                }
                .buttonStyle(TimeTravelButtonStyle(active: false, palette: palette))

                Text("intercept and rewrite this node output, then replay the chain")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(palette.textQuaternary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(palette.panelSecondary.opacity(0.50))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }
}
