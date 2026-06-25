import AppKit
import Combine
import Foundation

@MainActor
final class WorkspaceAccessStore: ObservableObject {
    static let shared = WorkspaceAccessStore()

    @Published private(set) var workspacePath: String?
    @Published private(set) var codexPath: String?

    private let defaults = UserDefaults.standard
    private var workspaceURL: URL?
    private var codexURL: URL?
    private var workspaceAccessing = false
    private var codexAccessing = false

    var hasWorkspaceAccess: Bool { workspaceURL != nil }
    var hasCodexAccess: Bool { codexURL != nil }

    private init() {
        restorePersistedAccess()
    }

    func restorePersistedAccess() {
        workspaceURL = Self.resolveBookmark(key: Self.workspaceBookmarkKey)
        codexURL = Self.resolveBookmark(key: Self.codexBookmarkKey)
        workspacePath = workspaceURL?.path
        codexPath = codexURL?.path

        if !workspaceAccessing, workspaceURL?.startAccessingSecurityScopedResource() == true {
            workspaceAccessing = true
        }
        if !codexAccessing, codexURL?.startAccessingSecurityScopedResource() == true {
            codexAccessing = true
        }
    }

    func ensureStartupAccess() {
        restorePersistedAccess()
        if workspaceURL == nil && !defaults.bool(forKey: Self.workspacePromptedKey) {
            requestWorkspaceAccess()
        }
    }

    func requestWorkspaceAccess() {
        defaults.set(true, forKey: Self.workspacePromptedKey)
        requestDirectory(
            title: "Grant Tether workspace access",
            message: "Choose the repository folder Tether should inspect for file changes.",
            defaultURL: Self.defaultWorkspaceURL(),
            bookmarkKey: Self.workspaceBookmarkKey
        ) { [weak self] url in
            self?.workspaceURL = url
            self?.workspacePath = url.path
            if self?.workspaceAccessing != true, url.startAccessingSecurityScopedResource() {
                self?.workspaceAccessing = true
            }
        }
    }

    func requestCodexAccess() {
        defaults.set(true, forKey: Self.codexPromptedKey)
        requestDirectory(
            title: "Grant Tether Codex log access",
            message: "Choose your .codex folder so Tether can observe Terminal Codex runs.",
            defaultURL: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true),
            bookmarkKey: Self.codexBookmarkKey
        ) { [weak self] url in
            self?.codexURL = url
            self?.codexPath = url.path
            if self?.codexAccessing != true, url.startAccessingSecurityScopedResource() {
                self?.codexAccessing = true
            }
        }
    }

    func forgetWorkspaceAccess() {
        if workspaceAccessing {
            workspaceURL?.stopAccessingSecurityScopedResource()
            workspaceAccessing = false
        }
        workspaceURL = nil
        workspacePath = nil
        defaults.removeObject(forKey: Self.workspaceBookmarkKey)
        defaults.removeObject(forKey: Self.workspacePromptedKey)
    }

    func forgetCodexAccess() {
        if codexAccessing {
            codexURL?.stopAccessingSecurityScopedResource()
            codexAccessing = false
        }
        codexURL = nil
        codexPath = nil
        defaults.removeObject(forKey: Self.codexBookmarkKey)
        defaults.removeObject(forKey: Self.codexPromptedKey)
    }

    nonisolated static func withWorkspaceAccess<T>(_ body: (URL) -> T) -> T? {
        guard let url = resolveBookmark(key: workspaceBookmarkKey) ?? defaultWorkspaceURL() else { return nil }
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return body(url)
    }

    nonisolated static func withCodexAccess<T>(_ body: (URL) -> T) -> T? {
        guard let url = resolveBookmark(key: codexBookmarkKey) else { return nil }
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return body(url)
    }

    private func requestDirectory(
        title: String,
        message: String,
        defaultURL: URL?,
        bookmarkKey: String,
        onGrant: @escaping (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
        panel.prompt = "Grant Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = defaultURL

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(data, forKey: bookmarkKey)
            onGrant(url)
        } catch {
            defaults.removeObject(forKey: bookmarkKey)
        }
    }

    nonisolated private static func resolveBookmark(key: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
            if stale {
                let refreshed = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(refreshed, forKey: key)
            }
            return url
        } catch {
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
    }

    nonisolated private static func defaultWorkspaceURL() -> URL? {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    nonisolated private static let workspaceBookmarkKey = "tether.access.workspaceBookmark"
    nonisolated private static let codexBookmarkKey = "tether.access.codexBookmark"
    nonisolated private static let workspacePromptedKey = "tether.access.workspacePrompted"
    nonisolated private static let codexPromptedKey = "tether.access.codexPrompted"
}
