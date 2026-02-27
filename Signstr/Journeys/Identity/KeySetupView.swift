// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  KeySetupView.swift
//  Signstr — Key setup: "Create new identity" or "Import existing nsec"

import SwiftUI

struct KeySetupView: View {
    @EnvironmentObject var cardState: CardState

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Icon ────────────────────────────────────────────
                Image(systemName: "key")
                    .font(.system(size: 40, weight: .ultraLight))
                    .foregroundColor(.sgBorderHover)

                Spacer().frame(height: 32)

                // ── Heading ─────────────────────────────────────────
                Text("Set up your identity")
                    .font(.outfit(.light, size: 22))
                    .tracking(0.3)
                    .foregroundColor(.sgTextBright)

                Spacer().frame(height: 12)

                Text("Your Nostr keypair is how the world knows you.")
                    .font(.outfit(.light, size: 13))
                    .foregroundColor(.sgTextMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 40)

                Spacer().frame(height: 48)

                // ── Create new identity ─────────────────────────────
                Button(action: {
                    cardState.homeNavigationPath.append(NavigationRoutes.generateKey)
                }) {
                    HStack(spacing: 14) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.sgTextBright)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("CREATE NEW IDENTITY")
                                .font(.outfit(.regular, size: 11))
                                .tracking(3)
                                .foregroundColor(.sgTextBright)

                            Text("Generate a fresh Nostr keypair")
                                .font(.outfit(.light, size: 12))
                                .foregroundColor(.sgTextFaint)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.sgTextGhost)
                    }
                    .padding(Dimensions.cardPadding)
                    .background(Color.sgBgRaised)
                    .cornerRadius(Dimensions.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                // ── Import existing nsec ────────────────────────────
                Button(action: {
                    cardState.homeNavigationPath.append(NavigationRoutes.importNsec)
                }) {
                    HStack(spacing: 14) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.sgTextBright)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("IMPORT EXISTING NSEC")
                                .font(.outfit(.regular, size: 11))
                                .tracking(3)
                                .foregroundColor(.sgTextBright)

                            Text("Paste or scan your nsec1... key")
                                .font(.outfit(.light, size: 12))
                                .foregroundColor(.sgTextFaint)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.sgTextGhost)
                    }
                    .padding(Dimensions.cardPadding)
                    .background(Color.sgBgRaised)
                    .cornerRadius(Dimensions.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
