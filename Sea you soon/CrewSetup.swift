//
//  CrewSetup.swift
//  Sea you soon
//
//  The one seafarer this installation is following: their name, ship and
//  contract window — established by redeeming a crew-issued pairing code.
//  Persisted in UserDefaults.
//

import Foundation

@Observable
class CrewSetup {
    var crewName: String {
        didSet { UserDefaults.standard.set(crewName, forKey: Keys.crewName) }
    }
    var shipName: String {
        didSet { UserDefaults.standard.set(shipName, forKey: Keys.shipName) }
    }
    var embarkDate: Date {
        didSet { UserDefaults.standard.set(embarkDate, forKey: Keys.embarkDate) }
    }
    var disembarkDate: Date {
        didSet { UserDefaults.standard.set(disembarkDate, forKey: Keys.disembarkDate) }
    }
    var isConfigured: Bool {
        didSet { UserDefaults.standard.set(isConfigured, forKey: Keys.isConfigured) }
    }

    /// The family member's own name (display only), set during pairing.
    var watcherName: String {
        didSet { UserDefaults.standard.set(watcherName, forKey: Keys.watcherName) }
    }
    /// Identity of the redeemed pairing link (for later revocation). Never shown.
    var accountId: String {
        didSet { UserDefaults.standard.set(accountId, forKey: Keys.accountId) }
    }
    var watchId: String {
        didSet { UserDefaults.standard.set(watchId, forKey: Keys.watchId) }
    }
    /// Guest mode = following a ship's public itinerary (manual pick).
    /// Family mode (isGuest == false) = following a specific person via a code.
    var isGuest: Bool {
        didSet { UserDefaults.standard.set(isGuest, forKey: Keys.isGuest) }
    }

    /// A pairing code arriving via the seayousoon:// deep link (QR scan).
    /// Transient — not persisted; consumed by the onboarding screen.
    var pendingRedeemCode: String?

    private enum Keys {
        static let crewName = "crewName"
        static let shipName = "shipName"
        static let embarkDate = "embarkDate"
        static let disembarkDate = "disembarkDate"
        static let isConfigured = "isConfigured"
        static let watcherName = "watcherName"
        static let accountId = "accountId"
        static let watchId = "watchId"
        static let isGuest = "isGuest"
    }

    init() {
        let defaults = UserDefaults.standard
        crewName = defaults.string(forKey: Keys.crewName) ?? ""
        shipName = defaults.string(forKey: Keys.shipName) ?? AidaShip.aidasol.rawValue
        embarkDate = defaults.object(forKey: Keys.embarkDate) as? Date ?? .now
        disembarkDate = defaults.object(forKey: Keys.disembarkDate) as? Date
            ?? Calendar.current.date(byAdding: .month, value: 4, to: .now) ?? .now
        isConfigured = defaults.bool(forKey: Keys.isConfigured)
        watcherName = defaults.string(forKey: Keys.watcherName) ?? ""
        accountId = defaults.string(forKey: Keys.accountId) ?? ""
        watchId = defaults.string(forKey: Keys.watchId) ?? ""
        isGuest = defaults.bool(forKey: Keys.isGuest)
        previousShip = defaults.string(forKey: "previousShip")
        previousEmbark = defaults.object(forKey: "previousEmbark") as? Date
        previousDisembark = defaults.object(forKey: "previousDisembark") as? Date
    }

    /// First name only, for friendly sentences ("Where is Jojo today?").
    var displayName: String {
        crewName.split(separator: " ").first.map(String.init) ?? crewName
    }

    /// What the UI is about: the person (family mode) or the ship (guest mode).
    var subject: String { isGuest ? shipName : displayName }

    /// Apply a redeemed pairing profile (family mode).
    func configure(from profile: CrewProfile, watcherName: String) {
        isGuest = false
        self.watcherName = watcherName
        crewName = profile.crewName
        shipName = profile.shipName
        embarkDate = profile.embarkDate
        disembarkDate = profile.disembarkDate
        accountId = profile.accountId
        watchId = profile.watchId
        isConfigured = true
    }

    /// Follow a ship's public itinerary (guest mode — no person, no code).
    /// Switching away from an existing guest setup remembers it, so a quick
    /// look at a job offer's route is one tap away from home again.
    func configureGuest(ship: String, embark: Date, disembark: Date) {
        if isConfigured && isGuest && ship != shipName {
            previousShip = shipName
            previousEmbark = embarkDate
            previousDisembark = disembarkDate
        }
        isGuest = true
        shipName = ship
        embarkDate = embark
        disembarkDate = disembark
        crewName = ""
        watcherName = ""
        accountId = ""
        watchId = ""
        isConfigured = true
    }

    // MARK: Previous guest setup (the way back after a "quick look")

    var previousShip: String? {
        didSet { UserDefaults.standard.set(previousShip, forKey: "previousShip") }
    }
    var previousEmbark: Date? {
        didSet { UserDefaults.standard.set(previousEmbark, forKey: "previousEmbark") }
    }
    var previousDisembark: Date? {
        didSet { UserDefaults.standard.set(previousDisembark, forKey: "previousDisembark") }
    }

    var hasPreviousShip: Bool { isGuest && previousShip != nil }

    /// One tap back to the ship watched before the last "Change ship".
    func returnToPreviousShip() {
        guard let ship = previousShip,
              let embark = previousEmbark,
              let disembark = previousDisembark else { return }
        shipName = ship
        embarkDate = embark
        disembarkDate = disembark
        clearPreviousShip()
    }

    func clearPreviousShip() {
        previousShip = nil
        previousEmbark = nil
        previousDisembark = nil
    }

    /// Forget the current setup (returns the app to onboarding).
    func unpair() {
        isConfigured = false
        isGuest = false
        crewName = ""
        watcherName = ""
        accountId = ""
        watchId = ""
        clearPreviousShip()
    }
}
