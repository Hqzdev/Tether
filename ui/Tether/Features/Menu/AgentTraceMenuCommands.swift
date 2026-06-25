import AppKit
import SwiftUI

struct AgentTraceMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                NotificationCenter.default.post(name: .agentTraceShowSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .newItem) {
            Button("Export Traces...") {
                NotificationCenter.default.post(name: .agentTraceExportTraces, object: nil)
            }
            .keyboardShortcut("e", modifiers: .command)

            Button("Copy Failure Analysis Prompt") {
                NotificationCenter.default.post(name: .agentTraceCopyFailureAnalysisPrompt, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.shift, .command])

            Divider()
        }

        CommandGroup(replacing: .pasteboard) {
            Button("Copy") {
                NotificationCenter.default.post(name: .agentTraceCopySelection, object: nil)
            }
            .keyboardShortcut("c", modifiers: .command)

            Button("Select All") {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("a", modifiers: .command)

            Divider()

            Button("Clear View") {
                NotificationCenter.default.post(name: .agentTraceClearView, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.option, .command])
        }

        CommandMenu("View") {
            Button("Toggle Inspector") {
                NotificationCenter.default.post(name: .agentTraceToggleInspector, object: nil)
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("Show Inspector") {
                NotificationCenter.default.post(name: .agentTraceShowInspector, object: nil)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Show Graph") {
                NotificationCenter.default.post(name: .agentTraceShowGraph, object: nil)
            }
            .keyboardShortcut("2", modifiers: .command)

            Divider()

            Button("Previous Node") {
                NotificationCenter.default.post(name: .agentTraceSelectPreviousNode, object: nil)
            }
            .keyboardShortcut("[", modifiers: .command)

            Button("Next Node") {
                NotificationCenter.default.post(name: .agentTraceSelectNextNode, object: nil)
            }
            .keyboardShortcut("]", modifiers: .command)

            Divider()

            Button("Replay Selected Node") {
                NotificationCenter.default.post(name: .agentTraceReplaySelectedNode, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Reload") {
                NotificationCenter.default.post(name: .agentTraceReload, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.shift, .command])
        }

        CommandGroup(replacing: .help) {
            Button("Tether Help") {
                NotificationCenter.default.post(name: .agentTraceShowOnboarding, object: nil)
            }

            Button("How to Connect an Agent...") {
                NotificationCenter.default.post(name: .agentTraceShowOnboarding, object: nil)
            }

            Divider()

            Button("Send Feedback...") {
                if let url = URL(string: "mailto:?subject=Tether%20Feedback") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

extension Notification.Name {
    static let agentTraceNewSession = Notification.Name("agentTraceNewSession")
    static let agentTraceExportTraces = Notification.Name("agentTraceExportTraces")
    static let agentTraceCopyFailureAnalysisPrompt = Notification.Name("agentTraceCopyFailureAnalysisPrompt")
    static let agentTraceCopySelection = Notification.Name("agentTraceCopySelection")
    static let agentTraceClearView = Notification.Name("agentTraceClearView")
    static let agentTraceClearAllTraces = Notification.Name("agentTraceClearAllTraces")
    static let agentTraceShowInspector = Notification.Name("agentTraceShowInspector")
    static let agentTraceShowGraph = Notification.Name("agentTraceShowGraph")
    static let agentTraceToggleInspector = Notification.Name("agentTraceToggleInspector")
    static let agentTraceSelectPreviousNode = Notification.Name("agentTraceSelectPreviousNode")
    static let agentTraceSelectNextNode = Notification.Name("agentTraceSelectNextNode")
    static let agentTraceReplaySelectedNode = Notification.Name("agentTraceReplaySelectedNode")
    static let agentTraceReload = Notification.Name("agentTraceReload")
    static let agentTraceShowOnboarding = Notification.Name("agentTraceShowOnboarding")
    static let agentTraceShowSettings = Notification.Name("agentTraceShowSettings")
    static let agentTraceResetGraphLayout = Notification.Name("agentTraceResetGraphLayout")
}
