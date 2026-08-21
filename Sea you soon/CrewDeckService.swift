//
//  CrewDeckService.swift
//  Sea you soon
//
//  The crew-side JSON API of Crew Deck: sign in with the Crew Deck account
//  (username + PIN — OUR credential, the gate for anything that speaks as a
//  person), list followers, revoke, and send short one-way messages.
//  Family side fetches messages with the watchId issued at pairing.
//
//  Auth is the same session cookie as the website; URLSession's shared cookie
//  storage keeps it for ~14 days, so crew sign in rarely.
//

import Foundation

struct Follower: Codable, Identifiable {
    let watchId: String
    let watcherName: String
    let since: String
    var id: String { watchId }
}

struct CrewMessage: Codable, Identifiable {
    let id: Int
    let body: String
    let sentAt: String
}

struct FamilyMessages: Codable {
    let fromName: String
    let messages: [CrewMessage]
}

/// A freshly minted single-use pairing code (7 days, one redemption).
struct InviteCode: Codable {
    let code: String
    let expiresAt: String
    let link: String
}

/// The CURRENT contract behind a pairing link. Tours get extended and ships
/// change; the family app re-fetches this at launch so it quietly stays true.
struct FamilyProfile: Codable {
    let crewName: String
    let shipName: String
    let embarkDate: Date
    let disembarkDate: Date
}

enum CrewDeckError: LocalizedError {
    case notSignedIn
    case invalidLogin
    case usernameTaken
    case badFields
    case rateLimited
    case network

    var errorDescription: String? {
        switch self {
        case .notSignedIn:   return "Please sign in to Crew Deck."
        case .invalidLogin:  return "Username or PIN not recognised."
        case .usernameTaken: return "That username is taken — choose another."
        case .badFields:     return "Username: 3–20 letters/numbers. PIN: at least 4 digits."
        case .rateLimited:   return "Too many attempts — please wait a few minutes."
        case .network:       return "Couldn't reach Crew Deck. Please check your connection."
        }
    }
}

enum CrewDeck {
    static let baseURL = URL(string: "https://crew.oconnell-connect.com")!

    struct LoginInfo: Codable {
        let username: String
        let name: String
        let ship: String
        // Contract dates (ISO-8601): present on login, so a reinstalled app
        // can restore crew mode from a bare username + PIN.
        let embarkDate: String?
        let disembarkDate: String?
    }

    private static func request(_ path: String, method: String = "GET",
                                json: [String: String]? = nil) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.timeoutInterval = 20
        if let json {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONEncoder().encode(json)
        }
        return req
    }

    static func login(username: String, pin: String) async throws -> LoginInfo {
        let req = request("api/login", method: "POST",
                          json: ["username": username, "pin": pin])
        let (data, response) = try await URLSession.shared.data(for: req)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: return try JSONDecoder().decode(LoginInfo.self, from: data)
        case 401: throw CrewDeckError.invalidLogin
        case 429: throw CrewDeckError.rateLimited
        default:  throw CrewDeckError.network
        }
    }

    /// Native in-app registration (the website form's twin). Signs in too —
    /// the session cookie arrives with the 201.
    static func register(username: String, name: String, ship: String,
                         embark: Date, disembark: Date, pin: String) async throws -> LoginInfo {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let req = request("api/register", method: "POST", json: [
            "username": username, "name": name, "ship": ship,
            "embarkDate": f.string(from: embark),
            "disembarkDate": f.string(from: disembark),
            "pin": pin,
        ])
        let (data, response) = try await URLSession.shared.data(for: req)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 201: return try JSONDecoder().decode(LoginInfo.self, from: data)
        case 409: throw CrewDeckError.usernameTaken
        case 400: throw CrewDeckError.badFields
        case 429: throw CrewDeckError.rateLimited
        default:  throw CrewDeckError.network
        }
    }

    static func followers() async throws -> [Follower] {
        let (data, response) = try await URLSession.shared.data(for: request("api/followers"))
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: return try JSONDecoder().decode([Follower].self, from: data)
        case 401: throw CrewDeckError.notSignedIn
        default:  throw CrewDeckError.network
        }
    }

    static func send(watchId: String, body: String) async throws {
        let req = request("api/messages", method: "POST",
                          json: ["watchId": watchId, "body": body])
        let (_, response) = try await URLSession.shared.data(for: req)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 201: return
        case 401: throw CrewDeckError.notSignedIn
        default:  throw CrewDeckError.network
        }
    }

    static func generateCode() async throws -> InviteCode {
        let req = request("api/generate-code", method: "POST")
        let (data, response) = try await URLSession.shared.data(for: req)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 201: return try JSONDecoder().decode(InviteCode.self, from: data)
        case 401: throw CrewDeckError.notSignedIn
        default:  throw CrewDeckError.network
        }
    }

    static func revoke(watchId: String) async throws {
        let req = request("api/revoke", method: "POST", json: ["watchId": watchId])
        let (_, response) = try await URLSession.shared.data(for: req)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: return
        case 401: throw CrewDeckError.notSignedIn
        default:  throw CrewDeckError.network
        }
    }

    /// Family side — the watchId issued at pairing is the credential.
    /// 404 means the link is unknown or was revoked; callers leave the local
    /// setup untouched in that case (revocation just stops updates/messages).
    static func familyProfile(watchId: String) async throws -> FamilyProfile {
        let (data, response) = try await URLSession.shared.data(
            for: request("api/profile/\(watchId)"))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw CrewDeckError.network
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FamilyProfile.self, from: data)
    }

    /// Family side — the watchId issued at pairing is the credential.
    static func familyMessages(watchId: String) async throws -> FamilyMessages {
        let (data, response) = try await URLSession.shared.data(
            for: request("api/messages/\(watchId)"))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw CrewDeckError.network
        }
        return try JSONDecoder().decode(FamilyMessages.self, from: data)
    }
}
