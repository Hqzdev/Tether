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

    @EnvironmentObject private var preferences: AppPreferences

    @State private var cachedSections: [CodeSection]
    @State private var cachedRows: [CodeRow]

    init(
        sections: [CodeSection],
        language: ResponseLanguage,
        highlightedStatus: NodeStatus?,
        palette: AgentTracePalette
    ) {
        self.sections = sections
        self.language = language
        self.highlightedStatus = highlightedStatus
        self.palette = palette

        _cachedSections = State(initialValue: sections)
        _cachedRows = State(initialValue: Self.makeRows(from: sections))
    }

    /// Rows after applying the secret-redaction preference at render time.
    private var displayRows: [CodeRow] {
        guard preferences.redactSecrets else { return cachedRows }
        return cachedRows.map { row in
            guard let text = row.text else { return row }
            return CodeRow(number: row.number, label: row.label, text: Self.redactSecrets(in: text))
        }
    }

    /// Masks common API key and bearer-token shapes in inspector text.
    private static func redactSecrets(in text: String) -> String {
        let patterns = [
            "sk-ant-[A-Za-z0-9\\-_]{6,}",
            "sk-[A-Za-z0-9\\-_]{6,}",
            "Bearer\\s+[A-Za-z0-9\\-._]{6,}"
        ]

        var result = text
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "••• redacted •••")
        }
        return result
    }

    private static func makeRows(from sections: [CodeSection]) -> [CodeRow] {
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
        ScrollView(preferences.wrapInspectorLines ? .vertical : [.vertical, .horizontal]) {
            LazyVStack(spacing: 0) {
                ForEach(displayRows) { row in
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
        .onChange(of: sections) { _, newSections in
            guard cachedSections != newSections else { return }
            cachedSections = newSections
            cachedRows = Self.makeRows(from: newSections)
        }
    }
}
