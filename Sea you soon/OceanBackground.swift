//
//  OceanBackground.swift
//  Sea you soon
//
//  The shared ocean backdrop the Liquid Glass tiles refract: a pale sea-sky
//  gradient with two softly drifting colour spots. Light, so the app's
//  dark-blue ink text (Color.oceanInk) reads everywhere. Self-animating.
//

import SwiftUI

struct OceanBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var drift = false

    /// Light mode: pale sea-sky (navy ink on top).
    /// Dark mode: deep-sea night (white ink on top).
    private var gradientColors: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.02, green: 0.16, blue: 0.36),
               Color(red: 0.00, green: 0.42, blue: 0.60),
               Color(red: 0.10, green: 0.60, blue: 0.62)]
            // Pale sea-sky, nudged 10% toward the deep-sea gradient.
            : [Color(red: 0.79, green: 0.87, blue: 0.93),
               Color(red: 0.63, green: 0.83, blue: 0.91),
               Color(red: 0.53, green: 0.81, blue: 0.83)]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.mint.opacity(colorScheme == .dark ? 0.35 : 0.30))
                .frame(width: 280)
                .blur(radius: 60)
                .offset(x: drift ? -110 : -60, y: drift ? -230 : -160)
            Circle()
                .fill(Color.indigo.opacity(colorScheme == .dark ? 0.40 : 0.18))
                .frame(width: 320)
                .blur(radius: 70)
                .offset(x: drift ? 130 : 80, y: drift ? 250 : 320)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

#Preview {
    OceanBackground()
}
