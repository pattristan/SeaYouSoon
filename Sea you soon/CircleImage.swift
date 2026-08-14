//
//  CircleImage.swift
//  Sea you soon
//

import SwiftUI

struct CircleImage: View {
    let niceGray = Color(red: 0.7, green: 0.7, blue: 0.7).opacity(0.3)

    var image: Image
    var size: CGFloat = 250

    var body: some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay { Circle().stroke(niceGray, lineWidth: 4) }
            .shadow(radius: 7)
    }
}
