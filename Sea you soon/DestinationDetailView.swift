//
//  DestinationDetailView.swift
//  Sea you soon
//
//  Tap a port in the itinerary → map, the Wikipedia photo (via the ported
//  loader with its photo filter) and the Wikipedia summary. The direct
//  descendant of Finding Patrick's FindingDetail.
//

import MapKit
import SwiftUI

struct DestinationDetailView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(WikipediaImageLoader.self) private var imageLoader: WikipediaImageLoader?
    @Environment(FleetData.self) var fleetData
    @Environment(CrewSetup.self) var crewSetup
    @Environment(ShipPositionService.self) var shipPositions

    let finding: Finding

    /// Today's row shows the ship where she ACTUALLY is, when we know it —
    /// live feed position, fresh within 45 minutes. Other days (and stale
    /// data) use the itinerary's route-aware coordinates.
    private var livePosition: LivePosition? {
        let today = DateFormatter()
        today.dateFormat = "dd.MM.yyyy"
        guard finding.OnThisDay == today.string(from: .now),
              let ship = finding.ship else { return nil }
        return shipPositions.fresh(for: ship)
    }

    private var displayCoordinate: CLLocationCoordinate2D {
        livePosition.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            ?? finding.locationCoordinate
    }

    private let ringGray = Color(red: 0.7, green: 0.7, blue: 0.7).opacity(0.3)

    private var circleSize: CGFloat {
        horizontalSizeClass == .regular ? 350 : 250
    }

    private var name: String { crewSetup.subject }

    /// For sea days, describe the leg from adjacent ports.
    private var seaDayDescription: String? {
        guard finding.isAtSea,
              let idx = fleetData.findings.firstIndex(where: { $0.id == finding.id }) else { return nil }
        let prevPort = fleetData.findings[...idx].last(where: { !$0.isAtSea })
        let nextPort = fleetData.findings[idx...].first(where: { !$0.isAtSea })

        if let prev = prevPort, let next = nextPort {
            return "\(name) will be at sea, between \(prev.location) and \(next.location)."
        } else if let next = nextPort {
            return "\(name) will be at sea, heading to \(next.location)."
        } else if let prev = prevPort {
            return "\(name) will be at sea after leaving \(prev.location)."
        }
        return "A day at sea."
    }

    var body: some View {
        ZStack {
            OceanBackground()

            ScrollView {
                VStack(spacing: 0) {
                    MapView(coordinate: displayCoordinate,
                            markerTitle: finding.ship ?? "")
                        .frame(height: horizontalSizeClass == .regular ? 400 : 300)
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        .padding(.horizontal, 16)
                        .overlay(alignment: .topTrailing) {
                            if let live = livePosition {
                                Label("Live · \(live.timestamp.formatted(date: .omitted, time: .shortened))",
                                      systemImage: "dot.radiowaves.left.and.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.oceanInk)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .glassEffect(.regular.tint(.teal.opacity(0.4)), in: .capsule)
                                    .padding(.top, 10).padding(.trailing, 26)
                            }
                        }

                    // Classic circular medallion for ports AND sea days — sea
                    // days use the plain "NP" photo here (the porthole lives on
                    // the Today and Tomorrow tiles instead).
                    LocationImageView(finding: finding, width: circleSize, height: circleSize, showPorthole: false)
                        .clipShape(Circle())
                        .overlay { Circle().stroke(ringGray, lineWidth: 4) }
                        .shadow(radius: 7)
                        .offset(y: -circleSize / 2.2)
                        .padding(.bottom, -circleSize / 2.2)
              

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(finding.OnThisDay)
                                    .font(.caption)
                                    .foregroundStyle(Color.oceanInk.opacity(0.65))
                                Label(finding.fromTill, systemImage: "clock")
                                    .font(.heading(size: 15))
                                    .foregroundStyle(Color.oceanInk)
                            }
                            Spacer()
                            Button {
                                // Open Maps showing the ship's position as a named
                                // pin — not directions from the viewer (who may be
                                // an ocean away). Maps offers directions on demand.
                                let location = CLLocation(latitude: displayCoordinate.latitude,
                                                          longitude: displayCoordinate.longitude)
                                let item = MKMapItem(location: location, address: nil)
                                let place = finding.isAtSea ? "at sea" : finding.location
                                item.name = finding.ship.map { "\($0) — \(place)" } ?? place
                                item.openInMaps()
                            } label: {
                                Label("Maps", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                                    .font(.heading(size: 16))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.glass)
                        }

                        // Wikipedia summary (the loader's photo filter + extract),
                        // with graceful fallbacks for sea days.
                        Text(imageLoader?.extract(for: finding.location)
                             ?? seaDayDescription
                             ?? "Fetching information…")
                            .font(.newYork(size: 15))
                            .foregroundStyle(Color.oceanInk)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))

                        if let articleURL = imageLoader?.articleURL(for: finding.location) {
                            Link(destination: articleURL) {
                                Label("Read more on Wikipedia", systemImage: "book")
                                    .font(.heading(size: 14))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .padding(16)
                }
                .padding(.top, 8)
            }
         
        }
        .navigationTitle(finding.location)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await imageLoader?.fetchInfo(for: finding)
        }
    }
}

#Preview {
    NavigationStack {
        DestinationDetailView(finding: FleetData().findings.first
            ?? Finding(id: 1, OnThisDay: "01.01.2027", location: "Hamburg", fromTill: "08:00 - 18:00",
                       description: "look up", cruise: "1", ship: "AIDAsol", imageName: "Hamburg",
                       coordinates: .init(latitude: 53.55, longitude: 9.99)))
    }
    .environment(FleetData())
    .environment(CrewSetup())
    .environment(WikipediaImageLoader())
    .environment(ShipPositionService())
}
