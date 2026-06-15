import Foundation

/// Inspector section selected by the user.
public enum InspectorTab: String, CaseIterable, Identifiable, Sendable {
    case prompt
    case response
    case metadata

    /// Stable identifier used by SwiftUI lists and pickers.
    public var id: String { rawValue }

    /// User-facing tab title.
    public var title: String {
        switch self {
        case .prompt:
            return "Prompt"
        case .response:
            return "Response"
        case .metadata:
            return "Metadata"
        }
    }
}
