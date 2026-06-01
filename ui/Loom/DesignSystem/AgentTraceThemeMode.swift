import SwiftUI

enum AgentTraceThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    func isLight(systemColorScheme: ColorScheme) -> Bool {
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
