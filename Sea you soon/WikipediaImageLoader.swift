//
//  WikipediaImageLoader.swift
//  Sea you soon
//
//  Fetches a representative photo + short description for each port from
//  Wikipedia (English-first), with a disk cache so it works offline / behind a
//  ship's slow connection. Adapted from the original Finding Patrick loader.
//

import Foundation
import UIKit

/// Cached data from a Wikipedia page summary
struct WikiInfo: Codable {
    let imageURL: URL?
    let alternateImageURL: URL?
    let extract: String?
    let articleURL: URL?
    let cachedAt: Date

    init(imageURL: URL?, alternateImageURL: URL?, extract: String?, articleURL: URL?, cachedAt: Date = .now) {
        self.imageURL = imageURL
        self.alternateImageURL = alternateImageURL
        self.extract = extract
        self.articleURL = articleURL
        self.cachedAt = cachedAt
    }

    /// Entry expires after 7 days
    var isExpired: Bool { cachedAt.timeIntervalSinceNow < -7 * 24 * 3600 }
}

// MARK: - Disk Cache

private enum DiskCache {
    private static let metadataFile: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("WikiCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("wiki-info.json")
    }()

    private static let imageDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("WikiImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func safeFilename(from key: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in Data(key.utf8) {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16)
    }

    static func saveAllInfo(_ cache: [String: WikiInfo]) {
        try? JSONEncoder().encode(cache).write(to: metadataFile, options: .atomic)
    }

    static func loadAllInfo() -> [String: WikiInfo] {
        guard let data = try? Data(contentsOf: metadataFile),
              let cache = try? JSONDecoder().decode([String: WikiInfo].self, from: data) else {
            return [:]
        }
        return cache.filter { !$0.value.isExpired }
    }

    static func saveImageData(_ data: Data, for url: URL) {
        let file = imageDir.appendingPathComponent(safeFilename(from: url.absoluteString))
        try? data.write(to: file, options: .atomic)
    }

    static func loadImageData(for url: URL) -> Data? {
        let file = imageDir.appendingPathComponent(safeFilename(from: url.absoluteString))
        return try? Data(contentsOf: file)
    }

    static func clearAll() {
        try? FileManager.default.removeItem(at: metadataFile)
        try? FileManager.default.removeItem(at: imageDir)
        try? FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: metadataFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    }
}

@MainActor @Observable
class WikipediaImageLoader {
    private var cache: [String: WikiInfo] = [:]
    private var imageCache: [URL: UIImage] = [:]
    private var networkFetched: Set<String> = []
    private var inFlight: Set<String> = []

    /// Locations that should always use local data (no Wikipedia lookup).
    private let localOnly: Set<String> = [Finding.seaLabel]

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private static let nonPhotoKeywords = [
        "wappen", "coat_of_arms", "arms_of", "-arms", "_arms",
        "flag_of", "logo", "icon",
        "blason", "escudo", "map_of", " map", "_map", "karte", "diagram", "chart",
        "seal_of", "emblem", "shield", "symbol", "insignia",
        "stemma", "blazon", "crest", "lokalisierung", "location_map",
        "lageplan", "locator", "commons-logo", "pictogram",
        "signature", "autograph", "panorama_of", "cenotaph",
        "sentinel", "satellite", "landsat"
    ]

    private static let interestingSectionKeywords = [
        "landmarks", "places of interest", "tourism", "sights",
        "attractions", "architecture", "gallery", "harbour", "harbor",
        "sehenswürdigkeiten", "tourismus", "bauwerke", "hafen", "altstadt"
    ]

    /// Wikipedia editions to try, in order (English first for this app).
    private let wikis = ["en", "de"]

    init() { cache = DiskCache.loadAllInfo() }

    // MARK: - Public API

    func clearCache() {
        cache.removeAll()
        imageCache.removeAll()
        networkFetched.removeAll()
        DiskCache.clearAll()
        URLCache.shared.removeAllCachedResponses()
    }

    func imageURL(for location: String) -> URL? { cache[location]?.imageURL }
    func alternateImageURL(for location: String) -> URL? { cache[location]?.alternateImageURL }
    func extract(for location: String) -> String? { cache[location]?.extract }
    func articleURL(for location: String) -> URL? { cache[location]?.articleURL }

    func cachedImage(for url: URL) -> UIImage? {
        if let img = imageCache[url] { return img }
        if let data = DiskCache.loadImageData(for: url), let img = UIImage(data: data) {
            imageCache[url] = img
            return img
        }
        return nil
    }

    func downloadAndCacheImage(for url: URL) async {
        if imageCache[url] != nil { return }
        do {
            let (data, _) = try await session.data(from: url)
            if let img = UIImage(data: data) {
                imageCache[url] = img
                DiskCache.saveImageData(data, for: url)
            }
        } catch { }
    }

