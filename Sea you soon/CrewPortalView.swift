//
//  CrewPortalView.swift
//  Sea you soon
//
//  Crew mode replaces the webcam (crew can look out of the window) with the
//  AIDA crew portal. Two portals matter aboard:
//    • the on-board portal  https://crewportal.<ship>.aida.de — flights home,
//      only reachable on the ship's own network
//    • the fleet portal     https://crewportal.aida.de — next contract,
//      history, evaluations; reachable anywhere
//  The ship subdomain follows the watched ship automatically, so no browser
//  bookmark goes stale when the next contract is a different ship.
//
//  Login (crew ID + password) happens on AIDA's page inside the web view —
//  this app never sees or stores those credentials.
//

import SwiftUI
import WebKit

struct CrewPortalView: View {
    @Environment(CrewSetup.self) var crewSetup

    private enum Portal: String, CaseIterable, Identifiable {
        case ship, fleet, gladis
        var id: String { rawValue }
    }

    @State private var portal: Portal = .ship

    /// "AIDAsol" -> "sol" for the on-board subdomain.
    private var shipSlug: String {
        crewSetup.shipName.replacingOccurrences(of: "AIDA", with: "").lowercased()
    }

    private var url: URL? {
        switch portal {
        case .ship:   return URL(string: "https://crewportal.\(shipSlug).aida.de")
        case .fleet:  return URL(string: "https://crewportal.aida.de")
        // GLADIS — Global Learning And Development Information System:
        // the online training courses (first aid, lifeboat loading, cyber
        // security …), doable aboard or at home before embarkation.
        case .gladis: return URL(string: "https://cmg.marinels.com")
        }
    }

    var body: some View {
        Group {
            if let url {
                if #available(iOS 26.0, *) {
                    WebView(url: url)
                        .id(portal)   // reload when switching portals
                } else {
                    Link("Open crew portal in Safari", destination: url)
                }
            } else {
                Text("Unable to build the portal address.")
            }
        }
        .navigationTitle("Crew Portal")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            Picker("Portal", selection: $portal) {
                Text("on board").tag(Portal.ship)
                Text("at home").tag(Portal.fleet)
                Text("GLADIS").tag(Portal.gladis)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }
}

#Preview {
    NavigationStack {
        CrewPortalView().environment(CrewSetup())
    }
}
