//
//  GlassModifiers.swift
//  Sea you soon
//

import SwiftUI

extension Color {
    /// The app's ink colour — Patrick's dark blue (RGB 0, 0, 94) in light
    /// mode, white in dark mode (where OceanBackground turns deep-sea dark).
    static let oceanInk = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .white
            : UIColor(red: 0, green: 0, blue: 94.0 / 255.0, alpha: 1)
    })
}

extension Font {
    /// New York — Apple's serif companion to San Francisco, the "NY" the app
    /// always intended. Provided by the system via the serif design; Apple's
    /// font license forbids bundling the file, and there's no need to.
    static func newYork(size: CGFloat) -> Font {
        .system(size: size, design: .serif)
    }

    /// Headings, names, times and data labels: San Francisco (system sans).
    /// The editorial split: data informs in sans, the app narrates in serif.
    static func heading(size: CGFloat) -> Font {
        .system(size: size)
    }
}

struct AnimatedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

extension View {
    @ViewBuilder
    func glassButton() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass(.clear))
        } else {
            self
        }
    }

    func animatedButton() -> some View {
        self.buttonStyle(AnimatedButtonStyle())
    }

    @ViewBuilder
    func liquidGlass(in shape: some Shape = .rect(cornerRadius: 10)) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.clear, in: shape)
        } else {
            self
        }
    }
}
