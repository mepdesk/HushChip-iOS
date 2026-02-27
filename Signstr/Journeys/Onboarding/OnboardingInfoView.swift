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
//  OnboardingInfoView.swift
//  Signstr — Onboarding Screen 2: "Tap. Store. Done."

import Foundation
import SwiftUI

// MARK: - NFC ripple arc shape

/// A single right-opening arc, representing an NFC radio wave.
private struct RippleArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.minX       // anchor on the left edge
        let cy = rect.midY
        let r  = rect.width      // radius = full width of the frame
        path.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: r,
            startAngle: .degrees(-50),
            endAngle:   .degrees(50),
            clockwise: false
        )
        return path
    }
}

// MARK: - NFC illustration

private struct NfcIllustration: View {
    var body: some View {
        ZStack {
            // ── Card (left, angled toward phone) ────────────────────────
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.sgBgRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.sgBorderHover, lineWidth: 1)
                    )
                    .frame(width: 90, height: 58)

                // Mini chip on card
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "#7a6840"))
                    .frame(width: 20, height: 16)
                    .padding(.top, 14)
                    .padding(.leading, 12)
            }
            .rotationEffect(.degrees(-20))
            .offset(x: -62, y: 12)

            // ── NFC ripple arcs (3, increasing size, fading outward) ─────
            ForEach(0..<3) { i in
                let size = CGFloat(30 + i * 22)
                RippleArc()
                    .stroke(
                        Color.sgBorderHover.opacity(1.0 - Double(i) * 0.28),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .offset(x: -10, y: 0)
            }

            // ── Phone (right, upright) ───────────────────────────────────
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.sgBgRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.sgBorderHover, lineWidth: 1)
                    )
                    .frame(width: 52, height: 88)

                // Camera pill
                Capsule()
                    .fill(Color.sgBgSurface)
                    .frame(width: 16, height: 5)
                    .offset(y: -36)

                // Home indicator bar
                Capsule()
                    .fill(Color.sgBorder)
                    .frame(width: 22, height: 4)
                    .offset(y: 36)
            }
            .offset(x: 56, y: -10)
        }
        .frame(width: 220, height: 140)
    }
}

// MARK: - Screen 2

struct OnboardingInfoView: View {

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Illustration ─────────────────────────────────────────────
            NfcIllustration()

            Spacer().frame(height: 44)

            // ── Heading ──────────────────────────────────────────────────
            Text("Tap. Store. Done.")
                .font(.outfit(.light, size: 20))
                .tracking(0.3)
                .foregroundColor(.sgTextBright)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 16)

            // ── Body ─────────────────────────────────────────────────────
            Text("Hold your card to your phone. Enter your PIN. Your secrets are safe.")
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 40)

            Spacer()
            // Reserve space for the bottom bar (dots + button)
            Spacer().frame(height: 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sgBg)
    }
}
