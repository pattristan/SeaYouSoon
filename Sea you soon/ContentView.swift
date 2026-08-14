//
//  ContentView.swift
//  Sea you soon
//
//  Router: first launch (or no crew set up) shows onboarding; otherwise the
//  main "where are they today" screen.
//

import SwiftUI

struct ContentView: View {
    @Environment(CrewSetup.self) var crewSetup

    var body: some View {
        // A scanned QR (pendingRedeemCode) always leads to onboarding with the
        // code prefilled — even when already following someone, so a new code
        // can re-pair. Existing setup is only replaced once redemption succeeds.
        if crewSetup.isConfigured && crewSetup.pendingRedeemCode == nil {
            TodayView()
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
        .environment(FleetData())
        .environment(CrewSetup())
        .environment(WeatherService())
        .environment(WikipediaImageLoader())
}
