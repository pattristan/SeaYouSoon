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

    private enum Mode { case family, guest }
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

    @State private var floatIcon = false
    @Namespace private var glassNamespace

    var body: some View {
        NavigationStack {
            ZStack {
                OceanBackground()
                switch mode {
                case .none:    chooser
                case .family:  familyForm
                case .guest:   guestForm
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
                Image(systemName: "ferry.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.oceanInk)
                    .frame(width: 96, height: 96)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .offset(y: floatIcon ? -6 : 6)

                Text("Sea You Soon")
                    .font(.heading(size: 34)).fontWeight(.bold)
                    .foregroundStyle(Color.oceanInk)
                Text("Follow a voyage around the world")
                    .font(.callout).foregroundStyle(Color.oceanInk.opacity(0.85))
                    .padding(.bottom, 12)

                choiceCard(
                    tint: .pink,
                    title: "Follow someone",
                    subtitle: "A loved one sent you a code",
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

                    Text("Scan the QR your seafarer shows you — or type the code they sent. Each code works once.\n\nA code is their personal invitation: your seafarer always knows who's following and can stop sharing at any time.")
                        .font(.footnote).foregroundStyle(Color.oceanInk.opacity(0.7))
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

    // MARK: - Guest (ship) form

    private var guestForm: some View {
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
                    dateTile(icon: "calendar.badge.checkmark", label: "Until", selection: $guestDisembark, range: guestEmbark...)

                    Text("You'll see this ship's public itinerary — where it is today and tomorrow.")
                        .font(.footnote).foregroundStyle(Color.oceanInk.opacity(0.7))
                        .multilineTextAlignment(.center).padding(.horizontal, 24)

                    Button {
                        withAnimation {
                            crewSetup.configureGuest(ship: guestShip, embark: guestEmbark, disembark: guestDisembark)
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
