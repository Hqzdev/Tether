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
    @Binding var replayImpacts: [AgentNode.ID: TraceInvalidationResult]
    let onSaveMockResponse: SaveMockResponseAction
    let palette: AgentTracePalette
    @State private var saving = false
    @State private var saveError: String?

    var body: some View {
        VStack(spacing: 7) {
            if editing {
                Button {
                    saveDraft()
                } label: {
                    Text(saving ? "Saving Replay Boundary..." : "Save Mocked Response & Replay")
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                }
                .buttonStyle(TimeTravelButtonStyle(active: true, palette: palette))
                .disabled(saving)

                Text(saveError ?? "downstream steps will re-run against your edit - cancel")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(saveError == nil ? palette.textQuaternary : palette.pinkText)
                    .onTapGesture {
                        editing = false
                        saveError = nil
                    }
                    .lineLimit(1)
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

    private func saveDraft() {
        guard !saving else { return }

        saving = true
        saveError = nil
        Task {
            do {
                let impact = try await onSaveMockResponse.perform(node, draft)
                await MainActor.run {
                    responseEdits[node.id] = draft
                    replayImpacts[node.id] = impact
                    editing = false
                    tab = .context
                    saving = false
                }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    saving = false
                }
            }
        }
    }
}
