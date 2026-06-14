import Foundation

@MainActor
public final class LocalProxyLauncher {
    public static let shared = LocalProxyLauncher()

    private var process: Process?

    private init() {}

    @discardableResult
    public func startIfAvailable() -> Bool {
        if process?.isRunning == true {
            return true
        }

        guard let binaryURL = findProxyBinary() else {
            return false
        }

        let runtimeDirectory: URL
        do {
            runtimeDirectory = try Self.runtimeDirectory()
        } catch {
            return false
        }

        let process = Process()
        process.executableURL = binaryURL
        process.currentDirectoryURL = binaryURL.deletingLastPathComponent()
        process.environment = proxyEnvironment(runtimeDirectory: runtimeDirectory)

        do {
            let logURL = try logFileURL(in: runtimeDirectory)
            let logHandle = try FileHandle(forWritingTo: logURL)
            try logHandle.seekToEnd()
            process.standardOutput = logHandle
            process.standardError = logHandle
            try process.run()
            self.process = process
            return true
        } catch {
            return false
        }
    }

    public func stop() {
        guard let process, process.isRunning else { return }
        process.terminate()
        self.process = nil
    }

    @discardableResult
    public func restart() -> Bool {
        stop()
        return startIfAvailable()
    }

    private func findProxyBinary() -> URL? {
        let fileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let candidates = [
            repoRoot.appendingPathComponent("proxy/target/debug/loom-proxy"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/loom-proxy")
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private func proxyEnvironment(runtimeDirectory: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let settings = ProxySettingsStore.current
        environment["LOOM_ADDR"] = settings.listenAddress
        environment["LOOM_CACHE"] = settings.localCacheEnabled ? "on" : "off"
        environment["OPENAI_UPSTREAM"] = settings.openAIUpstreamURL
        environment["ANTHROPIC_UPSTREAM"] = settings.anthropicUpstreamURL
        environment["LOOM_DB"] = runtimeDirectory
            .appendingPathComponent("loom-cache.sqlite")
            .path
        if let openAIKey = KeychainStore.read(.openAIAPIKey) {
            environment["OPENAI_API_KEY"] = openAIKey
        }
        if let anthropicKey = KeychainStore.read(.anthropicAPIKey) {
            environment["ANTHROPIC_API_KEY"] = anthropicKey
        }
        return environment
    }

    private func logFileURL(in runtimeDirectory: URL) throws -> URL {
        let url = runtimeDirectory.appendingPathComponent("proxy.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        return url
    }

    private static func runtimeDirectory() throws -> URL {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent("Loom", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
