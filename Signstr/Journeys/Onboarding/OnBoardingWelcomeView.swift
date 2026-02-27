// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// https://github.com/Toporin/Seedkeeper-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  OnBoardingWelcomeView.swift
//  Signstr — Onboarding Screen 1: "Your Nostr identity. Secured."

import Foundation
import SwiftUI

// MARK: - Shield illustration

/// A shield with a key silhouette inside, representing identity security.
private struct ShieldIllustration: View {

    var body: some View {
        ZStack {
            // Shield outline
            ShieldShape()
                .fill(Color.sgBgRaised)
                .overlay(
                    ShieldShape()
                        .stroke(Color.sgBorderHover, lineWidth: 1.5)
                )
                .frame(width: 100, height: 120)

            // Key icon inside shield
            Image(systemName: "key.fill")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(.sgBorderHover)
                .rotationEffect(.degrees(-45))
                .offset(y: -4)
        }
        .frame(width: 140, height: 140)
    }
}

/// Custom shield shape.
private struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = rect.midX

        // Top left corner
        path.move(to: CGPoint(x: cx, y: 0))
        // Top right curve
        path.addQuadCurve(
            to: CGPoint(x: w, y: h * 0.15),
            control: CGPoint(x: w, y: 0)
        )
        // Right side
        path.addLine(to: CGPoint(x: w, y: h * 0.45))
        // Bottom right curve to point
        path.addQuadCurve(
            to: CGPoint(x: cx, y: h),
            control: CGPoint(x: w, y: h * 0.78)
        )
        // Bottom left curve
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h * 0.45),
            control: CGPoint(x: 0, y: h * 0.78)
        )
        // Left side
        path.addLine(to: CGPoint(x: 0, y: h * 0.15))
        // Top left curve
        path.addQuadCurve(
            to: CGPoint(x: cx, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Screen 1

struct OnboardingWelcomeView: View {

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Illustration ────────────────────────────────────────
            ShieldIllustration()

            Spacer().frame(height: 44)

            // ── Heading ─────────────────────────────────────────────
            Text("Your Nostr identity. Secured.")
                .font(.outfit(.light, size: 20))
                .tracking(0.3)
                .foregroundColor(.sgTextBright)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 16)

            // ── Body ────────────────────────────────────────────────
            Text("Signstr keeps your nsec encrypted in one place. No more pasting it into every app.")
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
