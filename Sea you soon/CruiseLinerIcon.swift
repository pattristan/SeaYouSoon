//
//  CruiseLinerIcon.swift
//  Sea you soon
//
//  A little cruise liner on waves, drawn in code — SF Symbols has no cruise
//  ship, so this stands in. Inherits the current foregroundStyle like a
//  symbol would, and stays crisp at any size.
//

import SwiftUI

struct CruiseLinerIcon: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Ship silhouette (even-odd so windows punch through)
                Path { p in
                    // Hull — bow to the right
                    p.move(to: CGPoint(x: 0.08 * w, y: 0.58 * h))
                    p.addLine(to: CGPoint(x: 0.88 * w, y: 0.58 * h))
                    p.addQuadCurve(to: CGPoint(x: 0.96 * w, y: 0.66 * h),
                                   control: CGPoint(x: 0.95 * w, y: 0.58 * h))
                    p.addQuadCurve(to: CGPoint(x: 0.84 * w, y: 0.82 * h),
                                   control: CGPoint(x: 0.93 * w, y: 0.80 * h))
                    p.addLine(to: CGPoint(x: 0.14 * w, y: 0.82 * h))
                    p.addQuadCurve(to: CGPoint(x: 0.08 * w, y: 0.58 * h),
                                   control: CGPoint(x: 0.06 * w, y: 0.70 * h))
                    p.closeSubpath()

                    // Upper deck
                    p.addRoundedRect(in: CGRect(x: 0.18 * w, y: 0.44 * h,
                                                width: 0.60 * w, height: 0.14 * h),
                                     cornerSize: CGSize(width: 0.02 * w, height: 0.02 * h))
                    // Bridge deck
                    p.addRoundedRect(in: CGRect(x: 0.26 * w, y: 0.32 * h,
                                                width: 0.42 * w, height: 0.12 * h),
                                     cornerSize: CGSize(width: 0.02 * w, height: 0.02 * h))
                    // Funnel
                    p.addRoundedRect(in: CGRect(x: 0.52 * w, y: 0.18 * h,
                                                width: 0.10 * w, height: 0.14 * h),
                                     cornerSize: CGSize(width: 0.015 * w, height: 0.015 * h))

                    // Porthole row (punched out of the hull by even-odd)
                    for i in 0..<5 {
                        let cx = (0.22 + Double(i) * 0.13) * w
                        p.addEllipse(in: CGRect(x: cx, y: 0.66 * h,
                                                width: 0.045 * w, height: 0.045 * w))
                    }
                }
                .fill(ForegroundStyle(), style: FillStyle(eoFill: true))

                // Waves
                Path { p in
                    p.move(to: CGPoint(x: 0.02 * w, y: 0.92 * h))
                    p.addQuadCurve(to: CGPoint(x: 0.26 * w, y: 0.92 * h),
                                   control: CGPoint(x: 0.14 * w, y: 0.82 * h))
                    p.addQuadCurve(to: CGPoint(x: 0.50 * w, y: 0.92 * h),
                                   control: CGPoint(x: 0.38 * w, y: 1.02 * h))
                    p.addQuadCurve(to: CGPoint(x: 0.74 * w, y: 0.92 * h),
                                   control: CGPoint(x: 0.62 * w, y: 0.82 * h))
                    p.addQuadCurve(to: CGPoint(x: 0.98 * w, y: 0.92 * h),
                                   control: CGPoint(x: 0.86 * w, y: 1.02 * h))
                }
                .stroke(ForegroundStyle(), style: StrokeStyle(lineWidth: max(1.2, 0.05 * h),
                                                              lineCap: .round))
            }
        }
        .aspectRatio(1.25, contentMode: .fit)
    }
}

#Preview {
    VStack(spacing: 24) {
        CruiseLinerIcon().frame(height: 20).foregroundStyle(Color.oceanInk)
        CruiseLinerIcon().frame(height: 40).foregroundStyle(.mint)
        CruiseLinerIcon().frame(height: 80).foregroundStyle(.teal)
    }
    .padding()
}
