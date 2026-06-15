import Core
import SwiftUI

/// Shared color and radius tokens for the Tether desktop trace interface.
public struct AgentTracePalette {
    /// Whether the palette should render in the light theme variant.
    public let light: Bool

    /// Creates a palette for the current trace surface theme.
    public init(light: Bool) {
        self.light = light
    }

    public var stage: Color { Color.white }
    public var stageGlowOne: Color { Color(hex: 0xfafafa) }
    public var stageGlowTwo: Color { Color(hex: 0xf4f4f5) }
    public var gridLine: Color { Color(hex: 0xf0f0f0) }

    public var paperRadius: CGFloat { 28 }
    public var panelRadius: CGFloat { 18 }
    public var controlRadius: CGFloat { panelRadius }

    public var window: Color { Color.white }
    public var panel: Color { Color(hex: 0xfafafa) }
    public var panelSecondary: Color { Color(hex: 0xf4f4f5) }
    public var elevated: Color { Color.white }
    public var active: Color { Color(hex: 0xe4e4e7) }
    public var border: Color { Color(hex: 0xe4e4e7) }
    public var borderSoft: Color { Color(hex: 0xeeeeef) }
    public var borderStrong: Color { Color(hex: 0xd4d4d8) }

    public var titleTop: Color { Color.white.opacity(0.88) }
    public var titleBottom: Color { Color(hex: 0xf8fafc).opacity(0.76) }
    public var paperTop: Color { Color(hex: 0xfafafa).opacity(0.94) }
    public var paperBottom: Color { Color(hex: 0xf4f4f5).opacity(0.86) }
    public var nodeTop: Color { Color.white }
    public var nodeBottom: Color { Color(hex: 0xfafafa) }
    public var gridDot: Color { Color.black.opacity(0.055) }
    public var glassTint: Color { Color.white.opacity(0.74) }
    public var glassTintStrong: Color { Color.white.opacity(0.88) }
    public var glassStroke: Color { Color.white.opacity(0.90) }
    public var glassStrokeSoft: Color { Color.black.opacity(0.08) }
    public var glassHighlight: Color { Color.white.opacity(0.96) }
    public var liquidShade: Color { Color(hex: 0x0f172a).opacity(0.10) }

    public var text: Color { Color(hex: 0x18181b) }
    public var textSecondary: Color { Color(hex: 0x3f3f46) }
    public var textTertiary: Color { Color(hex: 0x71717a) }
    public var textQuaternary: Color { Color(hex: 0xa1a1aa) }

    public var green: Color { Color(hex: 0x10b981) }
    public var greenDim: Color { Color(hex: 0xa7f3d0) }
    public var greenBackground: Color { green.opacity(0.10) }
    public var cyan: Color { Color(hex: 0x0284c7) }
    public var cyanDim: Color { Color(hex: 0xbae6fd) }
    public var cyanBackground: Color { cyan.opacity(0.10) }
    public var pink: Color { Color(hex: 0xdb2777) }
    public var pinkDim: Color { Color(hex: 0xfbcfe8) }
    public var pinkBackground: Color { pink.opacity(0.10) }
    public var pinkText: Color { Color(hex: 0xbe185d) }
    public var violet: Color { Color(hex: 0x7c3aed) }
    public var violetBorder: Color { Color(hex: 0xddd6fe) }
    public var amber: Color { Color(hex: 0xd97706) }
    public var accent: Color { Color(hex: 0x4f46e5) }
    public var accentTwo: Color { Color(hex: 0x9333ea) }
    public var accentThree: Color { Color(hex: 0xec4899) }
    public var accentBackground: Color { accent.opacity(0.10) }

    /// Returns the primary accent color for a node status.
    public func color(for status: NodeStatus) -> Color {
        switch status {
        case .success:
            return green
        case .cached:
            return cyan
        case .running:
            return amber
        case .error:
            return pink
        }
    }

    /// Returns a softer status color used for fills and gradients.
    public func dimColor(for status: NodeStatus) -> Color {
        switch status {
        case .success:
            return greenDim
        case .cached:
            return cyanDim
        case .running:
            return amber.opacity(0.36)
        case .error:
            return pinkDim
        }
    }

    /// Returns the status background color used by compact badges.
    public func background(for status: NodeStatus) -> Color {
        switch status {
        case .success:
            return greenBackground
        case .cached:
            return cyanBackground
        case .running:
            return amber.opacity(0.10)
        case .error:
            return pinkBackground
        }
    }
}
