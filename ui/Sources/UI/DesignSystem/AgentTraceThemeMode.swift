import SwiftUI

public enum AgentTraceThemeMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    public func isLight(systemColorScheme: ColorScheme) -> Bool {
        switch self {
        case .system:
            return systemColorScheme == .light
        case .light:
            return true
        case .dark:
            return false
        }
    }
}
