//
//  ReturnShipChip.swift
//  Sea you soon
//
//  After "Change ship" (the quick look at a job offer's route), this chip
//  offers the one-tap way back to the previously watched ship. Shown on the
//  Today screen and the itinerary list; the ✕ means "I'm staying".
//

import SwiftUI

struct ReturnShipChip: View {
    @Environment(CrewSetup.self) var crewSetup
    @Environment(FleetData.self) var fleetData

    var body: some View {
        if let previous = crewSetup.previousShip, crewSetup.hasPreviousShip {
            HStack(spacing: 4) {
                Button {
                    withAnimation(.spring(duration: 0.4)) {
                        crewSetup.returnToPreviousShip()
                        fleetData.apply(crewSetup)
                    }
                } label: {
                    Label("Return to \(previous)", systemImage: "arrow.uturn.backward")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .padding(.leading, 14)
                        .padding(.vertical, 9)
                }
                Button {
                    withAnimation(.spring(duration: 0.4)) {
                        crewSetup.clearPreviousShip()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .padding(.trailing, 14)
                        .padding(.vertical, 9)
                }
            }
            .foregroundStyle(Color.oceanInk)
            .glassEffect(.regular.tint(.teal.opacity(0.35)).interactive(), in: .capsule)
            .padding(.top, 4)
        }
    }
}
