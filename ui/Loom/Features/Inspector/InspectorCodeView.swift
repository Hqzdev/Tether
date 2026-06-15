import Core
import SwiftUI
import UI

/// Compact toolbar shown above prompt and response code panes.
struct EditorToolbar: View {
    let title: String
    let chips: [String]
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(palette.textQuaternary)

            Spacer(minLength: 0)

            ForEach(chips, id: \.self) { chip in
                ChipLabel(chip: chip, palette: palette)
            }
        }
        .frame(height: 32)
        .padding(.horizontal, 12)
        .background(palette.panelSecondary)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.borderSoft)
                .frame(height: 1)
        }
    }
}

private struct ChipLabel: View {
    let chip: String
    let palette: AgentTracePalette

    var body: some View {
        Text(chip)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }

    private var foreground: Color {
        chip == "200 OK" ? palette.green : chip == "LIVE" ? palette.amber : chip == "edited" ? palette.amber : palette.textTertiary
    }

    private var background: Color {
        chip == "200 OK" ? palette.greenBackground : chip == "LIVE" ? palette.amber.opacity(0.10) : palette.panel
    }

    private var stroke: Color {
        chip == "200 OK" ? palette.greenDim : chip == "LIVE" ? palette.amber.opacity(0.36) : palette.border
    }
}

/// One labeled or text row in the inspector code viewer.
struct CodeSection: Hashable {
    let label: String?
    let text: String
}

/// Scrollable monospaced renderer for prompt and response text.
struct CodeView: View {
    let sections: [CodeSection]
    let language: ResponseLanguage
    let highlightedStatus: NodeStatus?
    let palette: AgentTracePalette

    private var rows: [CodeRow] {
        var result: [CodeRow] = []
        var lineNumber = 1

        for section in sections {
            if let label = section.label {
                result.append(CodeRow(number: lineNumber, label: label, text: nil))
                lineNumber += 1
            }

            let lines = section.text.isEmpty ? [""] : section.text.components(separatedBy: .newlines)
            for line in lines {
                result.append(CodeRow(number: lineNumber, label: nil, text: line))
                lineNumber += 1
            }
        }

        return result
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    CodeLineView(
                        row: row,
                        language: language,
                        highlightedStatus: highlightedStatus,
                        palette: palette
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(palette.panelSecondary.opacity(0.52))
    }
}
