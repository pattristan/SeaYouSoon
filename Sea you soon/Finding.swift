//
//  Finding.swift
//  Sea you soon
//
//  One day in a ship's itinerary. Mirrors the record shape of the fleet feed
//  (Fleet_en.json), generalised from the original "Finding Patrick" model.
//

import CoreLocation
import Foundation
import SwiftUI

struct Finding: Hashable, Codable, Identifiable {
    var id: Int

    var OnThisDay: String       // "dd.MM.yyyy" — used as the day key
    var location: String
    var fromTill: String
    var description: String

    var cruise: String
    var ship: String?
    var imageName: String
    var image: Image { Image(imageName) }

    var coordinates: Coordinates
    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude)
    }

    // Crew-mode extras (optional in the feed; absent in older feeds).
    var pier: String?
    var berthing: String?      // "Docked" | "Anchored" | "On Engines" | "Seawalk"
    var timeChange: Double?    // clocks shift this many hours (can be ±0.5 etc.)

    /// Tender situation: passengers ferried ashore by boat — crew shore leave
    /// starts late. "Anchored" and station-keeping "On Engines" both qualify.
    var isTender: Bool {
        berthing == "Anchored" || berthing == "On Engines"
    }

    /// True on sea days. The feed uses the English sentinel "At Sea".
    var isAtSea: Bool { location == Finding.seaLabel }

    static let seaLabel = "At Sea"

    struct Coordinates: Hashable, Codable {
        var latitude: Double
        var longitude: Double
    }
}
