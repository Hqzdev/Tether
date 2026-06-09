import AppKit
import Networking
import SwiftUI

struct AppSettingsView: View {
    var body: some View {
        TabView {
            ProxySettingsView()
                .tabItem {
                    Label("Proxy", systemImage: "network")
                }
        }
        .frame(width: 480)
    }
}

private struct ProxySettingsView: View {
    @State private var portText = String(ProxySettingsStore.current.port)
    @State private var openAIUpstreamURL = ProxySettingsStore.current.openAIUpstreamURL
    @State private var anthropicUpstreamURL = ProxySettingsStore.current.anthropicUpstreamURL
    @State private var localCacheEnabled = ProxySettingsStore.current.localCacheEnabled
    @State private var footerMessage = "Requires proxy restart"
    @State private var footerMessageIsError = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                SettingsSection("Listen") {
                    SettingsRow("Port") {
                        TextField("", text: $portText)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                SettingsSection("Upstream URLs") {
                    SettingsRow("OpenAI") {
                        TextField("", text: $openAIUpstreamURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)
                    }

                    SettingsRow("Anthropic") {
                        TextField("", text: $anthropicUpstreamURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)
                    }
                }

                SettingsSection("Cache") {
                    HStack {
                        Text("Enable local cache")
                            .foregroundStyle(.primary)

                        Spacer(minLength: 16)

                        Toggle("", isOn: $localCacheEnabled)
                            .labelsHidden()
                    }

                    Button("Clear Cache") {
                        clearCache()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .top)

            Spacer(minLength: 0)

            Divider()

            HStack(spacing: 12) {
                Spacer(minLength: 0)

                Text(footerMessage)
                    .font(.caption)
                    .foregroundStyle(footerMessageIsError ? .red : .secondary)

                Button("Save & Restart") {
                    saveAndRestart()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.windowBackground)
        }
        .frame(width: 480, height: 360)
        .background(.windowBackground)
    }

    private func saveAndRestart() {
        do {
            let settings = try validatedSettings()
            ProxySettingsStore.save(settings)
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
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 10) {
                content
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct SettingsRow<Content: View>: View {
    private let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .foregroundStyle(.primary)
                .frame(width: 88, alignment: .leading)

            content

            Spacer(minLength: 0)
        }
    }
}
