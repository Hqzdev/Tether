import Core
import Networking
import SwiftUI
import UI

/// Footer controls for editing a node response before replay.
struct InspectorReplayFooter: View {
    @Binding var editing: Bool
    @Binding var draft: String
    @Binding var tab: InspectorTab
    let node: AgentNode
    let responseText: String
    @Binding var responseEdits: [AgentNode.ID: String]
    @Binding var replayImpacts: [AgentNode.ID: TraceInvalidationResult]
    let onSaveMockResponse: SaveMockResponseAction
    let onRunMultiple: RunMultipleAction
    let onReplayWithModel: ReplayWithModelAction
    let palette: AgentTracePalette
    @State private var saving = false
    @State private var saveError: String?
    @State private var runs: [TraceReplayResult] = []
    @State private var showingRunResults = false
    @State private var running = false
    @State private var runError: String?
    @State private var cometConfigured = false
    @State private var loadingCometState = false
    @State private var cometModels: [CometModel] = []
    @State private var selectedCometModelId = ""
    @State private var cometError: String?
    @State private var replayingWithComet = false
    @State private var cometReplayResult: ReplayResult?
    @State private var showingCometDiff = false

    private let runCount = 3

    var body: some View {
        VStack(spacing: 12) {
            if editing {
                Button {
                    saveDraft()
                } label: {
                    Text(saving ? "Saving replay boundary..." : "Save mocked response and replay")
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(TimeTravelButtonStyle(role: .primary, palette: palette))
                .disabled(saving)

                Button {
                    editing = false
                    saveError = nil
                } label: {
                    Text(saveError ?? "Downstream steps will re-run against this edit - cancel")
                        .font(.system(size: 11))
                        .foregroundStyle(saveError == nil ? palette.textTertiary : palette.pinkText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                ReplayAction(
                    title: "Time-travel - edit response",
                    caption: nil,
                    role: .primary,
                    disabled: false,
                    palette: palette
                ) {
                    draft = responseText
                    editing = true
                    tab = .response
                }

                ReplayAction(
                    title: running ? "Running \(runCount)x..." : "Run \(runCount)x and compare",
                    caption: runError,
                    role: .secondary,
                    disabled: running,
                    captionColor: palette.pinkText,
                    palette: palette,
                    action: runMultiple
                )
            }

            if cometConfigured {
                Divider()
                    .padding(.vertical, 2)
                cometReplaySection
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(palette.panelSecondary.opacity(0.50))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
        .sheet(isPresented: $showingRunResults) {
            NonDeterminismResultsView(runs: runs, palette: palette)
        }
        .sheet(isPresented: $showingCometDiff) {
            if let cometReplayResult {
                ReplayDiffView(original: node, replay: cometReplayResult, palette: palette)
            }
        }
        .task(id: node.id) {
            await loadCometState()
        }
    }

    private var cometReplaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.violet)
                Text("Cross-model replay")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.text)
                Spacer(minLength: 0)
                if loadingCometState || replayingWithComet {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Picker("", selection: $selectedCometModelId) {
                ForEach(groupedCometModels, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.models) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                }
            }
            .labelsHidden()
            .disabled(cometModels.isEmpty || replayingWithComet)

            ReplayAction(
                title: selectedCometModelId.isEmpty ? "Replay with CometAPI" : "Replay with \(selectedCometModelId)",
                caption: cometError,
                role: .secondary,
                disabled: selectedCometModelId.isEmpty || replayingWithComet,
                captionColor: palette.pinkText,
                palette: palette,
                action: replayWithComet
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var groupedCometModels: [CometModelGroup] {
        let groups = [
            CometModelGroup(title: "GPT", models: cometModels.filter { $0.id.localizedCaseInsensitiveContains("gpt") || $0.provider == "openai" }),
            CometModelGroup(title: "Claude", models: cometModels.filter { $0.id.localizedCaseInsensitiveContains("claude") || $0.provider == "anthropic" }),
            CometModelGroup(title: "Gemini", models: cometModels.filter { $0.id.localizedCaseInsensitiveContains("gemini") || $0.provider == "google" })
        ]
        let groupedIds = Set(groups.flatMap { $0.models }.map(\.id))
        let other = CometModelGroup(title: "Other", models: cometModels.filter { !groupedIds.contains($0.id) })
        return (groups + [other]).filter { !$0.models.isEmpty }
    }

    private func loadCometState() async {
        guard !loadingCometState else { return }

        await MainActor.run {
            loadingCometState = true
            cometError = nil
        }
        do {
            let client = CometAPIClient()
            let status = try await client.cometAPIKeyStatus()
            guard status.configured else {
                await MainActor.run {
                    cometConfigured = false
                    cometModels = []
                    selectedCometModelId = ""
                    loadingCometState = false
                }
                return
            }
            let models = try await client.fetchModels()
            await MainActor.run {
                cometConfigured = true
                cometModels = Array(models.prefix(50))
                if selectedCometModelId.isEmpty || !cometModels.contains(where: { $0.id == selectedCometModelId }) {
                    selectedCometModelId = cometModels.first?.id ?? ""
                }
                loadingCometState = false
            }
        } catch {
            await MainActor.run {
                cometError = error.localizedDescription
                cometConfigured = cometConfigured || KeychainStore.hasValue(.cometAPIKey)
                loadingCometState = false
            }
        }
    }

    private func runMultiple() {
        guard !running else { return }

        running = true
        runError = nil
        Task {
            do {
                let results = try await onRunMultiple.perform(node, runCount)
                await MainActor.run {
                    runs = results
                    running = false
                    showingRunResults = true
                }
            } catch {
                await MainActor.run {
                    runError = error.localizedDescription
                    running = false
                }
            }
        }
    }

    private func replayWithComet() {
        guard !replayingWithComet, !selectedCometModelId.isEmpty else { return }

        replayingWithComet = true
        cometError = nil
        Task {
            do {
                let result = try await onReplayWithModel.perform(node, selectedCometModelId)
                await MainActor.run {
                    cometReplayResult = result
                    replayingWithComet = false
                    showingCometDiff = true
                }
            } catch {
                await MainActor.run {
                    cometError = error.localizedDescription
                    replayingWithComet = false
                }
            }
        }
    }

    private func saveDraft() {
        guard !saving else { return }

        saving = true
        saveError = nil
        Task {
            do {
                let impact = try await onSaveMockResponse.perform(node, draft)
                await MainActor.run {
                    responseEdits[node.id] = draft
                    replayImpacts[node.id] = impact
                    editing = false
                    tab = .context
                    saving = false
                }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    saving = false
                }
            }
        }
    }
}

private struct CometModelGroup {
    let title: String
    let models: [CometModel]
}

private struct ReplayAction: View {
    let title: String
    let caption: String?
    let role: TimeTravelButtonRole
    let disabled: Bool
    var captionColor: Color? = nil
    let palette: AgentTracePalette
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Text(title)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(TimeTravelButtonStyle(role: role, palette: palette))
            .disabled(disabled)

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(captionColor ?? Color(hex: 0x888888))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
