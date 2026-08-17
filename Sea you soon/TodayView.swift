//
//  TodayView.swift
//  Sea you soon
//
//  "Where is my seafarer today?" — port photo, on-board time, weather, the
//  countdown home, and a map. Generalised in English from Finding Patrick.
//

import CoreLocation
import SwiftUI

struct TodayView: View {
    @Environment(FleetData.self) var fleetData
    @Environment(CrewSetup.self) var crewSetup
    @Environment(WeatherService.self) var weatherService
    @Environment(WikipediaImageLoader.self) private var imageLoader: WikipediaImageLoader?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @State private var currentIndex = 0
    @State private var showTomorrow = false
    @State private var showList = false
    @State private var showWebcam = false
    @State private var showSettings = false
    @State private var showTimeInfo = false
    @State private var showProgress = false
    @State private var showWeather = false

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

    private var todayFormatted: String { Self.dayFormatter.string(from: .now) }

    private var name: String { crewSetup.subject }

    /// Where the contract stands relative to today.
    private enum Phase { case beforeEmbark, aboard, afterDisembark }
    private var phase: Phase {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        if today < cal.startOfDay(for: crewSetup.embarkDate) { return .beforeEmbark }
        if today > cal.startOfDay(for: crewSetup.disembarkDate) { return .afterDisembark }
        return .aboard
    }

    /// The itinerary row to display: today's, or the nearest end if outside the window.
    private var currentFinding: Finding? {
        guard !fleetData.findings.isEmpty else { return nil }
        if fleetData.findings.indices.contains(currentIndex) {
            return fleetData.findings[currentIndex]
        }
        return fleetData.findings.last
    }

    // MARK: - Ship time

    /// The offset the ship's clocks are actually set to today — including the
    /// hour-by-hour drift across sea days. The single source of truth for the
    /// on-board time AND the "clocks are X ahead/behind" sentence.
    private var shipOffsetHours: Int? {
        guard let current = currentFinding else { return nil }
        let offsetHours: Int
        if current.isAtSea,
           let idx = fleetData.findings.firstIndex(where: { $0.id == current.id }) {
            let nextPort = fleetData.findings[idx...].first(where: { !$0.isAtSea })
            let prevPort = fleetData.findings[...idx].last(where: { !$0.isAtSea })
            let startOffset = ShipTime.timezoneOffset(for: prevPort ?? current)
            let endOffset = ShipTime.timezoneOffset(for: nextPort ?? current)

            var firstSeaIdx = idx
            while firstSeaIdx > fleetData.findings.startIndex
                    && fleetData.findings[fleetData.findings.index(before: firstSeaIdx)].isAtSea {
                firstSeaIdx = fleetData.findings.index(before: firstSeaIdx)
            }
            var lastSeaIdx = idx
            while fleetData.findings.index(after: lastSeaIdx) < fleetData.findings.endIndex
                    && fleetData.findings[fleetData.findings.index(after: lastSeaIdx)].isAtSea {
                lastSeaIdx = fleetData.findings.index(after: lastSeaIdx)
            }
            let totalSeaDays = lastSeaIdx - firstSeaIdx + 1
            let dayNumber = idx - firstSeaIdx + 1

            if totalSeaDays <= 1 || startOffset == endOffset {
                offsetHours = endOffset
            } else {
                let totalShift = endOffset - startOffset
                let shiftPerDay = Double(totalShift) / Double(totalSeaDays)
                offsetHours = startOffset + Int((shiftPerDay * Double(dayNumber)).rounded())
            }
        } else {
            offsetHours = ShipTime.timezoneOffset(for: current)
        }
        return offsetHours
    }

    private var shipTimeString: String? {
        guard let offsetHours = shipOffsetHours,
              let tz = TimeZone(secondsFromGMT: offsetHours * 3600) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = tz
        return formatter.string(from: .now)
    }

    // MARK: - Sea day description

