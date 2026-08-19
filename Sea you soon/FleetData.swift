//
//  FleetData.swift
//  Sea you soon
//
//  The fleet feed (Fleet_en.json — all 11 ships), filtered to the followed
//  ship + contract window. Three-tier loading keeps the data fresh without
//  App Store releases:
//    1. bundled feed  — first run, always works offline
//    2. cached feed   — the last successfully downloaded update
//    3. remote feed   — fetched in the background from the webspace; Patrick
//       FTPs a new Fleet_en.json after each MXP re-import and every installed
//       app picks it up on next launch.
//

import Foundation

@Observable
class FleetData {
    /// The full fleet feed, every ship.
    private var allFindings: [Finding] = []

    /// The followed crew member's itinerary (their ship, within the contract dates).
    var findings: [Finding] = []

    /// "date|port" → ships calling there that day. Powers sister-ship encounters.
    private var portIndex: [String: [String]] = [:]

    /// Where updated feeds are published (same webspace pattern as the
    /// original Finding Patrick app).
    private static let remoteURL = "https://www.oconnell-connect.de/Fleet_en.json"

    private static var cacheFile: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FleetCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("Fleet_en.json")
    }

    init() {
        // Prefer the last downloaded feed; fall back to the bundled one.
        if let data = try? Data(contentsOf: Self.cacheFile),
           let cached = try? JSONDecoder().decode([Finding].self, from: data),
           !cached.isEmpty {
            adopt(cached)
        } else {
            adopt(Self.loadFromBundle("Fleet_en.json"))
        }
    }

    /// Replace the feed and rebuild derived data.
    private func adopt(_ all: [Finding]) {
        allFindings = all
        var index: [String: [String]] = [:]
        for f in all where f.location != Finding.seaLabel {
            // Shipyard calls (refits, e.g. "Yard (Marseille)") aren't encounters.
            if f.location.localizedCaseInsensitiveContains("yard (") { continue }
            if let ship = f.ship {
                index["\(f.OnThisDay)|\(Self.portCity(f.location))", default: []].append(ship)
            }
        }
        portIndex = index
    }

    /// Fetch the published feed; on success adopt it, cache it, and re-apply
    /// the current setup. Silently keeps the current feed on any failure
    /// (offline, 404 before the first upload, bad decode …).
    func refreshFromRemote(applying setup: CrewSetup) async {
        let stamp = Int(Date.now.timeIntervalSince1970)
        guard let url = URL(string: "\(Self.remoteURL)?v=\(stamp)") else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let fresh = try JSONDecoder().decode([Finding].self, from: data)
            guard !fresh.isEmpty else { return }
            await MainActor.run {
                adopt(fresh)
                if setup.isConfigured { apply(setup) }
            }
            try? data.write(to: Self.cacheFile, options: .atomic)
        } catch {
            // Offline or feed not yet published — the bundled/cached feed stands.
        }
    }

    /// "Hamburg - Steinwerder" and "Hamburg - Altona" are the same city for
    /// meeting purposes — a ship visit across the Elbe still counts.
    private static func portCity(_ location: String) -> String {
        location.components(separatedBy: " - ").first ?? location
    }

    /// Sister ships sharing this port on this day (excluding the stop's own ship).
    /// The photo opportunity for guests — and the ship visit for crew.
    func sisterShips(at stop: Finding) -> [String] {
        guard !stop.isAtSea else { return [] }
        let ships = portIndex["\(stop.OnThisDay)|\(Self.portCity(stop.location))"] ?? []
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