    func fetchInfo(for finding: Finding) async {
        await fetchInfo(
            for: finding.location,
            latitude: finding.coordinates.latitude,
            longitude: finding.coordinates.longitude
        )
    }

    func fetchInfo(for location: String, latitude: Double?, longitude: Double?) async {
        if localOnly.contains(location) || networkFetched.contains(location) || inFlight.contains(location) {
            return
        }

        let cleanName = location
            .replacingOccurrences(of: "in ", with: "")
            .trimmingCharacters(in: .whitespaces)

        inFlight.insert(location)
        defer { inFlight.remove(location) }

        let title = await resolveTitle(cleanName: cleanName, latitude: latitude, longitude: longitude)
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }

        var imageURL: URL?
        var extract: String?
        var articleURL: URL?
        var networkSucceeded = false

        for wiki in wikis {
            guard let apiURL = URL(string: "https://\(wiki).wikipedia.org/api/rest_v1/page/summary/\(encodedTitle)") else { continue }
            do {
                let (data, _) = try await session.data(from: apiURL)
                let summary = try JSONDecoder().decode(WikiSummary.self, from: data)
                if summary.type == "disambiguation" { continue }
                networkSucceeded = true
                if extract == nil { extract = summary.extract }
                if articleURL == nil, let page = summary.content_urls?.desktop?.page {
                    articleURL = URL(string: page)
                }
                if let source = summary.originalimage?.source, looksLikePhoto(source) {
                    imageURL = URL(string: source)
                }
                if imageURL == nil {
                    imageURL = await findBestPhoto(title: title, wiki: wiki)
                }
                if imageURL != nil { break }
            } catch { }
        }

