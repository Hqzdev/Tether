import Core
import SwiftUI
import UI

struct SaveMockResponseAction: Sendable {
    let perform: @MainActor @Sendable (AgentNode, String) async throws -> TraceInvalidationResult

    init(_ perform: @escaping @MainActor @Sendable (AgentNode, String) async throws -> TraceInvalidationResult) {
        self.perform = perform
    }
}

/// Right-hand inspector that shows prompt, response, and metadata for the selected node.
struct InspectorPane: View {
    let node: AgentNode?
    @Binding var tab: InspectorTab
    @Binding var responseEdits: [AgentNode.ID: String]
    @Binding var replayImpacts: [AgentNode.ID: TraceInvalidationResult]
    let onSaveMockResponse: SaveMockResponseAction
    let palette: AgentTracePalette

    @State private var editing = false
    @State private var draft = ""

    private var responseText: String {
        guard let node else { return "" }
        return responseEdits[node.id] ?? node.response.text
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorHeader(node: node, tab: $tab, palette: palette)

            if let node {
                InspectorBody(
                    node: node,
                    tab: tab,
                    responseText: responseText,
                    edited: responseEdits[node.id] != nil,
                    replayImpact: replayImpacts[node.id],
                    editing: editing,
                    draft: $draft,
                    palette: palette
                )
            } else {
                InspectorEmptyState(palette: palette)
            }

            if let node {
                InspectorReplayFooter(
                    editing: $editing,
                    draft: $draft,
                    tab: $tab,
                    node: node,
                    responseText: responseText,
                    responseEdits: $responseEdits,
                    replayImpacts: $replayImpacts,
                    onSaveMockResponse: onSaveMockResponse,
                    palette: palette
                )
            }
        }
        .background(palette.panel.opacity(0.54))
        .onChange(of: node?.id) {
            editing = false
            draft = ""
        }
        .onChange(of: tab) {
            editing = false
        }
    }
}

private struct InspectorHeader: View {
    let node: AgentNode?
    @Binding var tab: InspectorTab
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 9) {
                if let node {
                    StatusDot(status: node.status, palette: palette)
                    Text(node.stepName)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                    InspectorModelBadges(node: node, palette: palette)
                } else {
                    Text("Inspector")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
            }

            InspectorTabPicker(tab: $tab, palette: palette)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }
}

private struct InspectorModelBadges: View {
    let node: AgentNode
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 6) {
            AgentBadge(name: node.agentName, palette: palette)

            Text("\(node.provider) / \(node.model)")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(palette.violet)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(palette.violet.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                        .stroke(palette.violetBorder, lineWidth: 1)
                )
        }
    }
}
