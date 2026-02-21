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
//  AddSecretView.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 04/05/2024.
//

import Foundation
import SwiftUI

// MARK: - Secret type definitions for the type selector

private struct SecretTypeOption: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let description: String
    let generatorMode: GeneratorMode
    let isSupported: Bool
}

private let secretTypeOptions: [SecretTypeOption] = [
    SecretTypeOption(icon: "Aa", name: "Mnemonic", description: "12 or 24 word seed phrase", generatorMode: .mnemonic, isSupported: true),
    SecretTypeOption(icon: "\u{25CF}", name: "Password", description: "Login credentials and passwords", generatorMode: .password, isSupported: true),
    SecretTypeOption(icon: "{ }", name: "Wallet Descriptor", description: "Bitcoin wallet configuration", generatorMode: .freeText, isSupported: false),
    SecretTypeOption(icon: "T", name: "Free Text", description: "Any text you want to keep safe", generatorMode: .freeText, isSupported: true),
    SecretTypeOption(icon: "S", name: "Master Seed", description: "Raw cryptographic seed bytes", generatorMode: .freeText, isSupported: false),
]

struct AddSecretView: View {
    // MARK: - Properties
    @Binding var homeNavigationPath: NavigationPath

    var body: some View {
        ZStack {
            Color.hcBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    // Heading
                    Text("ADD SECRET")
                        .font(.custom("Outfit-Regular", size: 14))
                        .tracking(3)
                        .foregroundColor(.hcTextBright)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer().frame(height: 20)

                    // Type cards
                    VStack(spacing: 10) {
                        ForEach(secretTypeOptions) { option in
                            SecretTypeCard(option: option) {
                                guard option.isSupported else { return }
                                homeNavigationPath.append(
                                    NavigationRoutes.generateGenerator(
                                        GeneratorModeNavData(
                                            generatorMode: option.generatorMode,
                                            secretCreationMode: .manualImport
                                        )
                                    )
                                )
                            }
                        }
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, Dimensions.lateralPadding)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            homeNavigationPath.removeLast()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                Text("Back")
                    .font(.custom("Outfit-Regular", size: 12))
            }
            .foregroundColor(.hcTextMuted)
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("NEW SECRET")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.hcTextMuted)
                    .textCase(.uppercase)
            }
        }
    }
}

// MARK: - Secret Type Card

private struct SecretTypeCard: View {
    let option: SecretTypeOption
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Type icon
                Text(option.icon)
                    .font(.custom("Outfit-Regular", size: 11))
                    .foregroundColor(.hcTextFaint)
                    .frame(width: 28, height: 28)
                    .background(Color.hcBgSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.hcBorder, lineWidth: 1)
                    )
                    .cornerRadius(6)

                // Name + description
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                        .font(.custom("Outfit-Regular", size: 12))
                        .foregroundColor(.hcTextBody)
                        .lineLimit(1)
                    Text(option.description)
                        .font(.custom("Outfit-Light", size: 11))
                        .foregroundColor(.hcTextFaint)
                        .lineLimit(1)
                }

                Spacer()

                // Chevron or coming soon
                if option.isSupported {
                    Text("\u{203A}")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.hcTextGhost)
                } else {
                    Text("SOON")
                        .font(.custom("Outfit-Regular", size: 8))
                        .tracking(1)
                        .foregroundColor(.hcTextGhost)
                }
            }
            .padding(16)
            .background(Color.hcBgRaised)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.hcBorder, lineWidth: 1)
            )
            .cornerRadius(12)
            .opacity(option.isSupported ? 1.0 : 0.5)
        }
        .disabled(!option.isSupported)
    }
}
