//
//  SplashScreenView.swift
//  Sea you soon
//

import SwiftUI

struct SplashScreenView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var opacity: Double = 0
    @State private var scale: Double = 0.8
    @State private var displayedText: String = ""
    private let fullText = "Sea You Soon..."

    var body: some View {
        ZStack {
//            LinearGradient(colors: [Color(red: 0.02, green: 0.16, blue: 0.36), Color(red: 0.0, green: 0.42, blue: 0.6)],
//                           startPoint: .top, endPoint: .bottom)
              //  .ignoresSafeArea()
            OceanBackground()

            VStack(spacing: 20) {
                
                Image(uiImage: UIImage(named: "CUsoonLLogo2") ?? UIImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: horizontalSizeClass == .regular ? 350 : 350,
                           height: horizontalSizeClass == .compact ? 301 : 301)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
//                    .font(.system(size: 90))
//                    .foregroundStyle(.white)
//                    .shadow(radius: 8)

                Text(displayedText)
                    .font(.custom("NY", size: 34))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.oceanInk)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                opacity = 1.0
                scale = 1.0
            }
            typeText()
        }
    }

    private func typeText() {
        for (index, character) in fullText.enumerated() {
            let delay = 0.6 + Double(index) * 0.06
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                displayedText.append(character)
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
