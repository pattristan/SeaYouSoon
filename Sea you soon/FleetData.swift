//
//  FleetData.swift
//  Sea you soon
//
//  Loads the bundled fleet feed (Fleet_en.json — all 11 ships) and exposes the
//  itinerary filtered to the followed crew member's ship + contract window.
//

import Foundation

@Observable
class FleetData {
    /// The full fleet feed, every ship.
    private let allFindings: [Finding]

    /// The followed crew member's itinerary (their ship, within the contract dates).
    var findings: [Finding] = []

    /// "date|port" → ships calling there that day. Powers sister-ship encounters.
    private let portIndex: [String: [String]]

    init() {
        let all: [Finding] = Self.loadFromBundle("Fleet_en.json")
        allFindings = all
        var index: [String: [String]] = [:]
        for f in all where f.location != Finding.seaLabel {
            // Shipyard calls (refits, e.g. "Yard (Marseille)") aren't encounters.
            if f.location.localizedCaseInsensitiveContains("yard (") { continue }
            if let ship = f.ship {
                index["\(f.OnThisDay)|\(f.location)", default: []].append(ship)
            }
        }
        portIndex = index
    }

    /// Sister ships sharing this port on this day (excluding the stop's own ship).
    /// The photo opportunity for guests — and the ship visit for crew.
    func sisterShips(at stop: Finding) -> [String] {
        guard !stop.isAtSea else { return [] }
        let ships = portIndex["\(stop.OnThisDay)|\(stop.location)"] ?? []
        return ships.filter { $0 != stop.ship }.sorted()
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

    /// Recompute `findings` for the given setup: the selected ship, restricted to
    /// the embark…disembark window, sorted by date.
    func apply(_ setup: CrewSetup) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: setup.embarkDate)
        let end = calendar.startOfDay(for: setup.disembarkDate)

        findings = allFindings
            .filter { $0.ship == setup.shipName }
            .filter { finding in
                guard let date = Self.dateFormatter.date(from: finding.OnThisDay) else { return false }
                let day = calendar.startOfDay(for: date)
                return day >= start && day <= end
            }
            .sorted { a, b in
                let da = Self.dateFormatter.date(from: a.OnThisDay) ?? .distantPast
                let db = Self.dateFormatter.date(from: b.OnThisDay) ?? .distantPast
                return da < db
            }
    }

    static func date(from onThisDay: String) -> Date? {
        dateFormatter.date(from: onThisDay)
    }

    static func loadFromBundle<T: Decodable>(_ filename: String) -> T {
        guard let file = Bundle.main.url(forResource: filename, withExtension: nil) else {
            fatalError("Couldn't find \(filename) in main bundle.")
        }
        do {
            let data = try Data(contentsOf: file)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("Couldn't load/parse \(filename): \(error)")
        }
    }
}
