//
//  WebcamView.swift
//  Sea you soon
//
//  Live bug-cam of the ship. Defaults to the followed crew member's ship, with
//  a menu to peek at any other ship in the fleet (useful for guests, too).
//

import SwiftUI
import WebKit

struct WebcamView: View {
    @Environment(CrewSetup.self) var crewSetup
    @State private var selectedShip: AidaShip = .aidasol

    var body: some View {
        Group {
            if let url = selectedShip.webcamURL {
                if #available(iOS 26.0, *) {
                    WebView(url: url)
                        .id(selectedShip)
                } else {
                    fallback(url: url)
                }
            } else {
                Text("Unable to load ship webcam.")
            }
        }
        .navigationTitle("\(selectedShip.rawValue) Bug-cam")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(AidaShip.allCases) { ship in
                        Button {
                            selectedShip = ship
                        } label: {
                            if ship == selectedShip {
                                Label(ship.rawValue, systemImage: "checkmark")
                            } else {
                                Text(ship.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            if let ship = AidaShip(rawValue: crewSetup.shipName) {
                selectedShip = ship
            }
        }
    }

    @ViewBuilder
    private func fallback(url: URL) -> some View {
        ZStack {
            OceanBackground()
            GlassEffectContainer(spacing: 20) {
                VStack(spacing: 16) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.oceanInk)
                        .frame(width: 90, height: 90)
                        .glassEffect(.regular, in: .circle)
                    Text("Live view needs a newer iOS version.")
                        .foregroundStyle(Color.oceanInk)
                        .multilineTextAlignment(.center)
                    Link("Open \(selectedShip.rawValue) webcam in Safari", destination: url)
                        .buttonStyle(.glassProminent)
                        .tint(.teal)
                }
                .padding()
            }
        }
    }
}

#Preview {
    NavigationStack {
        WebcamView().environment(CrewSetup())
    }
}
