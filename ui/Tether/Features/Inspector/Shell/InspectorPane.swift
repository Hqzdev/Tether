import Core
import Networking
import SwiftUI
import UI

struct SaveMockResponseAction: Sendable {
    let perform: @MainActor @Sendable (AgentNode, String) async throws -> TraceInvalidationResult

    init(_ perform: @escaping @MainActor @Sendable (AgentNode, String) async throws -> TraceInvalidationResult) {
        self.perform = perform
    }
}

struct RunMultipleAction: Sendable {
    let perform: @MainActor @Sendable (AgentNode, Int) async throws -> [TraceReplayResult]

    init(_ perform: @escaping @MainActor @Sendable (AgentNode, Int) async throws -> [TraceReplayResult]) {
        self.perform = perform
    }
}

struct ReplayWithModelAction: Sendable {
    let perform: @MainActor @Sendable (AgentNode, String) async throws -> ReplayResult

    init(_ perform: @escaping @MainActor @Sendable (AgentNode, String) async throws -> ReplayResult) {
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
    let onRunMultiple: RunMultipleAction
    let onReplayWithModel: ReplayWithModelAction
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
                    onRunMultiple: onRunMultiple,
                    onReplayWithModel: onReplayWithModel,
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
            VStack(alignment: .leading, spacing: 8) {
                if let node {
                    HStack(alignment: .top, spacing: 12) {
                        Text(node.stepName)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(palette.text)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        InspectorStatusBadge(status: node.status, stale: node.stale, palette: palette)
                    }

                    InspectorModelBadges(node: node, palette: palette)
                } else {
                    Text("Inspector")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            InspectorTabPicker(tab: $tab, palette: palette)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }
}

private struct InspectorStatusBadge: View {
    let status: NodeStatus
    let stale: Bool
    let palette: AgentTracePalette

    private var text: String {
        stale ? "STALE" : status.label
    }

    private var color: Color {
        stale ? palette.amber : palette.color(for: status)
    }

    private var background: Color {
        stale ? palette.amber.opacity(0.10) : palette.background(for: status)
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(color.opacity(0.22), lineWidth: 1)
            }
            .fixedSize()
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
