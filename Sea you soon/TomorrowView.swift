//
//  TomorrowView.swift
//  Sea you soon
//
//  A quick look at where the ship will be tomorrow — Liquid Glass over the
//  shared ocean backdrop.
//

import SwiftUI

struct TomorrowView: View {
    @Environment(FleetData.self) var fleetData
    @Environment(CrewSetup.self) var crewSetup
    @Environment(\.dismiss) private var dismiss

    /// "Coming up" starts folded — something satisfying to tap open.
    @State private var comingUpExpanded = false

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

    private var tomorrowKey: String {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        return Self.dayFormatter.string(from: tomorrow)
    }

    private var tomorrowFinding: Finding? {
        fleetData.findings.first { $0.OnThisDay == tomorrowKey }
    }

    private var name: String { crewSetup.subject }

    /// Where tomorrow falls relative to the contract window.
    private enum Phase { case beforeEmbark, aboard, afterDisembark }
    private var tomorrowPhase: Phase {
        let cal = Calendar.current
        let tomorrow = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: .now) ?? .now)
        if tomorrow < cal.startOfDay(for: crewSetup.embarkDate) { return .beforeEmbark }
        if tomorrow > cal.startOfDay(for: crewSetup.disembarkDate) { return .afterDisembark }
        return .aboard
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OceanBackground()

                if tomorrowPhase == .aboard, let finding = tomorrowFinding {
                    ScrollView {
                        GlassEffectContainer(spacing: 20) {
                            VStack(spacing: 18) {
                                // Photo + port tile tap through to the detail view,
                                // chevron pinned trailing so the text stays centred
                                // — mirroring TodayView.
                                NavigationLink {
                                    DestinationDetailView(finding: finding)
                                } label: {
                                    VStack(spacing: 14) {
                                        LocationImageView(finding: finding, width: 350, height: 350)
                                            .clipShape(RoundedRectangle(cornerRadius: 17))
                                            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)

                                        VStack(spacing: 8) {
                                            Text(finding.location)
                                                .font(.custom("NY", size: 26))
                                                .fontWeight(.bold)
                                                .multilineTextAlignment(.center)

                                            if !finding.isAtSea {
                                                Text(finding.fromTill)
                                                    .fontWeight(.semibold)
                                                    .font(.custom("NY", size: 17))
                                                    .opacity(0.9)

                                                if let hint = ShipTime.viewerTimeHint(for: finding) {
                                                    Text(hint)
                                                        .font(.custom("NY", size: 12))
                                                        .opacity(0.65)
                                                }
                                            }

                                            Text(finding.isAtSea
                                                 ? "\(name) will be at sea"
                                                 : "\(name) will be in \(finding.location)")
                                                .font(.custom("NY", size: 13))
                                                .opacity(0.8)
                                                .italic()
                                                .multilineTextAlignment(.center)
                                        }
                                        .foregroundStyle(Color.oceanInk)
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 16)
                                        .frame(maxWidth: 340)
                                        .overlay(alignment: .trailing) {
                                            Image(systemName: "chevron.right")
                                                .font(.footnote)
                                                .foregroundStyle(Color.oceanInk.opacity(0.45))
                                                .padding(.trailing, 14)
                                        }
                                        .glassEffect(.regular, in: .rect(cornerRadius: 17))
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                // The rest of this cruise — no more tap-hunting
                                // for the day after tomorrow.
                                if !restOfCruise(after: finding).isEmpty {
                                    comingUpCard(stops: restOfCruise(after: finding))
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    GlassEffectContainer(spacing: 20) {
                        VStack(spacing: 16) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.oceanInk)
                                .frame(width: 100, height: 100)
                                .glassEffect(.regular.interactive(), in: .circle)
                            Text(homeTomorrowText)
                                .font(.custom("NY", size: 20))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.oceanInk)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .glassEffect(.regular, in: .rect(cornerRadius: 17))
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Tomorrow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.oceanInk)
                }
            }
        }
    }

    /// The remaining stops of tomorrow's cruise, after tomorrow itself.
    /// Cruises are delimited by Full Turn-Around in the feed (the `cruise` field).
    private func restOfCruise(after tomorrow: Finding) -> [Finding] {
        guard let idx = fleetData.findings.firstIndex(where: { $0.id == tomorrow.id }) else { return [] }
        return fleetData.findings[fleetData.findings.index(after: idx)...]
            .prefix(while: { $0.cruise == tomorrow.cruise })
            .map { $0 }
    }

    /// True when tomorrow is a turnaround day — the first day of a NEW cruise
    /// (its cruise number differs from today's). The card then promises the
    /// next cruise instead of wrongly claiming "this" one.
    private var tomorrowStartsNewCruise: Bool {
        let todayKey = Self.dayFormatter.string(from: .now)
        guard let today = fleetData.findings.first(where: { $0.OnThisDay == todayKey }),
              let tomorrow = tomorrowFinding else { return false }
        return today.cruise != tomorrow.cruise
    }

    private func comingUpCard(stops: [Finding]) -> some View {
        DisclosureGroup(isExpanded: $comingUpExpanded.animation(.spring(duration: 0.35))) {
            VStack(spacing: 0) {
                Divider().overlay(Color.oceanInk.opacity(0.25)).padding(.top, 8)
                ForEach(stops) { stop in
                    NavigationLink {
                        DestinationDetailView(finding: stop)
                    } label: {
                        HStack {
                            Text(String(stop.OnThisDay.prefix(5)))   // "dd.MM"
                                .font(.caption.monospacedDigit())
                                .opacity(0.7)
                                .frame(width: 46, alignment: .leading)
                            Text(stop.location)
                                .fontWeight(stop.isAtSea ? .regular : .medium)
                                .opacity(stop.isAtSea ? 0.7 : 1.0)
                            Spacer()
                            if stop.isAtSea {
                                Image(systemName: "water.waves").foregroundStyle(.mint.opacity(0.8))
                            } else {
                                Text(stop.fromTill).font(.caption2).opacity(0.6)
                                Image(systemName: "chevron.right").font(.caption2).opacity(0.45)
                            }
                        }
                        .foregroundStyle(Color.oceanInk)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        } label: {
            Label(tomorrowStartsNewCruise ? "Coming up on the next cruise" : "still to come on this cruise",
                  systemImage: tomorrowStartsNewCruise ? "sparkles" : "calendar")
                .font(.headline)
                .foregroundStyle(Color.oceanInk)
                .padding(.vertical, 4)
        }
        .tint(Color.oceanInk)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 340)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    private var homeTomorrowText: String {
        switch tomorrowPhase {
        case .beforeEmbark:
            return crewSetup.isGuest
                ? "Your cruise hasn't set sail yet"
                : "\(name) will still be at home tomorrow"
        case .afterDisembark:
            return crewSetup.isGuest
                ? "Your cruise will be over"
                : "\(name) will be back home"
        case .aboard:
            return "Nothing scheduled for tomorrow"
        }
    }
}

#Preview {
    TomorrowView()
        .environment(FleetData())
        .environment(CrewSetup())
        .environment(WikipediaImageLoader())
}
