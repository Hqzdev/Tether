import Core
import SwiftUI
import UI

/// Numbered row rendered by the inspector code viewer.
struct CodeRow: Equatable, Identifiable {
    let id: Int
    let number: Int
    let label: String?
    let text: String?

    init(number: Int, label: String?, text: String?) {
        id = number
        self.number = number
        self.label = label
        self.text = text
    }
}

/// Renders one numbered line or labeled section break in the inspector.
struct CodeLineView: View {
    let row: CodeRow
    let language: ResponseLanguage
    let highlightedStatus: NodeStatus?
    let palette: AgentTracePalette

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("\(row.number)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(palette.textQuaternary)
                .frame(width: 48, alignment: .trailing)
                .padding(.trailing, 12)
                .padding(.leading, 14)
                .frame(minHeight: 20)
                .background(palette.panel.opacity(0.48))
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(palette.borderSoft)
                        .frame(width: 1)
                }

            if let label = row.label {
                SectionLabelLine(label: label, palette: palette)
            } else {
                CodeTextLine(
                    text: row.text ?? "",
                    language: language,
                    highlightedStatus: highlightedStatus,
                    palette: palette
                )
            }
        }
    }
}

private struct SectionLabelLine: View {
    let label: String
    let palette: AgentTracePalette

    private var labelAccent: Color {
        switch label.lowercased() {
        case "system":
            return palette.violet
        case "user":
            return palette.accent
        case "assistant":
            return palette.green
        default:
            return palette.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(labelAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(labelAccent.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                        .stroke(labelAccent.opacity(0.32), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))

            Rectangle()
                .fill(labelAccent.opacity(0.18))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(palette.panel.opacity(0.56))
    }
}

private struct CodeTextLine: View {
    let text: String
    let language: ResponseLanguage
    let highlightedStatus: NodeStatus?
    let palette: AgentTracePalette

    var body: some View {
        syntaxText(text)
            .font(.system(size: 12, design: .monospaced))
            .lineSpacing(5)
            .foregroundStyle(highlightedStatus == .error ? palette.pinkText : palette.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
            .padding(.horizontal, 16)
            .background(highlightedStatus == .error ? palette.pinkBackground.opacity(0.55) : Color.clear)
            .overlay(alignment: .leading) {
                if highlightedStatus == .error {
                    Rectangle()
                        .fill(palette.pink)
                        .frame(width: 3)
                }
            }
    }

    /// Returns display text while preserving empty rows for line-height consistency.
    private func syntaxText(_ text: String) -> Text {
        guard language == .json else {
            return Text(text.isEmpty ? " " : text)
        }

        return Text(text.isEmpty ? " " : text)
    }
}
