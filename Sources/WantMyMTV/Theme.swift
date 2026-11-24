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

/// The VHS "REWIND" title colors: lavender letters with a dark brown 3D extrusion.
extension Theme {
    static let titleFace = Color(hex: 0xA99CDA)
    static let titleExtrude = Color(hex: 0x3A2A22)

    /// Heavy, condensed, slightly slanted capitals, like the old VHS title.
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.condensed).italic()
    }
}

/// Lavender lettering with a stepped brown extrusion down and to the right, and a
/// thin dark outline. Lettering only, not a logo.
struct VHSTitle: ViewModifier {
    var depth: Int = 4

    func body(content: Content) -> some View {
        ZStack {
            ForEach((1...max(depth, 1)).reversed(), id: \.self) { step in
                content
                    .foregroundStyle(step == depth ? Theme.ink : Theme.titleExtrude)
                    .offset(x: CGFloat(step), y: CGFloat(step))
            }
            content
                .foregroundStyle(Theme.titleFace)
                .shadow(color: Theme.ink, radius: 0, x: 0.8, y: 0.8)
                .shadow(color: Theme.ink, radius: 0, x: -0.8, y: -0.8)
                .shadow(color: Theme.ink, radius: 0, x: 0.8, y: -0.8)
                .shadow(color: Theme.ink, radius: 0, x: -0.8, y: 0.8)
        }
    }
}

extension View {
    func vhsTitle(depth: Int = 4) -> some View {
        modifier(VHSTitle(depth: depth))
    }
}

/// The app name in the VHS title style: "MTV" over "REWIND".
struct Wordmark: View {
    var size: CGFloat = 22
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: -size * 0.12) {
            Text("MTV")
                .font(Theme.title(size * 0.8))
                .tracking(2)
                .vhsTitle(depth: max(2, Int(size / 10)))
            Text("REWIND")
                .font(Theme.title(size * 1.15))
                .tracking(1.5)
                .vhsTitle(depth: max(3, Int(size / 6)))
        }
        .padding(.trailing, size / 5)
        .padding(.bottom, size / 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("MTV Rewind")
    }
}