        if networkSucceeded {
            var alternateImageURL: URL?
            if let primaryURL = imageURL {
                alternateImageURL = await findAlternatePhoto(title: title, primaryURL: primaryURL)
            }
            let info = WikiInfo(imageURL: imageURL, alternateImageURL: alternateImageURL, extract: extract, articleURL: articleURL)
            cache[location] = info
            networkFetched.insert(location)
            DiskCache.saveAllInfo(cache)
        }
    }

    // MARK: - Photo filtering

    private func looksLikePhoto(_ urlOrFilename: String) -> Bool {
        let lower = urlOrFilename.lowercased()
        if lower.contains(".svg") { return false }
        if lower.hasSuffix(".gif") { return false }
        for keyword in Self.nonPhotoKeywords where lower.contains(keyword) { return false }
        return true
    }

    private func findBestPhoto(title: String, wiki: String) async -> URL? {
        if let photo = await findPhotoFromInterestingSections(title: title, wiki: wiki) { return photo }
        return await findPhotoFromAllImages(title: title, wiki: wiki)
    }

    private func findAlternatePhoto(title: String, primaryURL: URL) async -> URL? {
        let primaryPath = primaryURL.path.lowercased()
        for wiki in wikis {
            if let alt = await findDifferentPhoto(title: title, wiki: wiki, excludingPath: primaryPath) { return alt }
        }
        return nil
    }

    private func findDifferentPhoto(title: String, wiki: String, excludingPath: String) async -> URL? {
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://\(wiki).wikipedia.org/w/api.php?action=query&titles=\(encoded)&prop=images&format=json&imlimit=50") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            let result = try JSONDecoder().decode(PageImagesResponse.self, from: data)
            let filenames = result.query?.pages?.values.first?.images?.map(\.title) ?? []
            let photoFilenames = filenames.filter { name in
                let lower = name.lowercased()
                guard lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png") else { return false }
                return looksLikePhoto(name)
            }
            for filename in photoFilenames {
                guard let fileURL = await fetchFileURL(filename: filename, wiki: wiki) else { continue }
                if fileURL.path.lowercased() != excludingPath { return fileURL }
            }
        } catch { }
        return nil
    }

    private func findPhotoFromInterestingSections(title: String, wiki: String) async -> URL? {
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://\(wiki).wikipedia.org/w/api.php?action=parse&page=\(encoded)&prop=sections&format=json") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            let result = try JSONDecoder().decode(ParseSectionsResponse.self, from: data)
            let sections = result.parse?.sections ?? []
            var tried = 0
            for section in sections where tried < 3 {
                let sectionName = section.line
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .lowercased()
                guard Self.interestingSectionKeywords.contains(where: { sectionName.contains($0) }) else { continue }
                tried += 1
                if let photo = await findPhotoInSection(title: title, sectionIndex: section.index, wiki: wiki) { return photo }
            }
        } catch { }
        return nil
    }

    private func findPhotoInSection(title: String, sectionIndex: String, wiki: String) async -> URL? {
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://\(wiki).wikipedia.org/w/api.php?action=parse&page=\(encoded)&section=\(sectionIndex)&prop=images&format=json") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            let result = try JSONDecoder().decode(ParseImagesResponse.self, from: data)
            let images = result.parse?.images ?? []
            let photoFilenames = images.filter { name in
                let lower = name.lowercased()
                guard lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png") else { return false }
                return looksLikePhoto(name)
            }
            guard let bestFile = photoFilenames.first else { return nil }
            return await fetchFileURL(filename: "File:\(bestFile)", wiki: wiki)
        } catch { }
        return nil
    }

    private func findPhotoFromAllImages(title: String, wiki: String) async -> URL? {
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://\(wiki).wikipedia.org/w/api.php?action=query&titles=\(encoded)&prop=images&format=json&imlimit=50") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            let result = try JSONDecoder().decode(PageImagesResponse.self, from: data)
            let filenames = result.query?.pages?.values.first?.images?.map(\.title) ?? []
            let photoFilenames = filenames.filter { name in
                let lower = name.lowercased()
                guard lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png") else { return false }
                return looksLikePhoto(name)
            }
            guard let bestFile = photoFilenames.first else { return nil }
            return await fetchFileURL(filename: bestFile, wiki: wiki)
        } catch { }
        return nil
    }

    private func fetchFileURL(filename: String, wiki: String) async -> URL? {
        guard let encoded = filename.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://\(wiki).wikipedia.org/w/api.php?action=query&titles=\(encoded)&prop=imageinfo&iiprop=url&iiurlwidth=1200&format=json") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            let result = try JSONDecoder().decode(ImageInfoResponse.self, from: data)
            if let info = result.query?.pages?.values.first?.imageinfo?.first {
                let urlString = info.thumburl ?? info.url
                if let urlString { return URL(string: urlString) }
            }
        } catch { }
        return nil
    }

    // MARK: - Title resolution

    private func resolveTitle(cleanName: String, latitude: Double?, longitude: Double?) async -> String {
        guard let encoded = cleanName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let checkURL = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else { return cleanName }

        var needsGeoSearch = false
        do {
            let (data, response) = try await session.data(from: checkURL)
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            if httpStatus == 200 {
                let summary = try JSONDecoder().decode(WikiSummary.self, from: data)
                if summary.type != "disambiguation" { return cleanName }
                needsGeoSearch = true
            } else {
                needsGeoSearch = true
            }
        } catch {
            needsGeoSearch = true
        }

        guard needsGeoSearch, let lat = latitude, let lon = longitude else { return cleanName }

        let geoURLString = "https://en.wikipedia.org/w/api.php?action=query&list=geosearch&gscoord=\(lat)%7C\(lon)&gsradius=10000&gslimit=5&format=json"
        guard let geoURL = URL(string: geoURLString) else { return cleanName }
        do {
            let (data, _) = try await session.data(from: geoURL)
            let geoResult = try JSONDecoder().decode(GeoSearchResult.self, from: data)
            if let firstTitle = geoResult.query?.geosearch?.first?.title { return firstTitle }
        } catch { }
        return cleanName
    }
}

// MARK: - API Response Models

private struct WikiSummary: Decodable {
    let type: String?
    let extract: String?
    let originalimage: WikiImage?
    let content_urls: ContentURLs?

    struct WikiImage: Decodable { let source: String }
    struct ContentURLs: Decodable {
        let desktop: DesktopURL?
        struct DesktopURL: Decodable { let page: String? }
    }
}

private struct GeoSearchResult: Decodable {
    let query: Query?
    struct Query: Decodable { let geosearch: [GeoArticle]? }
    struct GeoArticle: Decodable { let title: String }
}

private struct ParseSectionsResponse: Decodable {
    let parse: Parse?
    struct Parse: Decodable { let sections: [Section]? }
    struct Section: Decodable { let line: String; let index: String }
}

private struct ParseImagesResponse: Decodable {
    let parse: Parse?
    struct Parse: Decodable { let images: [String]? }
}

private struct PageImagesResponse: Decodable {
    let query: Query?
    struct Query: Decodable { let pages: [String: Page]? }
    struct Page: Decodable { let images: [ImageRef]? }
    struct ImageRef: Decodable { let title: String }
}

private struct ImageInfoResponse: Decodable {
    let query: Query?
    struct Query: Decodable { let pages: [String: Page]? }
    struct Page: Decodable { let imageinfo: [ImageInfo]? }
    struct ImageInfo: Decodable { let url: String?; let thumburl: String? }
}
