import AppKit
import SwiftUI
import UI

struct ContentView: View {
    @StateObject private var preferences = AppPreferences.shared
    @StateObject private var updateChecker = UpdateChecker()

    var body: some View {
        VStack(spacing: 0) {
            UpdateBannerView(checker: updateChecker)
            MainThreePaneLayoutView()
                .frame(minWidth: 800, minHeight: 520)
        }
        .background(WindowSizeConfigurator())
        .environmentObject(preferences)
        .preferredColorScheme(preferences.appearance.preferredColorScheme)
        .animation(.smooth(duration: 0.2), value: updateChecker.updateAvailable)
        .transition(.opacity)
        .task {
            await updateChecker.check()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

private struct WindowSizeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        DispatchQueue.main.async {
            configure(window: view.window)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }

        let minimumSize = CGSize(width: 800, height: 520)
        window.minSize = minimumSize
        window.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        if window.frame.width < minimumSize.width || window.frame.height < minimumSize.height {
            window.setContentSize(CGSize(
                width: max(window.frame.width, minimumSize.width),
                height: max(window.frame.height, minimumSize.height)
            ))
        }
    }
}
