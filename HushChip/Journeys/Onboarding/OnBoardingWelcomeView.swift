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
//  OnBoardingWelcomeView.swift
//  HushChip — Onboarding Screen 1: "Your secrets. On a chip."

import Foundation
import SwiftUI

struct OnboardingWelcomeView: View {

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Card illustration ────────────────────────────────────────
            ZStack(alignment: .topLeading) {
                // Card body
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.hcBgRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.hcBorderHover, lineWidth: 1)
                    )
                    .frame(width: 228, height: 144)

                // EMV chip — gold-toned rectangle in upper-left
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: "#7a6840"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color(hex: "#9a8855"), lineWidth: 0.5)
                    )
                    .frame(width: 38, height: 30)
                    .padding(.top, 30)
                    .padding(.leading, 26)

                // Chip contact lines (horizontal stripes for realism)
                VStack(spacing: 5) {
                    ForEach(0..<3) { _ in
                        Rectangle()
                            .fill(Color(hex: "#9a8855").opacity(0.4))
                            .frame(width: 38, height: 1)
                    }
                }
                .padding(.top, 39)
                .padding(.leading, 26)
            }

            Spacer().frame(height: 44)

            // ── Heading ──────────────────────────────────────────────────
            Text("Your secrets. On a chip.")
                .font(.outfit(.light, size: 20))
                .tracking(0.3)
                .foregroundColor(.hcTextBright)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 16)

            // ── Body ─────────────────────────────────────────────────────
            Text("Store seed phrases, passwords, and sensitive data on a PIN-protected NFC smart card.")
                .font(.outfit(.light, size: 13))
                .foregroundColor(.hcTextMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 40)

            Spacer()
            // Reserve space for the bottom bar (dots + button)
            Spacer().frame(height: 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hcBg)
    }
}
