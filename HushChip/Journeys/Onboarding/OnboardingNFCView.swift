// Copyright (c) 2026 Gridmark Technologies Ltd (HushChip)
// https://github.com/hushchip/HushChip-iOS
//
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// https://github.com/Toporin/Seedkeeper-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  OnboardingNFCView.swift
//  HushChip — Onboarding Screen 3: "Your PIN is everything."

import Foundation
import SwiftUI

// MARK: - Lock illustration

/// Padlock built from SwiftUI primitives:
///   • shackle: trimmed circle (top semicircle) + two vertical legs
///   • body: rounded rectangle
///   • keyhole: small filled circle
private struct LockIllustration: View {

    var body: some View {
        ZStack {
            // ── Shackle — top arc ────────────────────────────────────────
            // trim(0.5 → 1.0) on a Circle starting at 3-o'clock going clockwise:
            //   0.5 = 9-o'clock, 1.0 = 3-o'clock → traces the top half (∩ arc)
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(Color.hcBorderHover, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 44, height: 44)
                .offset(y: -25)

            // ── Shackle — left leg ───────────────────────────────────────
            Rectangle()
                .fill(Color.hcBorderHover)
                .frame(width: 5, height: 18)
                .offset(x: -22, y: -8)

            // ── Shackle — right leg ──────────────────────────────────────
            Rectangle()
                .fill(Color.hcBorderHover)
                .frame(width: 5, height: 18)
                .offset(x: 22, y: -8)

            // ── Lock body ────────────────────────────────────────────────
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.hcBgRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.hcBorderHover, lineWidth: 1.5)
                )
                .frame(width: 72, height: 56)
                .offset(y: 22)

            // ── Keyhole ──────────────────────────────────────────────────
            Circle()
                .fill(Color.hcBgSurface)
                .frame(width: 14, height: 14)
                .offset(y: 20)
        }
        .frame(width: 110, height: 110)
    }
}

// MARK: - Screen 3

struct OnboardingNFCView: View {

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Illustration ─────────────────────────────────────────────
            LockIllustration()

            Spacer().frame(height: 44)

            // ── Heading ──────────────────────────────────────────────────
            Text("Your PIN is everything.")
                .font(.outfit(.light, size: 20))
                .tracking(0.3)
                .foregroundColor(.hcTextBright)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 24)

            // ── Red warning box ──────────────────────────────────────────
            Text("If you forget your PIN, the card locks permanently. There is no recovery. Choose a PIN you will remember.")
                .font(.outfit(.light, size: 12))
                .foregroundColor(.hcDanger)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.hcDangerBg)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.hcDangerBorder, lineWidth: 1)
                )
                .padding(.horizontal, 32)

            Spacer()
            // Reserve space for the bottom bar (dots + button)
            Spacer().frame(height: 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hcBg)
    }
}
