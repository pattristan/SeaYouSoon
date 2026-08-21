//
//  SetupView.swift
//  Sea you soon
//
//  First-run onboarding. Two paths:
//   • Follow someone (family) — redeem a pairing code the seafarer sent. The
//     code supplies the person, ship and dates; consent-safe.
//   • Follow a ship (guest)   — pick any AIDA ship + dates and watch its public
//     itinerary. No person, no code.
//
//  Liquid Glass throughout, over the shared ocean backdrop.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(CrewSetup.self) var crewSetup
    @Environment(FleetData.self) var fleetData

    private enum Mode { case family, guest, crew }
    @State private var mode: Mode?

    // Family (code) state
    @State private var watcherName = ""
    @State private var code = ""
    @State private var isRedeeming = false
    @State private var errorMessage: String?

    // Guest (ship) state
    @State private var guestShip = AidaShip.aidasol.rawValue
    @State private var guestEmbark = Date.now
    @State private var guestDisembark = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

    // Crew (register / sign in) state
    @State private var crewName = ""
    @State private var crewUsername = ""
    @State private var crewPin = ""
    @State private var crewSigningIn = false
    @State private var crewBusy = false
    @State private var crewError: String?
    @State private var registeredName: String?   // non-nil → success step
    @State private var showInviteSheet = false

    @State private var floatIcon = false
    @Namespace private var glassNamespace

    var body: some View {
        NavigationStack {
            ZStack {
                OceanBackground()
                switch mode {
                case .none:    chooser
                case .family:  familyForm
                case .guest:   shipForm(crew: false)
                case .crew:    crewFlow
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if mode != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(duration: 0.4)) { mode = nil; errorMessage = nil }
                        } label: { Image(systemName: "chevron.left") }
                        .foregroundStyle(Color.oceanInk)
                    }
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { floatIcon = true }
                consumePendingCode()
            }
            .onChange(of: crewSetup.pendingRedeemCode) { consumePendingCode() }
        }
    }

    /// A code arriving via QR/deep link jumps straight to the family form, prefilled.
    private func consumePendingCode() {
        guard let pending = crewSetup.pendingRedeemCode else { return }
        crewSetup.pendingRedeemCode = nil
        withAnimation(.spring(duration: 0.4)) {
            mode = .family
            code = pending
            errorMessage = nil
        }
    }

    // MARK: - Chooser

    private var chooser: some View {
        GlassEffectContainer(spacing: 24) {
            VStack(spacing: 18) {
                CruiseLinerIcon()
                    .font(.system(size: 44))
                    .foregroundStyle(Color.oceanInk)
                    .frame(width: 96, height: 96)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .offset(y: floatIcon ? -6 : 6)

                Text("Sea You Soon")
                    .font(.heading(size: 34)).fontWeight(.bold)
                    .foregroundStyle(Color.oceanInk)
                Text("Follow a voyage around the world — or share your own")
                    .font(.callout).foregroundStyle(Color.oceanInk.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)

                choiceCard(
                    tint: .indigo,
                    title: "I'm a seafarer",
                    subtitle: "Follow my own tour & share it with loved ones",
                    action: {
                        // Contract dates, not holiday dates: default to a
                        // typical four-month tour so the picker starts close.
                        guestEmbark = .now
                        guestDisembark = Calendar.current.date(byAdding: .month, value: 4, to: .now) ?? .now
                        withAnimation(.spring(duration: 0.4)) { mode = .crew }
                    }
                ) {
                    Image(systemName: "person.badge.shield.checkmark.fill").font(.title3)
                }
                choiceCard(
                    tint: .pink,
                    title: "I've been invited",
                    subtitle: "Follow a loved one with their code",
                    action: { withAnimation(.spring(duration: 0.4)) { mode = .family } }
                ) {
                    Image(systemName: "heart.fill").font(.title2)
                }
                choiceCard(
                    tint: .teal,
                    title: "Follow a ship",
                    subtitle: "Track any AIDA ship's voyage",
                    action: { withAnimation(.spring(duration: 0.4)) { mode = .guest } }
                ) {
                    CruiseLinerIcon().frame(height: 18)
                }

                Text("No account, no sign-up, nothing to allow. The app only knows the ships' schedules — never where you are.")
                    .font(.footnote).foregroundStyle(Color.oceanInk.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24).padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 50)
        }
    }

    private func choiceCard(tint: Color, title: String, subtitle: String,
                            action: @escaping () -> Void,
                            @ViewBuilder icon: () -> some View) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                icon()
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.tint(tint.opacity(0.5)), in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(Color.oceanInk)
                    Text(subtitle).font(.footnote).foregroundStyle(Color.oceanInk.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.oceanInk.opacity(0.6))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
    }

    // MARK: - Family (code) form

    private var familyForm: some View {
        ScrollView {
            GlassEffectContainer(spacing: 24) {
                VStack(spacing: 18) {
                    Text("Follow someone")
                        .font(.heading(size: 30)).fontWeight(.bold)
                        .foregroundStyle(Color.oceanInk).padding(.top, 20)

                    glassField(icon: "person.fill", id: "name") {
                        TextField("Your name", text: $watcherName, prompt: prompt("Your name"))
                            .textInputAutocapitalization(.words)
                            .textContentType(.name)
                    }
                    glassField(icon: "key.fill", id: "code") {
                        TextField("Pairing code", text: $code, prompt: prompt("Pairing code  ·  e.g. SOL-7X4K9"))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                    }

                    Text("Scan the QR your seafarer shows you — or type the code they sent. Each code works once.\n\nA code is their personal invitation: your seafarer always knows who's following and can stop sharing at any time. They'll also see your local time, so they know when you're likely awake.")
                        .font(.footnote).foregroundStyle(Color.oceanInk.opacity(0.7))
                        .multilineTextAlignment(.center).padding(.horizontal, 24)

                    Text("No code yet? Ask them for one — it takes a minute on crew.oconnell-connect.com. Until then, you can still follow their ship from the previous screen.")
                        .font(.footnote).foregroundStyle(Color.oceanInk.opacity(0.55))
                        .multilineTextAlignment(.center).padding(.horizontal, 24)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout).foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .glassEffect(.regular.tint(.red.opacity(0.55)), in: .rect(cornerRadius: 16))
                            .glassEffectID("error", in: glassNamespace)
                    }

                    Button {
                        Task { await redeem() }
                    } label: {
                        HStack {
                            if isRedeeming { ProgressView().tint(.white) }
                            else { Text("Start following").fontWeight(.semibold) }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent).tint(.teal)
                    .disabled(!canRedeem)
                    .padding(.horizontal, 24).padding(.top, 4)

                    #if DEBUG
                    demoCodes
                    #endif
                }
                .padding(.horizontal, 20).padding(.bottom, 30)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var canRedeem: Bool {
        !watcherName.trimmingCharacters(in: .whitespaces).isEmpty
            && !code.trimmingCharacters(in: .whitespaces).isEmpty
            && !isRedeeming
    }

    // MARK: - Ship form (guest)

    private func shipForm(crew: Bool) -> some View {
        ScrollView {
            GlassEffectContainer(spacing: 24) {
                VStack(spacing: 18) {
                    Text("Follow a ship")
                        .font(.heading(size: 30)).fontWeight(.bold)
                        .foregroundStyle(Color.oceanInk).padding(.top, 20)

                    // Ship picker tile
                    Menu {
                        ForEach(AidaShip.names, id: \.self) { ship in
                            Button(ship) { guestShip = ship }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            CruiseLinerIcon().frame(height: 14).foregroundStyle(Color.oceanInk.opacity(0.8))
                            Text(guestShip).foregroundStyle(Color.oceanInk)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").foregroundStyle(Color.oceanInk.opacity(0.6))
                        }
                        .padding(.horizontal, 18).padding(.vertical, 15)
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    .padding(.horizontal, 4)

                    dateTile(icon: "calendar", label: "From", selection: $guestEmbark, range: nil)
                    dateTile(icon: "calendar.badge.checkmark", label: "Until",
                             selection: $guestDisembark, range: guestEmbark...)

                    Text("You'll see this ship's public itinerary — where it is today and tomorrow.")
                        .font(.footnote).foregroundStyle(Color.oceanInk.opacity(0.7))
                        .multilineTextAlignment(.center).padding(.horizontal, 24)

                    Button {
                        withAnimation {
                            crewSetup.configureGuest(ship: guestShip, embark: guestEmbark, disembark: guestDisembark)
                            crewSetup.isCrew = false
                            fleetData.apply(crewSetup)
                        }
                    } label: {
                        Text("Start watching").fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent).tint(.teal)
                    .disabled(guestDisembark < guestEmbark)
                    .padding(.horizontal, 24).padding(.top, 4)
                }
                .padding(.horizontal, 20).padding(.bottom, 30)
            }
        }
    }

    // MARK: - Crew flow (register or sign in, then a success step)

    @ViewBuilder
    private var crewFlow: some View {
        if let registeredName {
            crewSuccess(name: registeredName)
        } else {
            crewForm
        }
    }

    private var crewForm: some View {
        ScrollView {
            GlassEffectContainer(spacing: 24) {
                VStack(spacing: 18) {
                    Text(crewSigningIn ? "Welcome back" : "Your ship & contract")
                        .font(.heading(size: 30)).fontWeight(.bold)
                        .foregroundStyle(Color.oceanInk).padding(.top, 20)

                    if !crewSigningIn {
                        glassField(icon: "person.fill", id: "crewname") {
                            TextField("Your name", text: $crewName, prompt: prompt("Your name"))
                                .textInputAutocapitalization(.words)
                                .textContentType(.name)
                        }

                        Menu {
                            ForEach(AidaShip.names, id: \.self) { ship in
                                Button(ship) { guestShip = ship }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                CruiseLinerIcon().frame(height: 14).foregroundStyle(Color.oceanInk.opacity(0.8))
                                Text(guestShip).foregroundStyle(Color.oceanInk)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").foregroundStyle(Color.oceanInk.opacity(0.6))
                            }
                            .padding(.horizontal, 18).padding(.vertical, 15)
                        }
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                        .padding(.horizontal, 4)

                        dateTile(icon: "calendar", label: "Embark", selection: $guestEmbark, range: nil)
                        dateTile(icon: "calendar.badge.checkmark", label: "Disembark",
                                 selection: $guestDisembark, range: guestEmbark...)
                    }

                    glassField(icon: "at", id: "crewuser") {
                        TextField("Username", text: $crewUsername, prompt: prompt("Choose a username"))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    glassField(icon: "key.fill", id: "crewpin") {
                        SecureField("PIN", text: $crewPin, prompt: prompt("PIN (at least 4 digits)"))
                            .keyboardType(.numberPad)
                    }

                    if let crewError {
                        Label(crewError, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout).foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .glassEffect(.regular.tint(.red.opacity(0.55)), in: .rect(cornerRadius: 16))
                    }

                    if !crewSigningIn {
                        Text("You'll get the crew view: planned berths, tender anchorages, clock changes and the Crew Portal — and you can invite loved ones to follow you.")
                            .font(.footnote).foregroundStyle(Color.oceanInk.opacity(0.7))
                            .multilineTextAlignment(.center).padding(.horizontal, 24)
                    }

                    Button {
                        Task { crewSigningIn ? await crewSignIn() : await crewRegister() }
                    } label: {
                        HStack {
                            if crewBusy { ProgressView().tint(.white) }
                            else { Text(crewSigningIn ? "Sign in" : "Start my voyage").fontWeight(.semibold) }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent).tint(.indigo)
                    .disabled(!canSubmitCrew)
                    .padding(.horizontal, 24).padding(.top, 4)

                    Button(crewSigningIn ? "New here? Create your account" : "Already registered? Sign in") {
                        withAnimation(.spring(duration: 0.4)) {
                            crewSigningIn.toggle()
                            crewError = nil
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.oceanInk.opacity(0.8))

                    Link(destination: URL(string: "https://crew.oconnell-connect.com")!) {
                        Label("Prefer the website? crew.oconnell-connect.com", systemImage: "safari")
                            .font(.footnote)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                    }
                    .buttonStyle(.glass).tint(.indigo)
                    .foregroundStyle(Color.oceanInk.opacity(0.8))
                }
                .padding(.horizontal, 20).padding(.bottom, 30)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var canSubmitCrew: Bool {
        let userOK = !crewUsername.trimmingCharacters(in: .whitespaces).isEmpty
        let pinOK = crewPin.trimmingCharacters(in: .whitespaces).count >= 4
        if crewSigningIn { return userOK && pinOK && !crewBusy }
        return userOK && pinOK && !crewBusy
            && !crewName.trimmingCharacters(in: .whitespaces).isEmpty
            && guestDisembark >= guestEmbark
    }

    /// The moment between "account created" and "show me my voyage": the one
    /// natural opening to invite someone at home, so we offer it right here.
    private func crewSuccess(name: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .glassEffect(.regular.tint(.teal.opacity(0.5)), in: .circle)

            Text("Welcome aboard, \(name.split(separator: " ").first.map(String.init) ?? name)!")
                .font(.heading(size: 28)).fontWeight(.bold)
                .foregroundStyle(Color.oceanInk)
                .multilineTextAlignment(.center)

            Text("Your Crew Deck account is ready. Invite someone at home now — or head straight to your voyage. Inviting is always one tap away in Settings.")
                .font(.newYork(size: 15)).foregroundStyle(Color.oceanInk.opacity(0.8))
                .multilineTextAlignment(.center).padding(.horizontal, 24)

            Button {
                showInviteSheet = true
            } label: {
                Label("Invite someone now", systemImage: "heart.text.square")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent).tint(.pink.opacity(0.7))
            .padding(.horizontal, 24)

            Button {
                withAnimation {
                    crewSetup.configureGuest(ship: guestShip, embark: guestEmbark, disembark: guestDisembark)
                    crewSetup.isCrew = true
                    fleetData.apply(crewSetup)
                }
            } label: {
                Text("Show my voyage").fontWeight(.semibold)
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent).tint(.indigo)
            .padding(.horizontal, 24)
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showInviteSheet) { FollowersView() }
    }

    private func crewRegister() async {
        crewBusy = true
        withAnimation { crewError = nil }
        defer { crewBusy = false }
        do {
            let info = try await CrewDeck.register(
                username: crewUsername.trimmingCharacters(in: .whitespaces),
                name: crewName.trimmingCharacters(in: .whitespaces),
                ship: guestShip, embark: guestEmbark, disembark: guestDisembark,
                pin: crewPin.trimmingCharacters(in: .whitespaces))
            UserDefaults.standard.set(info.name, forKey: "crewDeckName")
            // The invite sheet can open before configureGuest runs — make sure
            // the share text already names the right ship.
            crewSetup.shipName = guestShip
            withAnimation(.spring(duration: 0.4)) { registeredName = info.name }
        } catch {
            withAnimation {
                crewError = (error as? CrewDeckError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// Returning crew (e.g. a reinstall): the server still knows their ship
    /// and contract, so username + PIN restores everything.
    private func crewSignIn() async {
        crewBusy = true
        withAnimation { crewError = nil }
        defer { crewBusy = false }
        do {
            let info = try await CrewDeck.login(
                username: crewUsername.trimmingCharacters(in: .whitespaces),
                pin: crewPin.trimmingCharacters(in: .whitespaces))
            UserDefaults.standard.set(info.name, forKey: "crewDeckName")
            let iso = ISO8601DateFormatter()
            let embark = info.embarkDate.flatMap { iso.date(from: $0) } ?? guestEmbark
            let disembark = info.disembarkDate.flatMap { iso.date(from: $0) } ?? guestDisembark
            withAnimation {
                crewSetup.configureGuest(ship: info.ship, embark: embark, disembark: disembark)
                crewSetup.isCrew = true
                fleetData.apply(crewSetup)
            }
        } catch {
            withAnimation {
                crewError = (error as? CrewDeckError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func dateTile(icon: String, label: String, selection: Binding<Date>, range: PartialRangeFrom<Date>?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.oceanInk.opacity(0.8)).frame(width: 24)
            if let range {
                DatePicker(label, selection: selection, in: range, displayedComponents: .date)
                    .foregroundStyle(Color.oceanInk)
            } else {
                DatePicker(label, selection: selection, displayedComponents: .date)
                    .foregroundStyle(Color.oceanInk)
            }
        }
        .tint(.teal)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .padding(.horizontal, 4)
    }

    // MARK: - Shared helpers

    private func glassField(icon: String, id: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.oceanInk.opacity(0.8)).frame(width: 24)
            content().foregroundStyle(Color.oceanInk)
        }
        .padding(.horizontal, 18).padding(.vertical, 15)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .glassEffectID(id, in: glassNamespace)
        .padding(.horizontal, 4)
    }

    private func prompt(_ text: String) -> Text { Text(text).foregroundStyle(Color.oceanInk.opacity(0.5)) }

    #if DEBUG
    private var demoCodes: some View {
        VStack(spacing: 10) {
            Text("Demo codes").font(.caption).foregroundStyle(Color.oceanInk.opacity(0.6)).padding(.top, 12)
            HStack(spacing: 14) {
                ForEach(Array(MockPairingService.seededCodes.keys).sorted(), id: \.self) { key in
                    Button { withAnimation(.spring(duration: 0.4)) { code = key } } label: {
                        Text(key).font(.system(.callout, design: .monospaced)).fontWeight(.semibold)
                            .foregroundStyle(Color.oceanInk).padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
        }
    }
    #endif

    private func redeem() async {
        isRedeeming = true
        withAnimation(.spring(duration: 0.4)) { errorMessage = nil }
        defer { isRedeeming = false }
        do {
            let name = watcherName.trimmingCharacters(in: .whitespaces)
            let profile = try await Pairing.service.redeem(code: code, watcherName: name)
            crewSetup.configure(from: profile, watcherName: name)
            fleetData.apply(crewSetup)
        } catch {
            withAnimation(.spring(duration: 0.4)) {
                errorMessage = (error as? PairingError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(CrewSetup())
        .environment(FleetData())
}
