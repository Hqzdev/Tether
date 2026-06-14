import AppKit
import Networking
import SwiftUI
import UI

struct AppSettingsView: View {
    var body: some View {
        TabView {
            ProxySettingsView()
                .tabItem {
                    Label("Proxy", systemImage: "network")
                }
        }
        .frame(width: 480)
        .preferredColorScheme(.light)
    }
}

private struct ProxySettingsView: View {
    private let palette = AgentTracePalette(light: true)

    @State private var portText = String(ProxySettingsStore.current.port)
    @State private var openAIUpstreamURL = ProxySettingsStore.current.openAIUpstreamURL
    @State private var anthropicUpstreamURL = ProxySettingsStore.current.anthropicUpstreamURL
    @State private var localCacheEnabled = ProxySettingsStore.current.localCacheEnabled
    @State private var footerMessage = "Requires proxy restart"
    @State private var footerMessageIsError = false
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var openAIKeyStored = KeychainStore.hasValue(.openAIAPIKey)
    @State private var anthropicKeyStored = KeychainStore.hasValue(.anthropicAPIKey)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                SettingsSection("Listen", palette: palette) {
                    SettingsRow("Port", palette: palette) {
                        TextField("", text: $portText)
                            .settingsField(palette: palette)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                SettingsSection("Upstream URLs", palette: palette) {
                    SettingsRow("OpenAI", palette: palette) {
                        TextField("", text: $openAIUpstreamURL)
                            .settingsField(palette: palette)
                            .frame(maxWidth: 300)
                    }

                    SettingsRow("Anthropic", palette: palette) {
                        TextField("", text: $anthropicUpstreamURL)
                            .settingsField(palette: palette)
                            .frame(maxWidth: 300)
                    }
                }

                SettingsSection("Provider Keys", palette: palette) {
                    SettingsRow("OpenAI", palette: palette) {
                        SecureField(openAIKeyStored ? "•••••••• stored" : "sk-…", text: $openAIKey)
                            .settingsField(palette: palette)
                            .frame(maxWidth: 300)
                    }

                    SettingsRow("Anthropic", palette: palette) {
                        SecureField(anthropicKeyStored ? "•••••••• stored" : "sk-ant-…", text: $anthropicKey)
                            .settingsField(palette: palette)
                            .frame(maxWidth: 300)
                    }

                    Text("Stored in the macOS Keychain. The proxy injects these on upstream calls when your client doesn't send its own key.")
                        .font(.caption)
                        .foregroundStyle(palette.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SettingsSection("Cache", palette: palette) {
                    HStack {
                        Text("Enable local cache")
                            .foregroundStyle(palette.text)

                        Spacer(minLength: 16)

                        Toggle("", isOn: $localCacheEnabled)
                            .labelsHidden()
                    }

                    Button {
                        clearCache()
                    } label: {
                        Label("Clear Cache", systemImage: "trash")
                            .frame(height: 30)
                    }
                    .buttonStyle(SettingsSecondaryButtonStyle(palette: palette, destructive: true))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .top)

            Spacer(minLength: 0)

            HorizontalDividerLine(palette: palette)

            HStack(spacing: 12) {
                Spacer(minLength: 0)

                Text(footerMessage)
                    .font(.caption)
                    .foregroundStyle(footerMessageIsError ? palette.pinkText : palette.textTertiary)

                Button {
                    saveAndRestart()
                } label: {
                    Text("Save & Restart")
                        .frame(width: 132, height: 34)
                }
                .buttonStyle(SettingsPrimaryButtonStyle(palette: palette))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(palette.panelSecondary.opacity(0.72))
        }
        .frame(width: 480, height: 360)
        .background {
            StageBackground(palette: palette)
        }
    }

    private func saveAndRestart() {
        do {
            let settings = try validatedSettings()
            ProxySettingsStore.save(settings)

            if !openAIKey.isEmpty {
                KeychainStore.save(.openAIAPIKey, value: openAIKey)
                openAIKey = ""
                openAIKeyStored = true
            }
            if !anthropicKey.isEmpty {
                KeychainStore.save(.anthropicAPIKey, value: anthropicKey)
                anthropicKey = ""
                anthropicKeyStored = true
            }

            LocalProxyLauncher.shared.restart()
            footerMessage = "Requires proxy restart"
            footerMessageIsError = false
        } catch {
            footerMessage = error.localizedDescription
            footerMessageIsError = true
        }
    }

    private func clearCache() {
        Task {
            do {
                try await TraceAPIClient().clearCache()
                footerMessage = "Cache cleared"
                footerMessageIsError = false
            } catch {
                footerMessage = error.localizedDescription
                footerMessageIsError = true
            }
        }
    }

    private func validatedSettings() throws -> ProxySettings {
        let trimmedPort = portText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(trimmedPort), (1...65535).contains(port) else {
            throw ProxySettingsValidationError.invalidPort
        }

        let openAIURL = try normalizedURL(openAIUpstreamURL, label: "OpenAI")
        let anthropicURL = try normalizedURL(anthropicUpstreamURL, label: "Anthropic")

        return ProxySettings(
            port: port,
            openAIUpstreamURL: openAIURL,
            anthropicUpstreamURL: anthropicURL,
            localCacheEnabled: localCacheEnabled
        )
    }

    private func normalizedURL(_ value: String, label: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            throw ProxySettingsValidationError.invalidURL(label)
        }

        return trimmed
    }
}

private struct SettingsSection<Content: View>: View {
    private let title: String
    private let palette: AgentTracePalette
    private let content: Content

    init(_ title: String, palette: AgentTracePalette, @ViewBuilder content: () -> Content) {
        self.title = title
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(palette.textTertiary)

            VStack(spacing: 10) {
                content
            }
            .padding(16)
            .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                    .stroke(palette.borderSoft, lineWidth: 1)
            )
        }
    }
}

private struct SettingsRow<Content: View>: View {
    private let title: String
    private let palette: AgentTracePalette
    private let content: Content

    init(_ title: String, palette: AgentTracePalette, @ViewBuilder content: () -> Content) {
        self.title = title
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .foregroundStyle(palette.textSecondary)
                .frame(width: 88, alignment: .leading)

            content

            Spacer(minLength: 0)
        }
    }
}

private struct SettingsFieldModifier: ViewModifier {
    let palette: AgentTracePalette

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 12.5, design: .monospaced))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.white.opacity(0.88), in: Capsule())
            .overlay(Capsule().stroke(palette.border, lineWidth: 1))
    }
}

private extension View {
    func settingsField(palette: AgentTracePalette) -> some View {
        modifier(SettingsFieldModifier(palette: palette))
    }
}

private struct SettingsPrimaryButtonStyle: ButtonStyle {
    let palette: AgentTracePalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .background(palette.text)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

private struct SettingsSecondaryButtonStyle: ButtonStyle {
    let palette: AgentTracePalette
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(destructive ? palette.pinkText : palette.textSecondary)
            .padding(.horizontal, 12)
            .background(destructive ? palette.pinkBackground : palette.panelSecondary, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(destructive ? palette.pinkDim : palette.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}
