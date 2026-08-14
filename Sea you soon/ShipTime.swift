//
//  ShipTime.swift
//  Sea you soon
//
//  Shared time helpers: the port's UTC offset (political sub-zones, not just
//  longitude) and the "(… your time)" conversion for viewers far from the port.
//  Used by TodayView and TomorrowView.
//

import Foundation

enum ShipTime {

    /// UTC offset (whole hours) for a position. Europe needs explicit
    /// sub-zones because political time zones ignore longitude — the UK sits
    /// "inside" the CET box yet runs GMT/BST an hour behind.
    static func timezoneOffset(for finding: Finding) -> Int {
        let lon = finding.coordinates.longitude
        let lat = finding.coordinates.latitude
        let month = Calendar.current.component(.month, from: .now)
        let isDST = month >= 3 && month <= 10   // rough European DST window

        // UK & Ireland: GMT/BST. (Channel Islands too — but NOT Cherbourg/
        // Le Havre just across the water, hence the tighter southern band.)
        let britishIsles = lat >= 49.9 && lat <= 61.5 && lon >= -11.0 && lon <= 1.6
        let channelIslands = lat >= 49.1 && lat < 49.9 && lon >= -3.0 && lon <= -1.9
        if britishIsles || channelIslands { return isDST ? 1 : 0 }

        // Portugal mainland: WET/WEST (Spain around it is CET).
        if lat >= 36.9 && lat <= 42.15 && lon >= -10.0 && lon <= -6.2 { return isDST ? 1 : 0 }

        // Canary Islands & Madeira: WET/WEST.
        if lat >= 27.3 && lat <= 33.5 && lon >= -18.5 && lon <= -13.0 { return isDST ? 1 : 0 }

        // Faroe Islands: WET/WEST.
        if lat >= 61.3 && lat <= 62.5 && lon >= -8.0 && lon <= -6.0 { return isDST ? 1 : 0 }

        // Iceland: UTC all year.
        if lat >= 62.5 && lat <= 67.5 && lon >= -25.0 && lon <= -12.0 { return 0 }

        // Rest of European waters: CET/CEST.
        if lat > 30 && lon > -15 && lon < 40 {
            return isDST ? 2 : 1
        }
        // Rest of world: geographic timezone from longitude.
        return Int((lon / 15.0).rounded())
    }

    /// "10:00 - 19:30" in Portland shown to a viewer in Myanmar becomes
    /// "(15:30 – 01:00 +1 your time)". Returns nil when the viewer is (near)
    /// the port's timezone or the times aren't plain HH:mm (e.g. Overnight).
    /// Minute-based so half-hour zones (Myanmar, India) come out exactly.
    static func viewerTimeHint(for finding: Finding) -> String? {
        let portMinutes = timezoneOffset(for: finding) * 60
        let viewerMinutes = TimeZone.current.secondsFromGMT() / 60
        let shift = viewerMinutes - portMinutes
        guard abs(shift) >= 60 else { return nil }   // same-ish zone: say nothing

        let parts = finding.fromTill.components(separatedBy: " - ")
        guard parts.count == 2,
              let start = parseMinutes(parts[0]),
              let end = parseMinutes(parts[1]) else { return nil }

        func shifted(_ minutes: Int) -> (text: String, nextDay: Bool) {
            var m = (minutes + shift) % 1440
            if m < 0 { m += 1440 }
            let crossed = minutes + shift >= 1440
            return (String(format: "%02d:%02d", m / 60, m % 60), crossed)
        }
        let s = shifted(start)
        let e = shifted(end)
        let marker = e.nextDay ? " +1" : ""
        return "(\(s.text) – \(e.text)\(marker) your time)"
    }

    /// "10:00" -> 600. Nil for tokens like "Overnight".
    static func parseMinutes(_ hhmm: String) -> Int? {
        let bits = hhmm.trimmingCharacters(in: .whitespaces).components(separatedBy: ":")
        guard bits.count == 2, let h = Int(bits[0]), let m = Int(bits[1]),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return h * 60 + m
    }
}
