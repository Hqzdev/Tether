import Core
import AppKit
import SwiftUI
import UI

/// Switches between the prompt, response, and metadata inspector bodies.
struct InspectorBody: View {
    let node: AgentNode
    let tab: InspectorTab
    let responseText: String
    let edited: Bool
    let replayImpact: TraceInvalidationResult?
    let editing: Bool
    @Binding var draft: String
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            switch tab {
            case .context:
                ContextBoundaryInspectorBody(
                    node: node,
                    replayImpact: replayImpact,
                    palette: palette
                )
            case .llmCall:
                LLMCallInspectorBody(
                    node: node,
                    responseText: responseText,
                    palette: palette
                )
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

private struct LLMCallInspectorBody: View {
    let node: AgentNode
    let responseText: String
    let palette: AgentTracePalette
    @State private var revealPrompt = false
    @State private var revealResponse = false

    var body: some View {
        EditorToolbar(
            title: "llm.call",
            chips: [
                node.provider,
                node.model,
                node.latency,
                node.cost
            ],
            palette: palette
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MetadataInlineRow(label: "Input Hash", value: node.inputHash, palette: palette)
                MetadataInlineRow(label: "Output Hash", value: node.outputHash, palette: palette)
                MetadataInlineRow(label: "Request ID", value: node.requestId, palette: palette)
                MetadataInlineRow(label: "Temperature", value: node.temperature.map { String(format: "%.2f", $0) } ?? "n/a", palette: palette)

                RawPayloadDisclosure(
                    title: "Raw Prompt",
                    revealed: $revealPrompt,
                    sections: [
                        CodeSection(label: "system", text: node.prompt.system),
                        CodeSection(label: "user", text: node.prompt.user)
                    ],
                    language: .text,
                    palette: palette
                )

                RawPayloadDisclosure(
                    title: "Raw Response",
                    revealed: $revealResponse,
                    sections: [CodeSection(label: nil, text: responseText)],
                    language: node.response.language,
                    palette: palette
                )
            }
        }
        .background(palette.panel.opacity(0.52))
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

/// Structured context-boundary view for the selected model call.
struct ContextBoundaryInspectorBody: View {
    let node: AgentNode
    let replayImpact: TraceInvalidationResult?
    let palette: AgentTracePalette

    var body: some View {
        EditorToolbar(
            title: "context.assembly",
            chips: [
                "\(node.contextInputs.sources.count) sources",
                "\(node.contextInputs.withheld.count) withheld",
                node.stale ? "stale" : "fresh"
            ],
            palette: palette
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ContextHashSection(node: node, palette: palette)
                ContextSourceSections(sources: node.contextInputs.sources, palette: palette)
                WithheldContextSection(withheld: node.contextInputs.withheld, palette: palette)
                ReplayBoundarySection(node: node, replayImpact: replayImpact, palette: palette)
            }
        }
        .background(palette.panel.opacity(0.52))
    }
}

private struct ContextHashSection: View {
    let node: AgentNode
    let palette: AgentTracePalette

    var body: some View {
        InspectorSection(title: "Boundary Hashes", palette: palette) {
            MetadataInlineRow(label: "Input Hash", value: node.inputHash, valueFontSize: 11, palette: palette)
            MetadataInlineRow(label: "Output Hash", value: node.outputHash, valueFontSize: 11, palette: palette)
            MetadataInlineRow(label: "Trace ID", value: node.traceId.isEmpty ? "n/a" : node.traceId, palette: palette)
            MetadataInlineRow(label: "Parent Span", value: node.parentSpanId ?? "root", palette: palette)
        }
    }
}

private struct ContextSourceSections: View {
    let sources: [AgentContextSource]
    let palette: AgentTracePalette

    var body: some View {
        InspectorSection(title: "Input Sources", palette: palette) {
            if sources.isEmpty {
                EmptyContextLine(text: "No structured context sources were retained.", palette: palette)
            } else {
                ForEach(AgentContextCategory.allCases) { category in
                    let bucket = sources.filter { $0.category == category }
                    if !bucket.isEmpty {
                        ContextCategoryGroup(category: category, sources: bucket, palette: palette)
                    }
                }
            }
        }
    }
}

private struct ContextCategoryGroup: View {
    let category: AgentContextCategory
    let sources: [AgentContextSource]
    let palette: AgentTracePalette
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.smooth(duration: 0.16)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                        .frame(width: 16)

                    Text(category.title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(palette.text)
                    Text("\(sources.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(palette.textTertiary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingHandCursor()

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(sources) { source in
                        ContextSourceRow(source: source, palette: palette)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.borderSoft)
                .frame(height: 1)
        }
    }
}

private struct ContextSourceRow: View {
    let source: AgentContextSource
    let palette: AgentTracePalette

    var body: some View {
        DisclosureGroup {
            Text(source.body?.isEmpty == false ? source.body ?? "" : "raw body not retained")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(source.body == nil ? palette.textQuaternary : palette.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(palette.panelSecondary.opacity(0.74))
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(source.kind)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(palette.accentBackground)
                        .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))

                    Text(source.pathOrId)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                HStack(spacing: 10) {
                    Text("#\(source.hash)")
                    Text(formatBytes(source.sizeBytes))
                    Text(source.body == nil ? "redacted" : "expandable")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(palette.textQuaternary)
            }
            .padding(.vertical, 8)
        }
        .tint(palette.accent)
        .padding(.leading, 12)
        .padding(.trailing, 2)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.borderSoft.opacity(0.72))
                .frame(height: 1)
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_024 {
            return String(format: "%.1fkb", Double(bytes) / 1_024)
        }

        return "\(bytes)b"
    }
}

