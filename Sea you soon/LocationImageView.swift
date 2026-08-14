//
//  LocationImageView.swift
//  Sea you soon
//
//  Shows a Wikipedia photo of the port, falling back to a bundled asset if one
//  exists (ports generally have none in this app, so Wikipedia is the source).
//

import SwiftUI

struct LocationImageView: View {
    @Environment(WikipediaImageLoader.self) private var imageLoader: WikipediaImageLoader?
    @Environment(FleetData.self) var fleetData
    let finding: Finding
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    /// Sea days show the porthole frame by default; views can opt out.
    var showPorthole: Bool = true

    /// A bundled asset that matches the location name (rare — most ports have none).
    private var hasBundleImage: Bool {
        UIImage(named: finding.imageName) != nil && finding.imageName != finding.location
    }

    /// True when this is a consecutive day at the same port (ship berthed overnight).
    private var isConsecutiveDay: Bool {
        guard let idx = fleetData.findings.firstIndex(where: { $0.id == finding.id }),
              idx > fleetData.findings.startIndex else { return false }
        let prevIdx = fleetData.findings.index(before: idx)
        return fleetData.findings[prevIdx].location == finding.location
    }

    private var displayImageURL: URL? {
        guard let imageLoader else { return nil }
        if isConsecutiveDay, let alt = imageLoader.alternateImageURL(for: finding.location) {
            return alt
        }
        return imageLoader.imageURL(for: finding.location)
    }

    /// Sea days use one of the bundled sea photos — picked pseudo-randomly per
    /// day (seeded by id, so it doesn't flicker between renders, but varies
    /// from sea day to sea day). "At sea N" has the porthole composited in
    /// (Photoshop); "At sea N-NP" is the plain photo ("No Porthole") used
    /// where the frame isn't wanted, e.g. TomorrowView.
    private var seaImageName: String {
        let idx = (abs(finding.id) % 3) + 1
        return showPorthole ? "At sea \(idx)" : "At sea \(idx)NP"
    }

    var body: some View {
        if finding.isAtSea {
            Image(seaImageName)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
        } else if hasBundleImage {
            localImage
                .frame(width: width, height: height)
                .clipped()
        } else if let url = displayImageURL, let img = imageLoader?.cachedImage(for: url) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
        } else if let url = displayImageURL {
            ZStack {
                placeholder
                ProgressView()
            }
            .frame(width: width, height: height)
            .clipped()
            .task { await imageLoader?.downloadAndCacheImage(for: url) }
        } else {
            placeholder
                .frame(width: width, height: height)
                .clipped()
                .task { await imageLoader?.fetchInfo(for: finding) }
        }
    }

    private var localImage: some View {
        Image(finding.imageName)
            .resizable()
            .scaledToFill()
    }

    /// Neutral placeholder used while a port photo is loading or unavailable.
    @ViewBuilder
    private var placeholder: some View {
        if UIImage(named: finding.imageName) != nil {
            localImage
        } else {
            ZStack {
                LinearGradient(colors: [.blue.opacity(0.35), .teal.opacity(0.25)],
                               startPoint: .top, endPoint: .bottom)
                Image(systemName: finding.isAtSea ? "water.waves" : "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
