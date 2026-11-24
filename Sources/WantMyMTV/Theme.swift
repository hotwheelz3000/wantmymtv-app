import SwiftUI
import UIKit

extension Color {
    /// A color from a hex number, e.g. `Color(hex: 0x2F5EB0)`.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Colors and type for the whole app: a black background with the site's
/// MTV Rewind palette (royal blue, lilac, mustard, red, salmon, light blue, and the
/// Enter button's pink-to-blue gradient), with chunky dark outlines.
enum Theme {
    static let background = Color.black
    static let royal = Color(hex: 0x2F5EB0)
    static let deep = Color(hex: 0x224C8B)
    static let navy = Color(hex: 0x10254D)
    static let lilac = Color(hex: 0xD1A1D2)
    static let yellow = Color(hex: 0xF4B940)
    static let red = Color(hex: 0xC72E20)
    static let salmon = Color(hex: 0xEE8887)
    static let lightBlue = Color(hex: 0xADC9EB)
    static let pink = Color(hex: 0xE471BF)
    static let purple = Color(hex: 0x7D78D9)
    static let sky = Color(hex: 0x69B0EF)
    static let ink = Color(hex: 0x141420)

    /// The Enter button: pink to purple to sky blue.
    static let enter = LinearGradient(colors: [pink, purple, sky], startPoint: .leading, endPoint: .trailing)

    static let panel = navy
    static let panelHigh = deep
    static let stroke = ink
    static let cyan = sky
    static let text = Color(hex: 0xF6F2EA)
    static let dim = Color(hex: 0xF6F2EA).opacity(0.6)

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func led(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

/// Small physical clicks for remote buttons.
@MainActor
enum Haptics {
    static func click() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
    }

    static func thunk() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func tick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

/// Buttons that sink a little when pressed, like a real remote.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Thin dark lines across the picture, like a CRT.
struct Scanlines: View {
    var spacing: CGFloat = 3
    var opacity: Double = 0.22

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(.black.opacity(opacity))
                )
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

/// Chunky cartoon lettering: a dark outline and a drop shadow, like the site's logo.
struct Outlined: ViewModifier {
    var width: CGFloat = 1.5
    var drop: CGFloat = 2.5

    func body(content: Content) -> some View {
        content
            .shadow(color: Theme.ink, radius: 0, x: width, y: width)
            .shadow(color: Theme.ink, radius: 0, x: -width, y: -width)
            .shadow(color: Theme.ink, radius: 0, x: width, y: -width)
            .shadow(color: Theme.ink, radius: 0, x: -width, y: width)
            .shadow(color: Theme.ink.opacity(0.9), radius: 0, x: drop, y: drop)
    }
}

extension View {
    func outlined(_ width: CGFloat = 1.5, drop: CGFloat = 2.5) -> some View {
        modifier(Outlined(width: width, drop: drop))
    }
}

/// The app name: "I WANT MY" in lilac, "MTV" in mustard and red, "REWIND" in
/// salmon and light blue like the site's logo. Lettering only, not the logo.
struct Wordmark: View {
    var size: CGFloat = 22

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text("I WANT MY")
                .font(Theme.display(size * 0.62))
                .foregroundStyle(Theme.lilac)
                .outlined(1, drop: 1.5)
            (Text("M").foregroundStyle(Theme.yellow) + Text("TV").foregroundStyle(Theme.red))
                .font(Theme.display(size))
                .outlined(1.5, drop: 2.5)
            (Text("RE").foregroundStyle(Theme.salmon) + Text("WIND").foregroundStyle(Theme.lightBlue))
                .font(Theme.display(size * 0.62))
                .outlined(1, drop: 1.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("I Want My MTV")
    }
}
