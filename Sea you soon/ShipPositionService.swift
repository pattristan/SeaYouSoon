//
//  ShipPositionService.swift
//  Sea you soon
//
//  Live fleet positions from AIDA's own website feed (the XML behind the
//  ship-position page). Fetched opportunistically — on launch and when the
//  app returns to the foreground, at most every 10 minutes, never on a
//  timer: we are a guest at this table. The feed sits behind bot protection
//  that admits residential/mobile connections, and aida.de is on the ships'
//  free Social-Media-Package whitelist, so crew get it at sea for free.
//  The static feed's interpolation remains the offline backbone; a fresh
//  live position is the polish on top, never a dependency.
//

import Foundation

struct LivePosition {
    let latitude: Double
    let longitude: Double
    let speed: Double          // knots
    let timestamp: Date
}

@MainActor
@Observable
class ShipPositionService {
    private(set) var positions: [String: LivePosition] = [:]
    private var lastAttempt: Date?

    /// A position we still trust — the feed updates every few minutes, so
    /// anything older than 45 minutes falls back to the itinerary.
    func fresh(for ship: String, maxAge: TimeInterval = 45 * 60) -> LivePosition? {
        guard let p = positions[ship],
              Date.now.timeIntervalSince(p.timestamp) < maxAge else { return nil }
        return p
    }

    func refresh() async {
        if let last = lastAttempt, Date.now.timeIntervalSince(last) < 10 * 60 { return }
        lastAttempt = .now

        var req = URLRequest(url: URL(string: "https://www.aida.de/webcam/shippositions.xml")!)
        req.timeoutInterval = 15
        // The exact browser-shaped header set the feed expects.
        req.setValue("https://aida.de", forHTTPHeaderField: "Origin")
        req.setValue("https://aida.de/", forHTTPHeaderField: "Referer")
        req.setValue("*/*", forHTTPHeaderField: "Accept")
        req.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        req.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        req.setValue("same-site", forHTTPHeaderField: "Sec-Fetch-Site")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.6.1 Safari/605.1.15",
                     forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
        let parsed = Parser.parse(data)
        if !parsed.isEmpty { positions = parsed }
    }

    /// Minimal XML reading: <ship ShipName="AIDAsol"> … <data latitude=… />.
    private final class Parser: NSObject, XMLParserDelegate {
        private var ship: String?
        private var result: [String: LivePosition] = [:]
        private static let iso = ISO8601DateFormatter()

        static func parse(_ data: Data) -> [String: LivePosition] {
            let delegate = Parser()
            let xml = XMLParser(data: data)
            xml.delegate = delegate
            xml.parse()
            return delegate.result
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName: String?,
                    attributes attributeDict: [String: String] = [:]) {
            if elementName == "ship" {
                ship = attributeDict["ShipName"]
            } else if elementName == "data", let ship,
                      let lat = attributeDict["latitude"].flatMap(Double.init),
                      let lon = attributeDict["longitude"].flatMap(Double.init),
                      let stamp = attributeDict["timestamp"].flatMap({ Self.iso.date(from: $0) }) {
                result[ship] = LivePosition(
                    latitude: lat, longitude: lon,
                    speed: attributeDict["speed"].flatMap(Double.init) ?? 0,
                    timestamp: stamp)
            }
        }
    }
}
