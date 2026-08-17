//
//  MapView.swift
//  Sea you soon
//

import MapKit
import SwiftUI

struct MapView: View {
    var coordinate: CLLocationCoordinate2D
    /// Label under the ship marker (e.g. the ship's name).
    var markerTitle: String = ""

    var body: some View {
        Map(position: .constant(.region(region))) {
            // Our own ship marks the spot — not a generic pin.
            Annotation(markerTitle, coordinate: coordinate) {
                CruiseLinerIcon()
                    .frame(height: 20)
                    .foregroundStyle(Color.oceanInk)
                    .padding(9)
                    .background(.white.opacity(0.92), in: Circle())
                    .overlay(Circle().stroke(Color.oceanInk.opacity(0.25), lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            }
        }
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
    }
}

#Preview {
    MapView(coordinate: CLLocationCoordinate2D(latitude: 54.321001, longitude: 10.132386),
            markerTitle: "AIDAsol")
}
