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

        let process = Process()
        process.executableURL = binaryURL
        process.currentDirectoryURL = binaryURL.deletingLastPathComponent()
        process.environment = proxyEnvironment()

        do {
            let logURL = try logFileURL()
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

    private func proxyEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let settings = ProxySettingsStore.current
        environment["Tether_ADDR"] = settings.listenAddress
        environment["Tether_CACHE"] = settings.localCacheEnabled ? "on" : "off"
        environment["OPENAI_UPSTREAM"] = settings.openAIUpstreamURL
        environment["ANTHROPIC_UPSTREAM"] = settings.anthropicUpstreamURL
        environment["Tether_DB"] = appSupportDirectory()
            .appendingPathComponent("Tether-cache.sqlite")
            .path
        return environment
    }

    private func logFileURL() throws -> URL {
        let url = appSupportDirectory().appendingPathComponent("proxy.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        return url
    }

    private func appSupportDirectory() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent("AgentTrace", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