private struct WithheldContextSection: View {
    let withheld: [String]
    let palette: AgentTracePalette

    var body: some View {
        InspectorSection(title: "Withheld / Deferred", palette: palette) {
            if withheld.isEmpty {
                EmptyContextLine(text: "none", palette: palette)
            } else {
                ForEach(withheld, id: \.self) { item in
                    MetadataInlineRow(label: "Filtered", value: item, palette: palette)
                }
            }
        }
    }
}

private struct ReplayBoundarySection: View {
    let node: AgentNode
    let replayImpact: TraceInvalidationResult?
    let palette: AgentTracePalette

    var body: some View {
        InspectorSection(title: "Replay Boundary", palette: palette) {
            if let replayImpact {
                MetadataInlineRow(label: "Reason", value: replayImpact.reason, palette: palette)
                MetadataInlineRow(
                    label: "Output Diff",
                    value: "\(replayImpact.previousOutputHash) -> \(replayImpact.outputHash)",
                    palette: palette
                )
                MetadataInlineRow(
                    label: "Invalidated",
                    value: replayImpact.invalidated.isEmpty ? "none" : replayImpact.invalidated.joined(separator: ", "),
                    palette: palette
                )
            } else if node.stale {
                MetadataInlineRow(label: "Reason", value: "invalidated-by-upstream-output", palette: palette)
                MetadataInlineRow(label: "Output Hash", value: node.outputHash, palette: palette)
                MetadataInlineRow(label: "Invalidated", value: node.id, palette: palette)
            } else {
                MetadataInlineRow(label: "Reason", value: "none", palette: palette)
                MetadataInlineRow(label: "Output Hash", value: node.outputHash, palette: palette)
            }
        }
    }
}

/// A simple labeled section used inside the inspector body.
struct InspectorSection<Content: View>: View {
    let title: String
    let palette: AgentTracePalette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.textTertiary)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 6)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.panel.opacity(0.42))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }
}

/// Compact key/value row shared by context, LLM call, and metadata surfaces.
struct MetadataInlineRow: View {
    let label: String
    let value: String
    let valueFontSize: CGFloat
    let palette: AgentTracePalette

    init(label: String, value: String, valueFontSize: CGFloat = 11.5, palette: AgentTracePalette) {
        self.label = label
        self.value = value
        self.valueFontSize = valueFontSize
        self.palette = palette
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(palette.textTertiary)
                .frame(width: 112, alignment: .leading)

            Text(value.isEmpty ? "n/a" : value)
                .font(.system(size: valueFontSize, design: .monospaced))
                .foregroundStyle(palette.text)
                .lineLimit(nil)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.borderSoft)
                .frame(height: 1)
        }
    }
}

private struct PointingHandCursorModifier: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                guard hovering != isHovering else { return }
                hovering = isHovering
                if isHovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onDisappear {
                if hovering {
                    NSCursor.pop()
                    hovering = false
                }
            }
    }
}

private extension View {
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursorModifier())
    }
}

/// Explicit raw payload reveal used by the LLM call layer.
struct RawPayloadDisclosure: View {
    let title: String
    @Binding var revealed: Bool
    let sections: [CodeSection]
    let language: ResponseLanguage
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.smooth(duration: 0.16)) {
                    revealed.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: revealed ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(title)
                        .font(.system(size: 11.5, weight: .semibold))
                    Spacer(minLength: 0)
                    Text(revealed ? "visible" : "redacted")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(revealed ? palette.amber : palette.textQuaternary)
                }
                .foregroundStyle(palette.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if revealed {
                CodeView(
                    sections: sections,
                    language: language,
                    highlightedStatus: nil,
                    palette: palette
                )
                .frame(minHeight: 160, idealHeight: 220, maxHeight: 280)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.borderSoft)
                .frame(height: 1)
        }
    }
}

private struct EmptyContextLine: View {
    let text: String
    let palette: AgentTracePalette

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundStyle(palette.textQuaternary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
    }
}