    private var seaDayDescription: String? {
        guard let current = currentFinding,
              let idx = fleetData.findings.firstIndex(where: { $0.id == current.id }) else { return nil }
        guard current.isAtSea else { return nil }

        let prevPort = fleetData.findings[...idx].last(where: { !$0.isAtSea })
        let nextPort = fleetData.findings[idx...].first(where: { !$0.isAtSea })

        if let prev = prevPort, let next = nextPort {
            return "\(name) is at sea, between \(prev.location) and \(next.location)"
        } else if let next = nextPort {
            return "\(name) is at sea, heading to \(next.location)"
        } else if let prev = prevPort {
            return "\(name) is at sea, having left \(prev.location)"
        }
        return nil
    }

    // MARK: - Coordinates (interpolated on sea days)

    private var estimatedCoordinates: Finding.Coordinates {
        guard let current = currentFinding else {
            return Finding.Coordinates(latitude: 0, longitude: 0)
        }
        guard current.isAtSea,
              let idx = fleetData.findings.firstIndex(where: { $0.id == current.id }),
              let start = fleetData.findings[...idx].last(where: { !$0.isAtSea }),
              let end = fleetData.findings[idx...].first(where: { !$0.isAtSea }) else {
            return current.coordinates
        }

        var firstSeaIdx = idx
        while firstSeaIdx > fleetData.findings.startIndex
                && fleetData.findings[fleetData.findings.index(before: firstSeaIdx)].isAtSea {
            firstSeaIdx = fleetData.findings.index(before: firstSeaIdx)
        }
        var lastSeaIdx = idx
        while fleetData.findings.index(after: lastSeaIdx) < fleetData.findings.endIndex
                && fleetData.findings[fleetData.findings.index(after: lastSeaIdx)].isAtSea {
            lastSeaIdx = fleetData.findings.index(after: lastSeaIdx)
        }
        let totalSeaDays = lastSeaIdx - firstSeaIdx + 1
        let dayNumber = idx - firstSeaIdx + 1
        let progress = Double(dayNumber) / Double(totalSeaDays + 1)

        let lat = start.coordinates.latitude + (end.coordinates.latitude - start.coordinates.latitude) * progress
        let lon = start.coordinates.longitude + (end.coordinates.longitude - start.coordinates.longitude) * progress
        return Finding.Coordinates(latitude: lat, longitude: lon)
    }

    // MARK: - Countdown

    private var countdown: (icon: String, message: String)? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let embarkStart = calendar.startOfDay(for: crewSetup.embarkDate)
        let disembarkStart = calendar.startOfDay(for: crewSetup.disembarkDate)
        let guest = crewSetup.isGuest

        if todayStart < embarkStart {
            let days = calendar.dateComponents([.day], from: todayStart, to: embarkStart).day ?? 0
            let unit = days == 1 ? "day" : "days"
            let msg = guest ? "\(days) \(unit) until your cruise" : "\(days) \(unit) until \(name) sets sail"
            return ("ferry.fill", msg)
        } else if todayStart <= disembarkStart {
            let days = calendar.dateComponents([.day], from: todayStart, to: disembarkStart).day ?? 0
            if days == 0 { return ("house.fill", guest ? "Last day of your cruise!" : "\(name) comes home today!") }
            let unit = days == 1 ? "day" : "days"
            let msg = guest ? "\(days) \(unit) left of your cruise" : "\(days) \(unit) until \(name) comes home"
            return ("house.fill", msg)
        } else {
            return ("checkmark.seal.fill", guest ? "Welcome home!" : "\(name) is back home")
        }
    }

    private static let mediumDate: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                OceanBackground()

                switch phase {
                case .aboard:
                    if let current = currentFinding {
                        content(for: current)
                    } else {
                        ContentUnavailableView(
                            "No itinerary found",
                            systemImage: "ferry",
                            description: Text("We couldn't find \(crewSetup.shipName)'s schedule for the dates you entered. Check the dates in Settings.")
                        )
                        .foregroundStyle(Color.oceanInk)
                    }
                case .beforeEmbark, .afterDisembark:
                    homeView
                }
            }
