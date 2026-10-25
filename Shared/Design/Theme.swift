import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// A color that switches with light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

enum Theme {
    static let ground = Color(light: 0xF3F4F1, dark: 0x111413)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C201E)
    static let ink = Color(light: 0x1A1D1B, dark: 0xF1F3F0)
    static let muted = Color(light: 0x5D6560, dark: 0xA3ACA6)
    static let track = Color(light: 0xE4E7E2, dark: 0x2C312E)
    static let hairline = Color(light: 0xECEEEA, dark: 0x262A28)
    /// Primary button fill; text on it uses `onInk`.
    static let inkButton = Color(light: 0x1A1D1B, dark: 0xF1F3F0)
    static let onInk = Color(light: 0xFFFFFF, dark: 0x1A1D1B)
    static let done = Color(light: 0x2E6B63, dark: 0x8FC7BD)

    static let cardRadius: CGFloat = 22
    static let gutter: CGFloat = 20
}

enum RhythmColor: String, CaseIterable, Identifiable, Codable, Sendable {
    case teal, amber, blue, plum, ink

    var id: String { rawValue }

    var name: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .teal: Color(light: 0x2E6B63, dark: 0x6FB3A8)
        case .amber: Color(light: 0xA85A24, dark: 0xE09A66)
        case .blue: Color(light: 0x3B5A8C, dark: 0x8AA6D6)
        case .plum: Color(light: 0x7A4A78, dark: 0xC48FC1)
        case .ink: Color(light: 0x1A1D1B, dark: 0xE4E7E2)
        }
    }

    var tint: Color {
        switch self {
        case .teal: Color(light: 0xE6EFEC, dark: 0x1F3632)
        case .amber: Color(light: 0xF5E9E0, dark: 0x3A2A1E)
        case .blue: Color(light: 0xE8ECF3, dark: 0x222C3D)
        case .plum: Color(light: 0xF1E8F0, dark: 0x352535)
        case .ink: Color(light: 0xE7E8E6, dark: 0x2C312E)
        }
    }
}

/// SF Symbols offered in the icon picker.
enum RhythmSymbols {
    static let all: [String] = [
        "mouth", "heart", "figure.run", "drop", "book",
        "leaf", "phone", "dumbbell", "bed.double", "pills",
        "fork.knife", "sparkles", "pencil", "music.note", "house",
    ]
}

/// Rounded square with the rhythm's symbol on its tint. Used by the app and the widgets.
struct IconTile: View {
    var symbol: String
    var color: RhythmColor
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundStyle(color.color)
            .frame(width: size, height: size)
            .background(color.tint, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

extension Font {
    static func rhythm(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
