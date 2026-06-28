import AppKit
import Foundation

@MainActor
enum UpdateInstallController {
    static func confirmAndOpenTerminal() {
        let alert = NSAlert()
        alert.messageText = "Update Tether from Terminal?"
        alert.informativeText = "Tether will open Terminal and run tether update. The app may close during the update, install the latest release, and reopen when the update finishes."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        openTerminalUpdate()
    }

    private static func openTerminalUpdate() {
        let command = [
            "if command -v tether >/dev/null 2>&1",
            "then tether update",
            "elif [ -x \"$HOME/.local/bin/tether\" ]",
            "then \"$HOME/.local/bin/tether\" update",
            "else echo \"tether CLI was not found.\"",
            "echo \"Install it with:\"",
            "echo \"curl -fsSL https://tetherapp.vercel.app/install.sh | bash\"",
            "fi"
        ].joined(separator: "; ")

        let script = """
        tell application "Terminal"
          activate
          do script "\(escapedAppleScriptString(command))"
        end tell
        """

        var error: NSDictionary?
        if NSAppleScript(source: script)?.executeAndReturnError(&error) == nil {
            showError(error)
        }
    }

    private static func escapedAppleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func showError(_ error: NSDictionary?) {
        let alert = NSAlert()
        alert.messageText = "Could not open Terminal"
        alert.informativeText = error?[NSAppleScript.errorMessage] as? String ?? "Run tether update from Terminal."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
