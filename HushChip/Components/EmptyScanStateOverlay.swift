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
//  EmptyScanStateOverlay.swift
//  HushChip — Home waiting screen with NFC ripple animation

import Foundation
import SwiftUI

// MARK: - Mini card-mark icon

private struct MiniCardIcon: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.hcBgRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.hcBorderHover, lineWidth: 1)
                )
                .frame(width: 44, height: 28)

            // EMV chip mark
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: "#7a6840"))
                .frame(width: 12, height: 10)
                .padding(.top, 6)
                .padding(.leading, 7)
        }
    }
}

// MARK: - Home waiting screen

struct EmptyScanStateOverlay: View {
    @EnvironmentObject var cardState: CardState
    @Binding var homeNavigationPath: NavigationPath

    @State private var animate = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Tappable scan area ────────────────────────────────────────
            // Card icon + ripple + labels all respond to tap → NFC scan.
            Button(action: { Task { cardState.scan() } }) {
                VStack(spacing: 0) {
                    // Card-mark icon above the ripple
                    MiniCardIcon()

                    Spacer().frame(height: 36)

                    // Three concentric circles that pulse outward and fade.
                    ZStack {
                        ForEach(0..<3) { i in
                            Circle()
                                .stroke(Color.hcBorderHover, lineWidth: 1)
                                .frame(width: 80, height: 80)
                                .scaleEffect(animate ? 2.4 : 1.0)
                                .opacity(animate ? 0.0 : Double(0.55 - Double(i) * 0.14))
                                .animation(
                                    .easeOut(duration: 2.2)
                                        .repeatForever(autoreverses: false)
                                        .delay(Double(i) * 0.72),
                                    value: animate
                                )
                        }
                    }
                    .frame(width: 200, height: 200)

                    // Labels
                    Text("Tap your card")
                        .font(.outfit(.light, size: 14))
                        .foregroundColor(.hcTextMuted)

                    Spacer().frame(height: 8)

                    Text("Hold your HushChip near the top of your iPhone")
                        .font(.outfit(.light, size: 11))
                        .foregroundColor(.hcTextFaint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer().frame(height: 32)

            // ── "TAP TO SCAN" primary button ──────────────────────────────
            Button(action: { Task { cardState.scan() } }) {
                Text("TAP TO SCAN")
                    .font(.outfit(.regular, size: 11))
                    .tracking(4)
                    .foregroundColor(.hcTextBright)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.hcBorder)
                    .cornerRadius(Dimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                            .stroke(Color.hcBorderHover, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear {
            animate = true
        }
    }
}
