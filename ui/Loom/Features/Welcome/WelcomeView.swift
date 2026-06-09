import Networking
import SwiftUI

struct WelcomeView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    @State private var hasAppeared = false
    @State private var contentOpacity: Double = 1

    var body: some View {
        VStack(spacing: 32) {
            WelcomeBranding()
                .welcomeReveal(hasAppeared, delay: 0)

            HStack(spacing: 16) {
                WelcomeFeatureCard(
                    systemImage: "terminal",
                    title: "Terminal-native",
                    description: "Point Claude Code or Codex to 127.0.0.1:8080 - no code changes needed"
                )
                .welcomeReveal(hasAppeared, delay: 0.15)

                WelcomeFeatureCard(
                    systemImage: "list.bullet.rectangle",
                    title: "Every call captured",
                    description: "Prompt, response, latency, model and cache status - all saved locally"
                )
                .welcomeReveal(hasAppeared, delay: 0.30)

                WelcomeFeatureCard(
                    systemImage: "eye",
                    title: "Visual call tree",
                    description: "See agent execution as a linked trace graph in real time"
                )
                .welcomeReveal(hasAppeared, delay: 0.45)
            }

            WelcomeFooter(launchAction: launchProxyServer)
                .welcomeReveal(hasAppeared, delay: 0.60)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 34)
        .frame(width: 720, height: 540)
        .background(.windowBackground)
        .tint(.teal)
        .opacity(contentOpacity)
        .animation(.easeIn(duration: 0.3), value: contentOpacity)
        .onAppear {
            hasAppeared = true
        }
    }

    private func launchProxyServer() {
        _ = LocalProxyLauncher.shared.startIfAvailable()

        withAnimation(.easeIn(duration: 0.3)) {
            contentOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            hasSeenWelcome = true
        }
    }
}

private struct WelcomeBranding: View {
    var body: some View {
        VStack(spacing: 0) {
            Image("BrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 18, y: 10)

            Text("AgentTrace")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.top, 12)

            Text("Local LLM proxy for AI agents")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
    }
}

private struct WelcomeFeatureCard: View {
    let systemImage: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.teal)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Text(description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160, alignment: .top)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct WelcomeFooter: View {
    let launchAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Tested with Claude Code and Codex · 100% local · Your keys never leave this Mac")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Button("Launch Proxy Server", action: launchAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(width: 260)
                .padding(.top, 16)

            Text("You can change the port anytime in Settings")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WelcomeRevealModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(delay), value: isVisible)
    }
}

private extension View {
    func welcomeReveal(_ isVisible: Bool, delay: Double) -> some View {
        modifier(WelcomeRevealModifier(isVisible: isVisible, delay: delay))
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .preferredColorScheme(.dark)
    }
}