//            .toolbar {
//                ToolbarItem(placement: .bottomBar) {
//                    Button { showTomorrow.toggle() } label: {
//                        Label("Tomorrow", systemImage: "calendar")
//                    }
//                    .sheet(isPresented: $showTomorrow) {
//                        TomorrowView().presentationDetents([.large])
//                    }
//                }
//                ToolbarItem(placement: .bottomBar) {
//                    Button { showList = true } label: {
//                        Label("Cruises", systemImage: "list.bullet")
//                    }
//                }
//                ToolbarItem(placement: .bottomBar) {
//                    Button { showWebcam = true } label: {
//                        Label("Webcam", systemImage: "video")
//                    }
//                }
//            }
            .toolbar {
                
                ToolbarItem(placement: .bottomBar) {
                    let tomorrow = Date.now.addingTimeInterval(86400)
                    let day = Calendar.current.component(.day, from: tomorrow)
                    Button {
                        showTomorrow.toggle()
                    } label: {
//
                            
                            Image(systemName: "\(day).calendar")
                        Text("tomorrow?")
//
                    }
                    .sheet(isPresented: $showTomorrow) {
                        TomorrowView().presentationDetents([.large])
                    }
                }
            
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showList = true
                    } label: {
                      
                        Image(systemName: "list.bullet")
                        Text("itinerary")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showWebcam = true
                    } label: {
                      
                        Image(systemName: "video")
                        Text("live")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationTitle("Where is \(name)? · \(todayFormatted)")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                // After a "Change ship" quick look: one tap back home.
                ReturnShipChip()
            }
            .navigationDestination(isPresented: $showList) { CruiseListView() }
            .navigationDestination(isPresented: $showWebcam) { WebcamView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showTimeInfo) {
                timeInfoSheet.presentationDetents([.height(320)])
            }
            .sheet(isPresented: $showProgress) {
                progressSheet.presentationDetents([.height(340)])
            }
            .sheet(isPresented: $showWeather) {
                weatherSheet.presentationDetents([.height(360)])
            }
            .onAppear { getTheDay() }
            .onChange(of: scenePhase) { if scenePhase == .active { getTheDay() } }
            .onChange(of: fleetData.findings) { getTheDay() }
            .task(id: currentFinding?.id) {
                let coords = estimatedCoordinates
                await weatherService.fetch(latitude: coords.latitude, longitude: coords.longitude)
            }
        }
    }

    @ViewBuilder
    private func content(for current: Finding) -> some View {
        GeometryReader { geo in
            let isRegular = horizontalSizeClass == .regular
            let contentWidth = isRegular ? min(geo.size.width * 0.85, 700) : min(geo.size.width - 40, 340)
            let imageHeight = isRegular ? contentWidth * 0.7 : 300.0
//            let mapHeight = isRegular ? contentWidth * 0.65 : 300.0

            if contentWidth > 0 {
                ScrollView {
                    GlassEffectContainer(spacing: 20) {
                        VStack(spacing: 18) {
                            // Photo + port name tap through to the detail view
                            // (Wikipedia info and the map live there).
                            NavigationLink {
                                DestinationDetailView(finding: current)
                            } label: {
                                VStack(spacing: 14) {
                                    LocationImageView(finding: current, width: contentWidth, height: imageHeight)
                                        .clipShape(RoundedRectangle(cornerRadius: 17))
                                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)

                                    // Port + its hours: one tile, the headline facts.
                                    // The chevron is an overlay pinned to the trailing
                                    // edge, so name and hours centre on each other.
                                    VStack(spacing: 8) {
                                        Text(current.location)
                                            .font(.custom("NY", size: isRegular ? 30 : 26))
                                            .fontWeight(.bold)
                                            .multilineTextAlignment(.center)

                                        if !current.isAtSea {
                                            Text(current.fromTill)
                                                .fontWeight(.semibold)
                                                .font(.custom("NY", size: isRegular ? 20 : 17))
                                                .opacity(0.9)

                                            // Whose clock? Convert for viewers far from the port.
                                            if let hint = ShipTime.viewerTimeHint(for: current) {
                                                Text(hint)
                                                    .font(.custom("NY", size: isRegular ? 14 : 12))
                                                    .opacity(0.65)
                                            }
                                        }

                                        if let seaDescription = seaDayDescription {
                                            Text(seaDescription)
                                                .font(.custom("NY", size: isRegular ? 16 : 13))
                                                .opacity(0.8)
                                                .italic()
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                    .foregroundStyle(Color.oceanInk)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 16)
                                    .frame(maxWidth: contentWidth)
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

                            // Ship time tile — tap for the time-zone story
                            if let time = shipTimeString {
                                Text("current time on board: \(time)")
                                    .font(.custom("NY", size: isRegular ? 18 : 14))
                                    .foregroundStyle(Color.oceanInk)
                                    .padding(.vertical, 12)
                                    .frame(width: contentWidth * 0.92)
                                    .glassEffect(.regular.interactive(), in: .capsule)
                                    .onTapGesture { showTimeInfo = true }
                            }

                            // Weather tile — tap for the full conditions
                            if let info = weatherService.weatherInfo, let temp = weatherService.temperature {
                                HStack(spacing: 4) {
                                    Image(systemName: info.icon).symbolRenderingMode(.multicolor)
                                    Text("weather: \(String(format: "%.0f", temp))° \(info.description)")
                                }
                                .font(.custom("NY", size: isRegular ? 18 : 14))
                                .foregroundStyle(Color.oceanInk)
                                .padding(.vertical, 12)
                                .frame(width: contentWidth * 0.92)
                                .glassEffect(.regular.interactive(), in: .capsule)
                                .onTapGesture { showWeather = true }
                            }

                            // Countdown tile — tap for the voyage progress
                            if let info = countdown {
                                HStack(spacing: 6) {
                                    Image(systemName: info.icon)
                                    Text(info.message)
                                }
                                .font(.custom("NY", size: isRegular ? 18 : 14))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.oceanInk)
                                .padding(.vertical, 10)
                                .frame(width: contentWidth * 0.92)
                                .glassEffect(.regular.tint(.teal.opacity(0.45)).interactive(), in: .capsule)
                                .onTapGesture { showProgress = true }
                            }
//
//                            MapView(coordinate: CLLocationCoordinate2D(
//                                latitude: estimatedCoordinates.latitude,
//                                longitude: estimatedCoordinates.longitude))
//                                .frame(width: contentWidth, height: mapHeight)
//                                .clipShape(RoundedRectangle(cornerRadius: 17))
//                                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
//                                .overlay(alignment: .bottomTrailing) {
//                                    Button {
//                                        let c = estimatedCoordinates
//                                        if let url = URL(string: "maps://?daddr=\(c.latitude),\(c.longitude)"),
//                                           UIApplication.shared.canOpenURL(url) {
//                                            UIApplication.shared.open(url)
//                                        }
//                                    } label: {
//                                        Label("Maps", systemImage: "arrow.triangle.turn.up.right.circle.fill")
//                                            .font(.caption)
//                                            .padding(.horizontal, 10)
//                                            .padding(.vertical, 6)
//                                    }
//                                    .buttonStyle(.glass)
//                                    .padding(8)
//                                }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }
                }
            }
        }
    }

    // MARK: - Tap-through sheets

    /// Tap on "current time on board": the time-zone story.
    private var timeInfoSheet: some View {
        ZStack {
            OceanBackground()
            VStack(spacing: 14) {
                Text("Ship's clock")
                    .font(.custom("NY", size: 24)).fontWeight(.bold)

                Text(shipTimeString ?? "--:--")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text("Where you are, it's \(Self.viewerClock.string(from: .now))")
                    .font(.custom("NY", size: 16))

                Text(timeDifferenceSentence)
                    .font(.custom("NY", size: 14))
                    .opacity(0.75)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .foregroundStyle(Color.oceanInk)
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture { showTimeInfo = false }
        .overlay(alignment: .topTrailing) {
            dismissCheck { showTimeInfo = false }
        }
    }

    /// Teal checkmark in the sheet's top-right corner — the HIG's home for
    /// affirmative dismissal. (Tapping anywhere on the sheet also closes it.)
    private func dismissCheck(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.headline)
                .padding(10)
        }
        .buttonStyle(.glassProminent)
        .tint(.teal)
        .padding(14)
    }

    private static let viewerClock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private var timeDifferenceSentence: String {
        // Same offset that drives the big clock — including sea-day drift —
        // so the sentence can never contradict the numbers above it.
        guard let offset = shipOffsetHours else { return "" }
        let shipMin = offset * 60
        let viewerMin = TimeZone.current.secondsFromGMT() / 60
        let diff = shipMin - viewerMin
        if diff == 0 { return "The ship's clocks match yours exactly." }
        let h = abs(diff) / 60, m = abs(diff) % 60
        let span = m == 0 ? "\(h) hour\(h == 1 ? "" : "s")" : "\(h) h \(m) min"
        let direction = diff > 0 ? "ahead of" : "behind"
        return "The ship's clocks are \(span) \(direction) yours. Ships adjust their clocks overnight as they sail between time zones."
    }

    /// Tap on the weather capsule: the full conditions at the ship's position.
    private var weatherSheet: some View {
        ZStack {
            OceanBackground()
            VStack(spacing: 12) {
                Text(currentFinding.map { $0.isAtSea ? "Weather at sea" : "Weather in \($0.location)" }
                     ?? "Weather at the ship")
                    .font(.custom("NY", size: 24)).fontWeight(.bold)

                if let info = weatherService.weatherInfo {
                    Image(systemName: info.icon)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 56))

                    if let temp = weatherService.temperature {
                        Text("\(String(format: "%.0f", temp))°")
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                    }

                    Text(info.description)
                        .font(.custom("NY", size: 18))

                    HStack(spacing: 22) {
                        if let feels = weatherService.apparentTemperature {
                            weatherFact(icon: "thermometer.medium",
                                        value: "\(String(format: "%.0f", feels))°",
                                        label: "feels like")
                        }
                        if let wind = weatherService.windSpeed {
                            weatherFact(icon: "wind",
                                        value: "\(String(format: "%.0f", wind)) km/h",
                                        label: "wind")
                        }
                        if let humidity = weatherService.humidity {
                            weatherFact(icon: "humidity.fill",
                                        value: "\(humidity) %",
                                        label: "humidity")
                        }
                    }
                    .padding(.top, 6)
                } else {
                    ProgressView().padding(.vertical, 30)
                }
            }
            .foregroundStyle(Color.oceanInk)
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture { showWeather = false }
        .overlay(alignment: .topTrailing) {
            dismissCheck { showWeather = false }
        }
    }

    private func weatherFact(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).symbolRenderingMode(.multicolor)
            Text(value).font(.custom("NY", size: 15)).fontWeight(.semibold)
            Text(label).font(.caption2).opacity(0.65)
        }
    }

    /// Tap on the countdown: the voyage progress.
    private var progressSheet: some View {
        let cal = Calendar.current
        let start = cal.startOfDay(for: crewSetup.embarkDate)
        let end = cal.startOfDay(for: crewSetup.disembarkDate)
        let today = cal.startOfDay(for: .now)
        let totalDays = max(1, (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        let dayNumber = min(max(0, (cal.dateComponents([.day], from: start, to: today).day ?? 0) + 1), totalDays)
        let fraction = phase == .beforeEmbark ? 0.0
            : phase == .afterDisembark ? 1.0
            : Double(dayNumber) / Double(totalDays)

        return ZStack {
            OceanBackground()
            VStack(spacing: 16) {
                Text(crewSetup.isGuest ? "Your cruise" : "\(name)'s voyage")
                    .font(.custom("NY", size: 24)).fontWeight(.bold)

                Text("\(Self.mediumDate.string(from: crewSetup.embarkDate))  –  \(Self.mediumDate.string(from: crewSetup.disembarkDate))")
                    .font(.custom("NY", size: 15))

                ProgressView(value: fraction)
                    .tint(.teal)
                    .padding(.horizontal, 36)

                Group {
                    switch phase {
                    case .beforeEmbark:
                        let days = cal.dateComponents([.day], from: today, to: start).day ?? 0
                        Text("Sets sail in \(days) day\(days == 1 ? "" : "s")")
                    case .aboard:
                        let left = totalDays - dayNumber
                        Text("Day \(dayNumber) of \(totalDays)  ·  \(left) day\(left == 1 ? "" : "s") to go")
                    case .afterDisembark:
                        Text("Voyage complete — welcome home! 🎉")
                    }
                }
                .font(.custom("NY", size: 17))
                .fontWeight(.semibold)
            }
            .foregroundStyle(Color.oceanInk)
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture { showProgress = false }
        .overlay(alignment: .topTrailing) {
            dismissCheck { showProgress = false }
        }
    }

    // MARK: - At-home screen (before embarkation / after disembarkation)

    @ViewBuilder
    private var homeView: some View {
        let departurePort = fleetData.findings.first
        ScrollView {
            GlassEffectContainer(spacing: 22) {
                VStack(spacing: 18) {
                    Image(systemName: phase == .afterDisembark ? "house.and.flag.fill" : "house.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.oceanInk)
                        .frame(width: 120, height: 120)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .padding(.top, 30)

                    Text(homeTitle)
                        .font(.custom("NY", size: 30))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.oceanInk)
                        .multilineTextAlignment(.center)

                    if let info = countdown {
                        HStack(spacing: 8) {
                            Image(systemName: info.icon)
                            Text(info.message)
                        }
                        .font(.custom("NY", size: 19))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.oceanInk)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .glassEffect(.regular.tint(.teal.opacity(0.45)).interactive(), in: .capsule)
                    }

                    if phase == .beforeEmbark, let dep = departurePort {
                        VStack(spacing: 4) {
                            Text(crewSetup.isGuest ? "Sailing from" : "\(name) sets sail from")
                                .font(.footnote)
                                .foregroundStyle(Color.oceanInk.opacity(0.8))
                            Text(dep.location)
                                .font(.custom("NY", size: 22))
                                .foregroundStyle(Color.oceanInk)
                            Text(Self.mediumDate.string(from: crewSetup.embarkDate))
                                .font(.callout)
                                .foregroundStyle(Color.oceanInk.opacity(0.85))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(maxWidth: 320)
                        .glassEffect(.regular, in: .rect(cornerRadius: 18))
                    }

                    Text(homeSubtitle)
                        .font(.callout)
                        .foregroundStyle(Color.oceanInk.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 40)
            }
        }
    }

    private var homeTitle: String {
        if phase == .afterDisembark {
            return crewSetup.isGuest ? "Welcome home 🎉" : "\(name) is back home 🎉"
        }
        return crewSetup.isGuest ? "Your voyage awaits" : "\(name) is still at home"
    }

    private var homeSubtitle: String {
        if phase == .afterDisembark {
            return crewSetup.isGuest ? "We hope you had a wonderful voyage." : "Home safe — enjoy the time together."
        }
        return crewSetup.isGuest ? "Counting down to your departure." : "Treasure the days before the next voyage."
    }

    private func getTheDay() {
        if let index = fleetData.findings.firstIndex(where: { $0.OnThisDay == todayFormatted }) {
            currentIndex = index
        } else if let embarkDate = fleetData.findings.first,
                  let today = Self.dayFormatter.date(from: todayFormatted),
                  let firstDate = Self.dayFormatter.date(from: embarkDate.OnThisDay),
                  today < firstDate {
            currentIndex = 0
        } else {
            currentIndex = max(0, fleetData.findings.count - 1)
        }
    }
}

// MARK: - Previews
// TodayView needs all four environment objects, plus a CrewSetup whose dates
// actually cover today — otherwise you'd only ever preview the home screen.

#Preview("Aboard") {
    let setup = CrewSetup()
    let fleet = FleetData()
    setup.configureGuest(
        ship: AidaShip.aidasol.rawValue,
        embark: Calendar.current.date(byAdding: .day, value: -7, to: .now)!,
        disembark: Calendar.current.date(byAdding: .day, value: 60, to: .now)!
    )
    fleet.apply(setup)
    return TodayView()
        .environment(fleet)
        .environment(setup)
        .environment(WeatherService())
        .environment(WikipediaImageLoader())
}

#Preview("At home") {
    let setup = CrewSetup()
    let fleet = FleetData()
    setup.configureGuest(
        ship: AidaShip.aidasol.rawValue,
        embark: Calendar.current.date(byAdding: .day, value: 12, to: .now)!,
        disembark: Calendar.current.date(byAdding: .day, value: 120, to: .now)!
    )
    fleet.apply(setup)
    return TodayView()
        .environment(fleet)
        .environment(setup)
        .environment(WeatherService())
        .environment(WikipediaImageLoader())
}
