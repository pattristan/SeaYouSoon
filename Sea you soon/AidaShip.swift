//
//  AidaShip.swift
//  Sea you soon
//
//  The AIDA fleet and each ship's bug-cam webcam URL.
//

import Foundation

enum AidaShip: String, CaseIterable, Identifiable {
    case aidabella = "AIDAbella"
    case aidablu = "AIDAblu"
    case aidacosma = "AIDAcosma"
    case aidadiva = "AIDAdiva"
    case aidaluna = "AIDAluna"
    case aidamar = "AIDAmar"
    case aidanova = "AIDAnova"
    case aidaperla = "AIDAperla"
    case aidaprima = "AIDAprima"
    case aidasol = "AIDAsol"
    case aidastella = "AIDAstella"

    var id: String { rawValue }

    /// URL slug matches the enum case name (e.g. .aidasol -> "aidasol")
    var slug: String { String(describing: self) }

    var webcamURL: URL? {
        URL(string: "https://aida.de/schiffe/\(slug)/bugcam")
    }

    /// All ship names, for pickers.
    static var names: [String] { allCases.map(\.rawValue) }
}
