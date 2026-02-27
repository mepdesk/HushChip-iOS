// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/hushchip/Signstr-iOS
//
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// https://github.com/Toporin/Seedkeeper-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  EmptyScanStateOverlay.swift
//  Signstr — Premium home/pairing screen with realistic card visual

import Foundation
import SwiftUI

// MARK: - Realistic EMV chip with contact pad lines

private struct EMVChipView: View {
    private let goldLight = Color(hex: "#a89058")
    private let gold = Color(hex: "#8a7440")
    private let goldDark = Color(hex: "#685830")
    private let padLine = Color(hex: "#5a4828")

    var body: some View {
        ZStack {
            // Base chip — gold gradient
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [goldLight, gold, goldDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Contact pad grid lines
            Canvas { context, size in
                let lw: CGFloat = 0.6
                let col = padLine

                // Horizontal center line (full width)
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: size.height / 2))
                        p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    },
                    with: .color(col), lineWidth: lw
                )

                // Vertical center line (full height)
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: size.width / 2, y: 0))
                        p.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                    },
                    with: .color(col), lineWidth: lw
                )

                // Upper-left pad division
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: size.height * 0.28))
                        p.addLine(to: CGPoint(x: size.width * 0.38, y: size.height * 0.28))
                    },
                    with: .color(col), lineWidth: lw
                )

                // Lower-left pad division
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: size.height * 0.72))
                        p.addLine(to: CGPoint(x: size.width * 0.38, y: size.height * 0.72))
                    },
                    with: .color(col), lineWidth: lw
                )

                // Upper-right pad division
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: size.width * 0.62, y: size.height * 0.28))
                        p.addLine(to: CGPoint(x: size.width, y: size.height * 0.28))
                    },
                    with: .color(col), lineWidth: lw
                )

                // Lower-right pad division
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: size.width * 0.62, y: size.height * 0.72))
                        p.addLine(to: CGPoint(x: size.width, y: size.height * 0.72))
                    },
                    with: .color(col), lineWidth: lw
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .frame(width: 36, height: 28)
    }
}

// MARK: - Realistic card visual (260 x 164 pt)

private struct RealisticCardView: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card background — dark gradient
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#121216"),
                            Color(hex: "#0e0e11"),
                            Color(hex: "#0b0b0e")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Matte grain texture overlay
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.008))

            // Thin light border for edge definition
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)

            // EMV chip — left side
            EMVChipView()
                .padding(.top, 42)
                .padding(.leading, 24)

            // NFC contactless icon — top-right, rotated so waves point upward
            Image(systemName: "wave.3.right")
                .font(.system(size: 14, weight: .ultraLight))
                .foregroundColor(Color(hex: "#3a3a42"))
                .rotationEffect(.degrees(-90))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 22)
                .padding(.trailing, 22)

            // "HUSH" wordmark — bottom-left
            Text("HUSH")
                .font(.custom("Outfit-Medium", size: 10))
                .tracking(5)
                .foregroundColor(Color(hex: "#34343c"))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.bottom, 22)
                .padding(.leading, 24)
        }
        .frame(width: 260, height: 164)
        .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 4)
        .shadow(color: .black.opacity(0.4), radius: 1.5, x: 0, y: 1)
    }
}

// MARK: - NFC pulse rings (3 concentric, staggered)

private struct PulseRingsView: View {
    @Binding var animate: Bool

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color(hex: "#7a6840").opacity(0.12), lineWidth: 0.8)
                    .frame(width: 90, height: 90)
                    .scaleEffect(animate ? 3.2 : 1.0)
                    .opacity(animate ? 0.0 : 0.45 - Double(i) * 0.12)
                    .animation(
                        .easeOut(duration: 3.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.9),
                        value: animate
                    )
            }
        }
    }
}

// MARK: - Gold glow behind card

private struct GoldGlowView: View {
    var body: some View {
        Ellipse()
            .fill(Color(hex: "#7a6840").opacity(0.05))
            .frame(width: 300, height: 200)
            .blur(radius: 50)
    }
}

// MARK: - Home waiting screen

struct EmptyScanStateOverlay: View {
    @EnvironmentObject var cardState: CardState
    @Binding var homeNavigationPath: NavigationPath

    @State private var pulseAnimate = false
    @State private var floating = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Tappable area: card + effects + labels ──────────────
            Button(action: { Task { cardState.scan() } }) {
                VStack(spacing: 0) {
                    // Card with glow + pulse rings + float
                    ZStack {
                        GoldGlowView()

                        PulseRingsView(animate: $pulseAnimate)

                        RealisticCardView()
                            .offset(y: floating ? -6 : 6)
                            .animation(
                                .easeInOut(duration: 4.0)
                                    .repeatForever(autoreverses: true),
                                value: floating
                            )
                    }
                    .frame(height: 220)

                    Spacer().frame(height: 32)

                    Text("Tap your card")
                        .font(.outfit(.light, size: 14))
                        .foregroundColor(.sgTextMuted)

                    Spacer().frame(height: 8)

                    Text("Hold your card near the top of your iPhone")
                        .font(.outfit(.light, size: 11))
                        .foregroundColor(.sgTextFaint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer().frame(height: 32)

            // ── "TAP TO SCAN" button ────────────────────────────────
            Button(action: { Task { cardState.scan() } }) {
                Text("TAP TO SCAN")
                    .font(.outfit(.regular, size: 11))
                    .tracking(4)
                    .foregroundColor(.sgTextBright)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.sgBorder)
                    .cornerRadius(Dimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                            .stroke(Color.sgBorderHover, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear {
            pulseAnimate = true
            floating = true
        }
    }
}
