import SwiftUI
import UIKit

/// Colors and type for the whole app: black, with the icon's neon pink, cyan and yellow.
enum Theme {
    static let background = Color.black
    static let panel = Color(red: 0.075, green: 0.067, blue: 0.11)
    static let panelHigh = Color(red: 0.13, green: 0.115, blue: 0.18)
    static let stroke = Color.white.opacity(0.08)
    static let pink = Color(red: 1.0, green: 0.18, blue: 0.58)
    static let cyan = Color(red: 0.17, green: 0.91, blue: 1.0)
    static let yellow = Color(red: 1.0, green: 0.88, blue: 0.23)
    static let text = Color(red: 0.96, green: 0.94, blue: 0.91)
    static let dim = Color(red: 0.96, green: 0.94, blue: 0.91).opacity(0.55)

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

/// The app name as a neon sign: "I WANT MY" over "MTV REWIND".
struct Wordmark: View {
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 8) {
            Text("I WANT MY")
                .font(Theme.display(size * 0.62))
                .foregroundStyle(Theme.text)
            Text("MTV")
                .font(Theme.display(size))
                .foregroundStyle(Theme.pink)
                .shadow(color: Theme.pink.opacity(0.8), radius: 8)
            Text("REWIND")
                .font(Theme.display(size * 0.62))
                .foregroundStyle(Theme.cyan)
                .shadow(color: Theme.cyan.opacity(0.7), radius: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("I Want My MTV")
    }
}
