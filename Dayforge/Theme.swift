import SwiftUI

/// Dayforge design system: warm off-white paper, deep charcoal ink and four muted accents.
/// Brand colour sets the user can switch between. Each keeps the same dusty, earthy saturation so any
/// preset sits with the quiet blue and yellow supporting tints.
enum ThemePreset: String, CaseIterable, Codable, Identifiable {
    case moss, terracotta, ocean, dusk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moss: return "Moss"
        case .terracotta: return "Terracotta"
        case .ocean: return "Ocean"
        case .dusk: return "Dusk"
        }
    }

    /// The main colour: buttons, selected states, the Pulse card.
    var brand: Color {
        switch self {
        case .moss: return Color(red: 0.404, green: 0.490, blue: 0.357)
        case .terracotta: return Color(red: 0.722, green: 0.420, blue: 0.314)
        case .ocean: return Color(red: 0.388, green: 0.510, blue: 0.616)
        case .dusk: return Color(red: 0.478, green: 0.431, blue: 0.557)
        }
    }

    /// The single warm highlight (badges, resume buttons).
    var highlight: Color {
        switch self {
        case .moss, .dusk: return Color(red: 0.722, green: 0.420, blue: 0.314)
        case .terracotta: return Color(red: 0.404, green: 0.490, blue: 0.357)
        case .ocean: return Color(red: 0.824, green: 0.671, blue: 0.318)
        }
    }

    /// Dark end of the brand gradients.
    var deep: Color {
        switch self {
        case .moss: return Color(red: 0.231, green: 0.286, blue: 0.247)
        case .terracotta: return Color(red: 0.302, green: 0.204, blue: 0.165)
        case .ocean: return Color(red: 0.204, green: 0.271, blue: 0.333)
        case .dusk: return Color(red: 0.271, green: 0.243, blue: 0.325)
        }
    }
}

enum Theme {
    /// Set from the profile; the app rebuilds its views when it changes.
    static var preset: ThemePreset = .moss

    static let background = Color(red: 0.965, green: 0.949, blue: 0.918)
    static let card = Color(red: 0.992, green: 0.984, blue: 0.965)
    static let ink = Color(red: 0.141, green: 0.149, blue: 0.169)
    static let inkSoft = Color(red: 0.141, green: 0.149, blue: 0.169).opacity(0.62)
    // Palette rule: moss is the brand colour, clay is the single warm highlight, blue and yellow are quiet
    // supporting tints. All four share one dusty, earthy saturation so any pair sits together.
    static var moss: Color { preset.brand }
    static var clay: Color { preset.highlight }
    static let blue = Color(red: 0.388, green: 0.510, blue: 0.616)
    static let yellow = Color(red: 0.824, green: 0.671, blue: 0.318)
    /// Deep moss, used as the dark end of gradients so cards stay in the same family.
    static var deep: Color { preset.deep }
    /// Warm brown for shadows and hairlines instead of pure black.
    static let shadow = Color(red: 0.239, green: 0.169, blue: 0.098)
    static let hairline = Color(red: 0.239, green: 0.169, blue: 0.098).opacity(0.10)

    static func title(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func number(_ size: CGFloat = 34) -> Font { .system(size: size, weight: .bold, design: .rounded).monospacedDigit() }
}

enum Accent: String, CaseIterable, Hashable, Codable {
    case moss, clay, blue, yellow

    var color: Color {
        switch self {
        case .moss: return Theme.moss
        case .clay: return Theme.clay
        case .blue: return Theme.blue
        case .yellow: return Theme.yellow
        }
    }

    var soft: Color { color.opacity(0.16) }
}

extension Color {
    /// 0xRRGGBB convenience used by the local manga artwork.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

struct DayCardStyle: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .shadow(color: Theme.shadow.opacity(0.07), radius: 14, x: 0, y: 7)
    }
}

extension View {
    func dayCard(padding: CGFloat = 18) -> some View {
        modifier(DayCardStyle(padding: padding))
    }
}

struct FilledButtonStyle: ButtonStyle {
    var tint: Color = Theme.ink
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(foreground)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(tint, in: Capsule())
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var tint: Color = Theme.moss

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(tint.opacity(0.14), in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
