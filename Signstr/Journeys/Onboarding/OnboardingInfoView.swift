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
//  OnboardingInfoView.swift
//  Signstr — Onboarding Screen 2: "Sign events. Never paste your nsec again."

import Foundation
import SwiftUI

// MARK: - Signing illustration

/// A pen signing a document, representing event signing.
private struct SigningIllustration: View {
    var body: some View {
        ZStack {
            // Document
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.sgBgRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.sgBorderHover, lineWidth: 1)
                )
                .frame(width: 80, height: 100)

            // Text lines on document
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.sgBorder)
                    .frame(width: 48, height: 3)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.sgBorder)
                    .frame(width: 40, height: 3)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.sgBorder)
                    .frame(width: 52, height: 3)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.sgBorder)
                    .frame(width: 32, height: 3)
            }
            .offset(y: -8)

            // Checkmark at bottom of document
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.sgBorderHover)
                .offset(y: 30)

            // Pen (angled, overlapping document)
            PenShape()
                .fill(Color.sgBorderHover)
                .frame(width: 8, height: 60)
                .rotationEffect(.degrees(35))
                .offset(x: 52, y: 24)
        }
        .frame(width: 180, height: 140)
    }
}

/// A simple pen nib shape.
private struct PenShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Pen body (rectangle)
        path.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: w, height: h * 0.8),
            cornerSize: CGSize(width: 2, height: 2)
        )

        // Pen tip (triangle)
        path.move(to: CGPoint(x: 0, y: h * 0.8))
        path.addLine(to: CGPoint(x: w, y: h * 0.8))
        path.addLine(to: CGPoint(x: w / 2, y: h))
        path.closeSubpath()

        return path
    }
}

// MARK: - Screen 2

struct OnboardingInfoView: View {

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Illustration ────────────────────────────────────────
            SigningIllustration()

            Spacer().frame(height: 44)

            // ── Heading ─────────────────────────────────────────────
            Text("Connect your favourite clients.")
                .font(.outfit(.light, size: 20))
                .tracking(0.3)
                .foregroundColor(.sgTextBright)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 16)

            // ── Body ────────────────────────────────────────────────
            Text("Damus, Primal, and other Nostr clients can request signatures without ever seeing your nsec.")
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
