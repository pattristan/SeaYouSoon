//
//  FollowersView.swift
//  Sea you soon
//
//  Crew mode: who is following me — with Revoke, and a short one-way message
//  to a single follower. A message in a bottle, not a chat app; no groups.
//  Gated by Crew Deck sign-in (username + PIN): messaging speaks AS a person,
//  so the self-declared crew toggle is not enough here.
//

import SwiftUI

struct FollowersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CrewSetup.self) private var crewSetup

    /// Remembered locally so the header can greet; the session cookie itself
    /// lives in URLSession's cookie storage (~14 days).
    @AppStorage("crewDeckName") private var crewDeckName = ""

    @State private var followers: [Follower]?
    @State private var needsLogin = false
    @State private var username = ""
    @State private var pin = ""
    @State private var busy = false
    @State private var errorMessage: String?

    @State private var composeFor: Follower?
    @State private var messageText = ""
    @State private var justSentTo: String?
    @State private var revokeCandidate: Follower?
    @State private var invite: InviteCode?
    @State private var inviteFor = ""
    @State private var generating = false

    var body: some View {
        NavigationStack {
            ZStack {
                OceanBackground()
                ScrollView {
                    GlassEffectContainer(spacing: 22) {
                        VStack(spacing: 16) {
                            if needsLogin {
                                loginForm
                            } else if let followers {
                                followerList(followers)
                            } else {
                                ProgressView().padding(.top, 60)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("My followers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.oceanInk)
                }
            }
            .task { await load() }
            .alert("Stop sharing with \(revokeCandidate?.watcherName ?? "")?",
                   isPresented: Binding(get: { revokeCandidate != nil },
                                        set: { if !$0 { revokeCandidate = nil } })) {
                Button("Remove", role: .destructive) {
                    if let f = revokeCandidate { Task { await revoke(f) } }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("They will no longer see your voyage. You can invite them again with a new code.")
            }
        }
    }

    // MARK: - Login gate

    private var loginForm: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.oceanInk)
                .frame(width: 90, height: 90)
                .glassEffect(.regular.interactive(), in: .circle)

            Text("Sign in to Crew Deck")
                .font(.heading(size: 24)).fontWeight(.bold)
                .foregroundStyle(Color.oceanInk)

            Text("Messages are sent in your name, so this needs your Crew Deck account — the same username and PIN as the website.")
                .font(.newYork(size: 13))
                .foregroundStyle(Color.oceanInk.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            glassField(icon: "person.fill") {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            glassField(icon: "key.fill") {
                SecureField("PIN", text: $pin)
                    .keyboardType(.numberPad)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .glassEffect(.regular.tint(.red.opacity(0.55)), in: .rect(cornerRadius: 16))
            }

            Button {
                Task { await signIn() }
            } label: {
                HStack {
                    if busy { ProgressView().tint(.white) }
                    else { Text("Sign in").fontWeight(.semibold) }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent).tint(.teal)
            .disabled(username.isEmpty || pin.isEmpty || busy)
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Follower list

    @ViewBuilder
    private func followerList(_ list: [Follower]) -> some View {
        if !crewDeckName.isEmpty {
            Text("Signed in as \(crewDeckName)")
                .font(.footnote)
                .foregroundStyle(Color.oceanInk.opacity(0.6))
        }

        inviteCard

        if list.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "person.2.slash")
                    .font(.largeTitle)
                    .foregroundStyle(Color.oceanInk.opacity(0.6))
                Text("Nobody is following you yet.")
                    .font(.newYork(size: 15))
                    .foregroundStyle(Color.oceanInk)
                Text("Create an invitation code above and send it to someone at home.")
                    .font(.footnote)
                    .foregroundStyle(Color.oceanInk.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 30)
        }

        ForEach(list) { follower in
            followerCard(follower)
        }
    }

    // MARK: - Invitation code

    /// Mint-and-share: each code invites exactly one person, valid 7 days.
    private var inviteCard: some View {
        VStack(spacing: 12) {
            if let invite {
                Text(invite.code)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.oceanInk)
                    .textSelection(.enabled)
                Text("Works once · expires \(String(invite.expiresAt.prefix(10)))")
                    .font(.footnote)
                    .foregroundStyle(Color.oceanInk.opacity(0.6))
                ShareLink(item: shareText(for: invite)) {
                    Label("Send to a loved one", systemImage: "square.and.arrow.up")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent).tint(.pink.opacity(0.7))
                .padding(.horizontal, 12)
            } else {
                // The name only personalises the message — nothing is stored.
                HStack(spacing: 10) {
                    Image(systemName: "heart")
                        .foregroundStyle(Color.oceanInk.opacity(0.7))
                    TextField("Who is it for? e.g. Maria (optional)", text: $inviteFor)
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(Color.oceanInk)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                .padding(.horizontal, 12)

                Button {
                    Task { await generateInvite() }
                } label: {
                    HStack {
                        if generating { ProgressView().tint(.white) }
                        else {
                            Label("Invite someone — new code", systemImage: "plus.circle.fill")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent).tint(.teal)
                .disabled(generating)
                .padding(.horizontal, 12)
            }
            if !needsLogin, let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .glassEffect(.regular.tint(.red.opacity(0.55)), in: .rect(cornerRadius: 12))
            }
        }
        .padding(.vertical, invite == nil ? 4 : 14)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    private func shareText(for invite: InviteCode) -> String {
        let recipient = inviteFor.trimmingCharacters(in: .whitespaces)
        let greeting = recipient.isEmpty ? "Hello!" : "Hello \(recipient)!"
        let sender = crewDeckName.isEmpty ? "Someone who loves you" : crewDeckName
        let aboard = crewSetup.shipName.isEmpty ? "" : " aboard \(crewSetup.shipName)"
        return """
        \(greeting) \(sender) has invited you to follow their tour of duty\(aboard) 💙
        If you don't have the app yet, download “Sea You Soon” from the App Store.
        Your invitation code: \(invite.code)
        Or just tap: \(invite.link)
        (works once, valid 7 days)
        """
    }

    private func followerCard(_ follower: Follower) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink.opacity(0.8))
                Text(follower.watcherName)
                    .font(.heading(size: 18)).fontWeight(.semibold)
                Spacer()
                if justSentTo == follower.watchId {
                    Label("Sent", systemImage: "checkmark")
                        .font(.footnote).fontWeight(.semibold)
                        .foregroundStyle(.teal)
                } else {
                    Button {
                        withAnimation(.spring(duration: 0.35)) {
                            composeFor = composeFor?.watchId == follower.watchId ? nil : follower
                            messageText = ""
                        }
                    } label: {
                        Image(systemName: "envelope")
                            .padding(8)
                    }
                    .buttonStyle(.glass)
                    Button {
                        revokeCandidate = follower
                    } label: {
                        Image(systemName: "xmark")
                            .padding(8)
                    }
                    .buttonStyle(.glass)
                    .tint(.red)
                }
            }
            .foregroundStyle(Color.oceanInk)

            if composeFor?.watchId == follower.watchId {
                HStack(spacing: 10) {
                    TextField("A short message to \(follower.watcherName)…",
                              text: $messageText, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.newYork(size: 15))
                        .foregroundStyle(Color.oceanInk)
                    Button {
                        Task { await send(to: follower) }
                    } label: {
                        Image(systemName: "paperplane.fill").padding(6)
                    }
                    .buttonStyle(.glassProminent).tint(.teal)
                    .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    // MARK: - Field helper

    private func glassField(icon: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.oceanInk.opacity(0.8)).frame(width: 24)
            content().foregroundStyle(Color.oceanInk)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    // MARK: - Actions

    private func load() async {
        do {
            followers = try await CrewDeck.followers()
            needsLogin = false
        } catch {
            needsLogin = true
        }
    }

    private func signIn() async {
        busy = true
        errorMessage = nil
        defer { busy = false }
        do {
            let info = try await CrewDeck.login(
                username: username.trimmingCharacters(in: .whitespaces),
                pin: pin.trimmingCharacters(in: .whitespaces))
            crewDeckName = info.name
            withAnimation { needsLogin = false }
            await load()
        } catch {
            errorMessage = (error as? CrewDeckError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func send(to follower: Follower) async {
        busy = true
        defer { busy = false }
        do {
            try await CrewDeck.send(watchId: follower.watchId,
                                    body: messageText.trimmingCharacters(in: .whitespaces))
            withAnimation(.spring(duration: 0.35)) {
                composeFor = nil
                justSentTo = follower.watchId
            }
            try? await Task.sleep(for: .seconds(2))
            withAnimation { justSentTo = nil }
        } catch {
            errorMessage = (error as? CrewDeckError)?.errorDescription
            if case .notSignedIn = error as? CrewDeckError { needsLogin = true }
        }
    }

    private func generateInvite() async {
        generating = true
        defer { generating = false }
        do {
            let new = try await CrewDeck.generateCode()
            withAnimation(.spring(duration: 0.35)) { invite = new }
        } catch {
            errorMessage = (error as? CrewDeckError)?.errorDescription
            if case .notSignedIn = error as? CrewDeckError { needsLogin = true }
        }
    }

    private func revoke(_ follower: Follower) async {
        try? await CrewDeck.revoke(watchId: follower.watchId)
        revokeCandidate = nil
        await load()
    }
}

#Preview {
    FollowersView()
        .environment(CrewSetup())
}
