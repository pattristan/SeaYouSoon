//
//  SettingsView.swift
//  Sea you soon
//
//  Shown from the ⚙️ button once set up: who/what you're following, and a way
//  to stop. Handles both family (a person) and guest (a ship) modes.
//

import SwiftUI

struct SettingsView: View {
    @Environment(CrewSetup.self) var crewSetup
    @Environment(FleetData.self) var fleetData
    @Environment(\.dismiss) private var dismiss

    /// Some seafarers on long contracts would rather not see "260 days to go".
    @AppStorage("showCountdown") private var showCountdown = true

    // "Change ship" (guest mode): prefilled with the current setup on open.
    @State private var showChangeShip = false
    @State private var showFollowers = false
    @State private var newShip = AidaShip.aidasol.rawValue
    @State private var newEmbark = Date.now
    @State private var newDisembark = Date.now

    var body: some View {
        NavigationStack {
            ZStack {
                OceanBackground()
                ScrollView {
                    GlassEffectContainer(spacing: 24) {
                        VStack(spacing: 18) {
                            Group {
                                if crewSetup.isGuest {
                                    CruiseLinerIcon()
                                        .frame(height: 40)
                                } else {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 40))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(width: 90, height: 90)
                            .glassEffect(.regular.tint((crewSetup.isGuest ? Color.teal : .pink).opacity(0.45)).interactive(), in: .circle)

                            Text(crewSetup.isGuest ? "You're watching" : "You're following")
                                .font(.callout).foregroundStyle(Color.oceanInk.opacity(0.8))

                            Text(crewSetup.isGuest ? crewSetup.shipName : crewSetup.crewName)
                                .font(.heading(size: 34)).fontWeight(.bold)
                                .foregroundStyle(Color.oceanInk)

                            VStack(spacing: 0) {
                                if !crewSetup.isGuest {
                                    statusRow(icon: "ferry.fill", label: "Ship", value: crewSetup.shipName)
                                    Divider().overlay(Color.oceanInk.opacity(0.2))
                                }
                                statusRow(icon: "calendar",
                                          label: crewSetup.isGuest ? "Cruise" : "On board",
                                          value: dateRangeText)
                            }
                            .glassEffect(.regular, in: .rect(cornerRadius: 20))
                            .padding(.horizontal, 4)

                            Toggle(isOn: $showCountdown) {
                                Label("Show days remaining", systemImage: "calendar.badge.clock")
                                    .foregroundStyle(Color.oceanInk)
                            }
                            .tint(.teal)
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))
                            .padding(.horizontal, 4)

                            // Crew self-declaration: unlocks berth/tender/clock info.
                            if crewSetup.isGuest {
                                @Bindable var crewSetup = crewSetup
                                Toggle(isOn: $crewSetup.isCrew) {
                                    Label("I am working aboard this ship", systemImage: "person.badge.shield.checkmark")
                                        .foregroundStyle(Color.oceanInk)
                                }
                                .tint(.teal)
                                .padding(.horizontal, 18).padding(.vertical, 12)
                                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                                .padding(.horizontal, 4)
                            }

                            // Followers & one-way messages (Crew Deck sign-in inside —
                            // messaging speaks AS a person, the toggle isn't enough).
                            if crewSetup.isGuest && crewSetup.isCrew {
                                Button {
                                    showFollowers = true
                                } label: {
                                    Label("My followers & messages", systemImage: "heart.text.square")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                                }
                                .buttonStyle(.glassProminent).tint(.pink.opacity(0.7))
                                .padding(.horizontal, 24)
                            }

                            // Switch/peek at another ship without starting over.
                            // Guests change ship; family peek out of curiosity —
                            // the pairing survives, a chip offers the way back.
                            if showChangeShip {
                                changeShipCard
                            } else {
                                Button {
                                    newShip = crewSetup.shipName
                                    newEmbark = crewSetup.embarkDate
                                    newDisembark = crewSetup.disembarkDate
                                    withAnimation(.spring(duration: 0.4)) { showChangeShip = true }
                                } label: {
                                    Label(crewSetup.isGuest ? "Change ship" : "Quick look at another ship",
                                          systemImage: crewSetup.isGuest ? "arrow.triangle.2.circlepath" : "binoculars.fill")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                                }
                                .buttonStyle(.glassProminent).tint(.teal)
                                .padding(.horizontal, 24).padding(.top, 8)
                            }

                            Button(role: .destructive) {
                                crewSetup.unpair()
                                fleetData.apply(crewSetup)
                                dismiss()
                            } label: {
                                Text(crewSetup.isGuest ? "Stop watching" : "Stop following")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                            }
                            .buttonStyle(.glassProminent).tint(.red.opacity(0.8))
                            .padding(.horizontal, 24).padding(.top, 8)

                            Text(crewSetup.isGuest
                                 ? "You can follow a different ship anytime."
                                 : "You can pair again anytime with a new code.")
                                .font(.footnote).foregroundStyle(Color.oceanInk.opacity(0.6))
                        }
                        .padding(.horizontal, 20).padding(.top, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFollowers) { FollowersView() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.oceanInk)
                }
            }
        }
    }

    /// Inline ship/date switcher — apply lands straight on the new route.
    private var changeShipCard: some View {
        VStack(spacing: 12) {
            Menu {
                ForEach(AidaShip.names, id: \.self) { ship in
                    Button(ship) { newShip = ship }
                }
            } label: {
                HStack(spacing: 12) {
                    CruiseLinerIcon()
                        .frame(height: 14)
                        .foregroundStyle(Color.oceanInk.opacity(0.8))
                    Text(newShip).foregroundStyle(Color.oceanInk)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(Color.oceanInk.opacity(0.6))
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }

            Divider().overlay(Color.oceanInk.opacity(0.2))

            DatePicker("From", selection: $newEmbark, displayedComponents: .date)
                .padding(.horizontal, 14)
            DatePicker("Until", selection: $newDisembark, in: newEmbark..., displayedComponents: .date)
                .padding(.horizontal, 14)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(duration: 0.4)) { showChangeShip = false }
                } label: {
                    Text("Cancel").frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.glass)

                Button {
                    if crewSetup.isGuest {
                        crewSetup.configureGuest(ship: newShip, embark: newEmbark, disembark: newDisembark)
                    } else {
                        crewSetup.peekAtShip(ship: newShip, embark: newEmbark, disembark: newDisembark)
                    }
                    fleetData.apply(crewSetup)
                    dismiss()
                } label: {
                    Text("Show this route").fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent).tint(.teal)
                .disabled(newDisembark < newEmbark)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .foregroundStyle(Color.oceanInk)
        .tint(.teal)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .padding(.horizontal, 4)
    }

    private func statusRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon).foregroundStyle(Color.oceanInk.opacity(0.8))
            Spacer()
            Text(value).fontWeight(.medium).foregroundStyle(Color.oceanInk)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }

    private var dateRangeText: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return "\(f.string(from: crewSetup.embarkDate)) – \(f.string(from: crewSetup.disembarkDate))"
    }
}

#Preview {
    SettingsView()
        .environment(CrewSetup())
        .environment(FleetData())
}
