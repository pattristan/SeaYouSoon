//
//  CruiseListView.swift
//  Sea you soon
//
//  The contract itinerary, grouped by cruise — each cruise is one Liquid Glass
//  card with a drop-down (DisclosureGroup), like the original Finding Patrick
//  list. Completed cruises (last day before today) are hidden by default and
//  can be revealed with a toggle. The current cruise starts expanded.
//

import SwiftUI

struct CruiseListView: View {
    @Environment(FleetData.self) var fleetData

    @State private var expandedCruises: Set<String> = []
    @State private var showCompleted = false
    @State private var searchText = ""
    @State private var showMeetings = false

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

    /// Findings grouped by cruise number, in itinerary order.
    private var cruises: [(cruise: String, stops: [Finding])] {
        var order: [String] = []
        var groups: [String: [Finding]] = [:]
        for finding in fleetData.findings {
            if groups[finding.cruise] == nil { order.append(finding.cruise) }
            groups[finding.cruise, default: []].append(finding)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    /// A cruise is completed when its last day is before today.
    private func isCompleted(_ stops: [Finding]) -> Bool {
        guard let last = stops.last,
              let lastDate = Self.dayFormatter.date(from: last.OnThisDay) else { return false }
        return Calendar.current.startOfDay(for: lastDate) < Calendar.current.startOfDay(for: .now)
    }

    /// The cruise containing today (if any).
    private var currentCruiseNumber: String? {
        let today = Self.dayFormatter.string(from: .now)
        return fleetData.findings.first(where: { $0.OnThisDay == today })?.cruise
    }

    private var visibleCruises: [(cruise: String, stops: [Finding])] {
        showCompleted ? cruises : cruises.filter { !isCompleted($0.stops) }
    }

    private var completedCount: Int {
        cruises.filter { isCompleted($0.stops) }.count
    }

    /// Upcoming days when a sister ship shares the port — "when's the next
    /// meeting?" is the question every crew mess asks.
    private var upcomingMeetings: [Finding] {
        let today = Calendar.current.startOfDay(for: .now)
        return fleetData.findings.filter { stop in
            guard !fleetData.sisterShips(at: stop).isEmpty,
                  let d = Self.dayFormatter.date(from: stop.OnThisDay) else { return false }
            return Calendar.current.startOfDay(for: d) >= today
        }
    }

    /// Days matching the search query — port name, date or times.
    private var searchResults: [Finding] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return fleetData.findings.filter {
            $0.location.localizedCaseInsensitiveContains(q)
                || $0.OnThisDay.contains(q)
                || $0.fromTill.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ZStack {
            OceanBackground()

            ScrollView {
                if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Searching: a flat list of matching days, no folds to open.
                    VStack(spacing: 0) {
                        if searchResults.isEmpty {
                            Text("No days match \"\(searchText)\"")
                                .font(.callout)
                                .foregroundStyle(Color.oceanInk.opacity(0.7))
                                .padding(.vertical, 24)
                        } else {
                            ForEach(searchResults) { stop in
                                stopRow(stop)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                } else {
                    LazyVStack(spacing: 16) {
                        // "When's the next meeting?" — sister-ship encounters ahead.
                        if !upcomingMeetings.isEmpty {
                            Button {
                                withAnimation(.spring(duration: 0.4)) { showMeetings.toggle() }
                            } label: {
                                HStack(spacing: 6) {
                                    CruiseLinerIcon().frame(height: 12)
                                    Text(showMeetings
                                         ? "Show full itinerary"
                                         : "Fleet meetings (\(upcomingMeetings.count))")
                                }
                                .font(.footnote)
                                .foregroundStyle(Color.oceanInk)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                            }
                            .glassEffect(.regular.tint(.teal.opacity(showMeetings ? 0.4 : 0.15)).interactive(),
                                         in: .capsule)
                        }

                        if showMeetings {
                            VStack(spacing: 0) {
                                ForEach(upcomingMeetings) { stop in
                                    stopRow(stop)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .glassEffect(.regular, in: .rect(cornerRadius: 20))
                        } else {
                            if completedCount > 0 {
                                Button {
                                    withAnimation(.spring(duration: 0.4)) { showCompleted.toggle() }
                                } label: {
                                    Label(showCompleted
                                          ? "Hide completed cruises"
                                          : "Show \(completedCount) completed \(completedCount == 1 ? "cruise" : "cruises")",
                                          systemImage: showCompleted ? "eye.slash" : "calendar.badge.checkmark")
                                        .font(.footnote)
                                        .foregroundStyle(Color.oceanInk)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                }
                                .glassEffect(.regular.interactive(), in: .capsule)
                            }

                            ForEach(visibleCruises, id: \.cruise) { group in
                                cruiseCard(group)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Port, date or time")
        .navigationTitle("Complete itinerary")
        .navigationBarTitleDisplayMode(.inline)
        // A search query belongs to the route it searched — when the itinerary
        // changes (return chip, change ship), the stale query clears with it.
        .onChange(of: fleetData.findings) { searchText = ""; showMeetings = false }
        .safeAreaInset(edge: .top) {
            // The offer's cruise is usually in the future — the list is where
            // it gets judged, so the way home lives here too.
            ReturnShipChip()
        }
    }

    /// One cruise = one glass card with a disclosure drop-down of its day rows.
    private func cruiseCard(_ group: (cruise: String, stops: [Finding])) -> some View {
        let isCurrent = group.cruise == currentCruiseNumber
        return DisclosureGroup(
            isExpanded: Binding(
                get: { expandedCruises.contains(group.cruise) },
                set: { open in
                    withAnimation(.spring(duration: 0.35)) {
                        if open { expandedCruises.insert(group.cruise) }
                        else { expandedCruises.remove(group.cruise) }
                    }
                }
            )
        ) {
            VStack(spacing: 0) {
                Divider().overlay(Color.oceanInk.opacity(0.25)).padding(.top, 8)
                ForEach(group.stops) { stop in
                    stopRow(stop)
                }
            }
        } label: {
            HStack {
                Label {
                    Text(isCurrent ? "Current cruise" : "Cruise \(group.cruise)")
                        .font(.headline)
                } icon: {
                    if isCurrent {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.mint)
                    } else {
                        CruiseLinerIcon()
                            .frame(height: 16)
                            .foregroundStyle(Color.oceanInk)
                    }
                }
                Spacer()
                Text(dateRange(for: group.stops))
                    .font(.caption)
                    .opacity(0.75)
            }
            .foregroundStyle(Color.oceanInk)
            .padding(.vertical, 4)
        }
        .tint(Color.oceanInk)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private func stopRow(_ stop: Finding) -> some View {
        NavigationLink {
            DestinationDetailView(finding: stop)
        } label: {
            HStack {
                Text(String(stop.OnThisDay.prefix(5)))   // "dd.MM"
                    .font(.caption.monospacedDigit())
                    .opacity(0.7)
                    .frame(width: 48, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.location)
                        .fontWeight(stop.isAtSea ? .regular : .medium)
                        .opacity(stop.isAtSea ? 0.7 : 1.0)
                    Text(stop.fromTill)
                        .font(.caption)
                        .opacity(0.6)

                    // Sister ships in the same port — a photo moment for
                    // guests, a ship visit for crew.
                    let sisters = fleetData.sisterShips(at: stop)
                    if !sisters.isEmpty {
                        HStack(spacing: 5) {
                            CruiseLinerIcon()
                                .frame(height: 10)
                            Text("meets \(sisters.joined(separator: " & "))")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.teal)
                    }
                }
                Spacer()
                if stop.isAtSea {
                    Image(systemName: "water.waves")
                        .foregroundStyle(.mint.opacity(0.8))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .opacity(0.45)
                }
            }
            .foregroundStyle(Color.oceanInk)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dateRange(for stops: [Finding]) -> String {
        guard let first = stops.first?.OnThisDay, let last = stops.last?.OnThisDay else { return "" }
        return "\(first) – \(last)"
    }
}

#Preview {
    NavigationStack {
        CruiseListView().environment(FleetData())
    }
}
