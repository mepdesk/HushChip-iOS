// Copyright (c) 2026 Gridmark Technologies Ltd (HushChip)
// https://github.com/hushchip/HushChip-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import SwiftUI

// MARK: - Chip graphic (drawn entirely in SwiftUI)

private struct HCChipView: View {
    var body: some View {
        ZStack {
            // Gold chip body
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "#b8993e"))
                .frame(width: 56, height: 44)

            // Contact pad lines
            Canvas { ctx, size in
                let lineColor = GraphicsContext.Shading.color(Color(hex: "#8a6e22"))
                var vLine = Path()
                vLine.move(to: CGPoint(x: size.width / 2, y: 3))
                vLine.addLine(to: CGPoint(x: size.width / 2, y: size.height - 3))
                ctx.stroke(vLine, with: lineColor, lineWidth: 1)

                let y1 = size.height / 3
                var h1 = Path()
                h1.move(to: CGPoint(x: 3, y: y1))
                h1.addLine(to: CGPoint(x: size.width - 3, y: y1))
                ctx.stroke(h1, with: lineColor, lineWidth: 1)

                let y2 = size.height * 2 / 3
                var h2 = Path()
                h2.move(to: CGPoint(x: 3, y: y2))
                h2.addLine(to: CGPoint(x: size.width - 3, y: y2))
                ctx.stroke(h2, with: lineColor, lineWidth: 1)
            }
            .frame(width: 56, height: 44)
        }
    }
}

// MARK: - Splash screen

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.hcBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Chip
                HCChipView()

                Spacer().frame(height: 28)

                // "HUSH" — very faint, wide tracking
                Text("HUSH")
                    .font(.custom("Outfit-ExtraLight", size: 42))
                    .tracking(14)
                    .foregroundColor(Color(hex: "#38383e"))

                Spacer().frame(height: 8)

                // "HUSHCHIP" — slightly brighter, smaller
                Text("HUSHCHIP")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(6)
                    .foregroundColor(Color(hex: "#28282e"))

                Spacer()
            }
        }
    }
}
