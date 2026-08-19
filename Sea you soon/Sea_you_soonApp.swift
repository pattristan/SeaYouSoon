//
//  Sea_you_soonApp.swift
//  Sea you soon
//

import SwiftUI

@main
struct Sea_you_soonApp: App {
    @State private var fleetData = FleetData()
    @State private var crewSetup = CrewSetup()
    @State private var imageLoader = WikipediaImageLoader()
    @State private var weatherService = WeatherService()

    @State private var splashOffset: CGFloat = 0
    @State private var splashDone = Self.hasLaunched
    private static var hasLaunched = false

    var body: some Scene {
        WindowGroup {
            GeometryReader { geo in
                ZStack {
                    ContentView()
                        .environment(fleetData)
                        .environment(crewSetup)
                        .environment(imageLoader)
                        .environment(weatherService)
                        .onAppear { fleetData.apply(crewSetup) }
                        .task {
                            // Pick up a freshly published feed (FTP'd after an
                            // MXP re-import) without an App Store release.
                            await fleetData.refreshFromRemote(applying: crewSetup)
                        }

                    if !splashDone {
                        SplashScreenView()
                            .offset(x: splashOffset)
                            .zIndex(1)
                    }
                }
                .onAppear {
                    guard !splashDone else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeInOut(duration: 1.2)) {
                            splashOffset = geo.size.width
                        } completion: {
                            splashDone = true
                            Self.hasLaunched = true
                        }
                    }
                }
                .onOpenURL { url in
                    // seayousoon://redeem?code=SOL-XXXXX (from the QR landing page)
                    guard url.scheme == "seayousoon", url.host == "redeem",
                          let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                          let code = items.first(where: { $0.name == "code" })?.value,
                          !code.isEmpty else { return }
                    crewSetup.pendingRedeemCode = code.uppercased()
                }
            }
        }
    }
}
