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
//  GenerateSecretView.swift
//  Signstr
//
//  Created by Lionel Delvaux on 07/05/2024.
//

import Foundation
import SwiftUI

struct GenerateSecretTypeView: View {
    // MARK: - Properties
    @Binding var homeNavigationPath: NavigationPath
    @State private var showPickerSheet = false
    @State var phraseTypeOptions = PickerOptions(placeHolder: String(localized: "typeOfSecret"), items: GeneratorMode.self)
    var secretCreationMode: SecretCreationMode

    private var headingText: String {
        secretCreationMode == .manualImport ? "Import Secret" : "Generate Secret"
    }

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                // Heading
                Text(headingText.uppercased())
                    .font(.custom("Outfit-Regular", size: 14))
                    .tracking(3)
                    .foregroundColor(.sgTextBright)

                Spacer().frame(height: 8)

                Text("Choose the type of secret")
                    .font(.custom("Outfit-Light", size: 12))
                    .foregroundColor(.sgTextFaint)

                Spacer().frame(height: 24)

                // Type selector cards
                VStack(spacing: 10) {
                    // Mnemonic
                    SecretTypeChoiceCard(
                        icon: "Aa",
                        name: "Mnemonic",
                        description: "BIP39 seed phrase"
                    ) {
                        homeNavigationPath.append(
                            NavigationRoutes.generateGenerator(
                                GeneratorModeNavData(
                                    generatorMode: .mnemonic,
                                    secretCreationMode: secretCreationMode
                                )
                            )
                        )
                    }

                    // Password
                    SecretTypeChoiceCard(
                        icon: "\u{25CF}",
                        name: "Password",
                        description: "Login credentials"
                    ) {
                        homeNavigationPath.append(
                            NavigationRoutes.generateGenerator(
                                GeneratorModeNavData(
                                    generatorMode: .password,
                                    secretCreationMode: secretCreationMode
                                )
                            )
                        )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, Dimensions.lateralPadding)
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
            .foregroundColor(.sgTextMuted)
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(secretCreationMode == .manualImport ? "IMPORT" : "GENERATE")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
            }
        }
    }
}

// MARK: - Secret Type Choice Card

private struct SecretTypeChoiceCard: View {
    let icon: String
    let name: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.custom("Outfit-Regular", size: 11))
                    .foregroundColor(.sgTextFaint)
                    .frame(width: 28, height: 28)
                    .background(Color.sgBgSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.custom("Outfit-Regular", size: 12))
                        .foregroundColor(.sgTextBody)
                        .lineLimit(1)
                    Text(description)
                        .font(.custom("Outfit-Light", size: 11))
                        .foregroundColor(.sgTextFaint)
                        .lineLimit(1)
                }

                Spacer()

                Text("\u{203A}")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.sgTextGhost)
            }
            .padding(16)
            .background(Color.sgBgRaised)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.sgBorder, lineWidth: 1)
            )
            .cornerRadius(12)
        }
    }
}
