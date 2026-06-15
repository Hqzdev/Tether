import Core
import SwiftUI
import UI

/// Switches between the prompt, response, and metadata inspector bodies.
struct InspectorBody: View {
    let node: AgentNode
    let tab: InspectorTab
    let responseText: String
    let edited: Bool
    let editing: Bool
    @Binding var draft: String
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            switch tab {
            case .prompt:
                PromptInspectorBody(node: node, palette: palette)
            case .response:
                ResponseInspectorBody(
                    node: node,
                    responseText: responseText,
                    edited: edited,
                    editing: editing,
                    draft: $draft,
                    palette: palette
                )
            case .metadata:
                MetadataTable(node: node, edited: edited, palette: palette)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PromptInspectorBody: View {
    let node: AgentNode
    let palette: AgentTracePalette

    var body: some View {
        EditorToolbar(
            title: "request.prompt",
            chips: [
                "temp \(node.temperature.map { String(format: "%.1f", $0) } ?? "n/a")",
                "\(node.tokensIn) tok"
            ],
            palette: palette
        )
        CodeView(
            sections: [
                CodeSection(label: "system", text: node.prompt.system),
                CodeSection(label: "user", text: node.prompt.user)
            ],
            language: .text,
            highlightedStatus: nil,
            palette: palette
        )
    }
}

private struct ResponseInspectorBody: View {
    let node: AgentNode
    let responseText: String
    let edited: Bool
    let editing: Bool
    @Binding var draft: String
    let palette: AgentTracePalette

    private var responseChips: [String] {
        var chips: [String] = []
        if edited {
            chips.append("edited")
        }

        if let error = node.error {
            chips.append(error.code)
        } else if node.status == .running {
            chips.append("LIVE")
        } else {
            chips.append("200 OK")
        }

        return chips
    }

    var body: some View {
        EditorToolbar(
            title: node.response.language == .json ? "response.json" : "response.txt",
            chips: responseChips,
            palette: palette
        )

        if let error = node.error, !editing {
            ErrorBanner(error: error, palette: palette)
        }

        if editing {
            TextEditor(text: $draft)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(palette.green)
                .scrollContentBackground(.hidden)
                .background(palette.panelSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(palette.amber, lineWidth: 2)
                        .opacity(0.9)
                )
        } else {
            CodeView(
                sections: [CodeSection(label: nil, text: responseText)],
                language: node.response.language,
                highlightedStatus: node.status == .error ? .error : nil,
                palette: palette
            )
        }
    }
}
