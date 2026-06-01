import SwiftUI

struct AgentTracePalette {
    let light: Bool

    var stage: Color { light ? Color(hex: 0xe7e9ee) : Color(hex: 0x08080a) }
    var stageGlowOne: Color { light ? Color(hex: 0xeef1f6) : Color(hex: 0x1a1a1f) }
    var stageGlowTwo: Color { light ? Color(hex: 0xeaeef4) : Color(hex: 0x14171c) }

    var window: Color { light ? Color.white : Color(hex: 0x0d0d0d) }
    var panel: Color { light ? Color(hex: 0xf4f4f6) : Color(hex: 0x161616) }
    var panelSecondary: Color { light ? Color(hex: 0xfafafc) : Color(hex: 0x121212) }
    var elevated: Color { light ? Color.white : Color(hex: 0x1c1c1e) }
    var active: Color { light ? Color(hex: 0xe3e3e8) : Color(hex: 0x26262a) }
    var border: Color { light ? Color(hex: 0xe2e2e6) : Color(hex: 0x2d2d2d) }
    var borderSoft: Color { light ? Color(hex: 0xededf0) : Color(hex: 0x232325) }
    var borderStrong: Color { light ? Color(hex: 0xcfcfd6) : Color(hex: 0x3a3a3d) }

    var titleTop: Color { light ? Color(hex: 0xfbfbfd) : Color(hex: 0x1b1b1d) }
    var titleBottom: Color { light ? Color(hex: 0xf3f3f5) : Color(hex: 0x161618) }
    var nodeTop: Color { light ? Color.white : Color(hex: 0x1a1a1c) }
    var nodeBottom: Color { light ? Color(hex: 0xfbfbfd) : Color(hex: 0x161618) }
    var gridDot: Color { light ? Color.black.opacity(0.05) : Color.white.opacity(0.028) }
    var glassTint: Color { light ? Color.white.opacity(0.34) : Color.white.opacity(0.10) }
    var glassTintStrong: Color { light ? Color.white.opacity(0.54) : Color.white.opacity(0.18) }
    var glassStroke: Color { light ? Color.white.opacity(0.74) : Color.white.opacity(0.16) }
    var glassStrokeSoft: Color { light ? Color.black.opacity(0.08) : Color.white.opacity(0.08) }
    var glassHighlight: Color { light ? Color.white.opacity(0.86) : Color.white.opacity(0.28) }
    var liquidShade: Color { light ? Color.black.opacity(0.07) : Color.black.opacity(0.34) }

    var text: Color { light ? Color(hex: 0x1a1a1c) : Color(hex: 0xededef) }
    var textSecondary: Color { light ? Color(hex: 0x46464b) : Color(hex: 0xb4b4b8) }
    var textTertiary: Color { light ? Color(hex: 0x76767c) : Color(hex: 0x7d7d83) }
    var textQuaternary: Color { light ? Color(hex: 0xa2a2a9) : Color(hex: 0x5a5a60) }

    var green: Color { light ? Color(hex: 0x14935b) : Color(hex: 0x74e0a8) }
    var greenDim: Color { light ? Color(hex: 0xb7e6cd) : Color(hex: 0x2c4a3c) }
    var greenBackground: Color { green.opacity(0.10) }
    var cyan: Color { light ? Color(hex: 0x0e8aa6) : Color(hex: 0x74cfe0) }
    var cyanDim: Color { light ? Color(hex: 0xb3e2ee) : Color(hex: 0x2c4248) }
    var cyanBackground: Color { cyan.opacity(0.10) }
    var pink: Color { light ? Color(hex: 0xd83a63) : Color(hex: 0xff8aa4) }
    var pinkDim: Color { light ? Color(hex: 0xf4c2d0) : Color(hex: 0x4a2c34) }
    var pinkBackground: Color { pink.opacity(light ? 0.09 : 0.10) }
    var pinkText: Color { light ? Color(hex: 0xc2336a) : Color(hex: 0xffb3c2) }
    var violet: Color { light ? Color(hex: 0x6b4bd6) : Color(hex: 0xb39cf5) }
    var violetBorder: Color { light ? Color(hex: 0xd7cef5) : Color(hex: 0x34304a) }
    var amber: Color { light ? Color(hex: 0xb67d12) : Color(hex: 0xf5cd7a) }
    var accent: Color { light ? Color(hex: 0x2f7df0) : Color(hex: 0x5aa0ff) }
    var accentBackground: Color { accent.opacity(light ? 0.13 : 0.14) }

    func color(for status: NodeStatus) -> Color {
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

    func dimColor(for status: NodeStatus) -> Color {
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

    func background(for status: NodeStatus) -> Color {
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

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let palette: AgentTracePalette
    let shape: S
    let tint: Color?
    let interactive: Bool
    let strokeOpacity: Double

    func body(content: Content) -> some View {
        content
            .background((tint ?? palette.glassTint), in: shape)
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                palette.glassHighlight.opacity(strokeOpacity),
                                palette.glassStroke.opacity(strokeOpacity * 0.72),
                                palette.glassStrokeSoft.opacity(strokeOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .topLeading) {
                shape
                    .stroke(palette.glassHighlight.opacity(strokeOpacity * 0.32), lineWidth: 0.6)
                    .blur(radius: 0.2)
                    .padding(1)
            }
            .shadow(color: palette.liquidShade.opacity(0.55), radius: 6, x: 0, y: 4)
    }
}

extension View {
    func liquidGlass<S: Shape>(
        palette: AgentTracePalette,
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false,
        strokeOpacity: Double = 1
    ) -> some View {
        modifier(
            LiquidGlassModifier(
                palette: palette,
                shape: shape,
                tint: tint,
                interactive: interactive,
                strokeOpacity: strokeOpacity
            )
        )
    }

    func liquidGlass(
        palette: AgentTracePalette,
        cornerRadius: CGFloat,
        tint: Color? = nil,
        interactive: Bool = false,
        strokeOpacity: Double = 1
    ) -> some View {
        liquidGlass(
            palette: palette,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            tint: tint,
            interactive: interactive,
            strokeOpacity: strokeOpacity
        )
    }
}
