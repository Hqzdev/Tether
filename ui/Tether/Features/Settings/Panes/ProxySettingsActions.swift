import Foundation
import Networking

extension ProxySettingsView {
    /// Persists validated proxy settings and restarts the local helper.
    func saveAndRestart() {
        do {
            let settings = try validatedSettings()
            ProxySettingsStore.save(settings)
            saveProviderKeys()
            LocalProxyLauncher.shared.restart()
            footerMessage = "Requires proxy restart"
            footerMessageIsError = false
        } catch {
            footerMessage = error.localizedDescription
            footerMessageIsError = true
        }
    }

    /// Clears cached proxy responses through the local API.
    func clearCache() {
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

    /// Validates the proxy form and returns a persistable settings value.
    func validatedSettings() throws -> ProxySettings {
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

    /// Normalizes and validates an upstream URL field.
    func normalizedURL(_ value: String, label: String) throws -> String {
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

    /// Stores entered provider keys and clears plaintext field state.
    private func saveProviderKeys() {
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
    }
}
