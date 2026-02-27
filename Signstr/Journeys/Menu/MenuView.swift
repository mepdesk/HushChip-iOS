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
//  MenuView.swift
//  Signstr
//
//  Created by Lionel Delvaux on 17/04/2024.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - URLs

enum SignstrURL: String {
    case howToUse = "https://signstr.com"
    case terms = "https://signstr.com/terms"
    case privacy = "https://signstr.com/privacy"
    case sourceCode = "https://github.com/hushchip/Signstr-iOS"
    case licence = "https://github.com/hushchip/Signstr-iOS/blob/main/LICENCE"

    var url: URL? {
        return URL(string: self.rawValue)
    }
}

// MARK: - Settings Screen

struct MenuView: View {
    @EnvironmentObject var cardState: CardState
    @Binding var homeNavigationPath: NavigationPath

    @State private var versionTapCount = 0
    @State private var showDebugUnlocked = false
    @State private var showResetConfirmation = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    private var cardVersionString: String {
        guard let cs = cardState.cardStatus else { return "Not connected" }
        return "v\(cs.protocolMajorVersion).\(cs.protocolMinorVersion)-\(cs.appletMajorVersion).\(cs.appletMinorVersion)"
    }

    private var pinTriesString: String {
        guard let cs = cardState.cardStatus else { return "—" }
        return "\(cs.pin0RemainingTries) remaining"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    // ── CARD section ──
                    SettingsSectionLabel(text: "CARD")

                    Spacer().frame(height: 10)

                    VStack(spacing: 1) {
                        // Card Name
                        SettingsRow(
                            icon: "creditcard",
                            label: "Card Info",
                            detail: cardState.cardLabel != "n/a" ? cardState.cardLabel : nil,
                            action: {
                                if cardState.cardStatus != nil {
                                    homeNavigationPath.append(NavigationRoutes.cardInfo)
                                }
                            }
                        )

                        // Change PIN
                        SettingsRow(
                            icon: "lock",
                            label: "Change PIN",
                            detail: pinTriesString,
                            action: {
                                if cardState.cardStatus != nil {
                                    homeNavigationPath.append(NavigationRoutes.editPinCode)
                                }
                            }
                        )

                        // Backup
                        SettingsRow(
                            icon: "arrow.triangle.2.circlepath",
                            label: "Backup",
                            action: {
                                if cardState.cardStatus != nil {
                                    homeNavigationPath.append(NavigationRoutes.backup)
                                }
                            }
                        )

                        // View Logs
                        SettingsRow(
                            icon: "list.bullet.rectangle",
                            label: "View Logs",
                            action: {
                                homeNavigationPath.append(NavigationRoutes.logs)
                            }
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer().frame(height: 28)

                    // ── APP section ──
                    SettingsSectionLabel(text: "APP")

                    Spacer().frame(height: 10)

                    VStack(spacing: 1) {
                        // Replay Onboarding
                        SettingsRow(
                            icon: "arrow.counterclockwise",
                            label: "Replay Onboarding",
                            action: {
                                UserDefaults.standard.set(false, forKey: Constants.Keys.onboardingComplete)
                                homeNavigationPath.append(NavigationRoutes.onboarding)
                            }
                        )

                        // Biometric Unlock (disabled for now)
                        SettingsRowDisabled(
                            icon: "faceid",
                            label: "Biometric Unlock",
                            badge: "SOON"
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer().frame(height: 28)

                    // ── ABOUT section ──
                    SettingsSectionLabel(text: "ABOUT")

                    Spacer().frame(height: 10)

                    VStack(spacing: 1) {
                        // Open Source / About
                        SettingsRow(
                            icon: "chevron.left.forwardslash.chevron.right",
                            label: "Open Source",
                            action: {
                                homeNavigationPath.append(NavigationRoutes.about)
                            }
                        )

                        // Version (with hidden debug tap)
                        SettingsRowVersion(
                            version: appVersion,
                            cardVersion: cardVersionString,
                            tapCount: $versionTapCount,
                            showDebugUnlocked: $showDebugUnlocked,
                            onDebugUnlocked: {
                                homeNavigationPath.append(NavigationRoutes.logs)
                            }
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer().frame(height: 28)

                    // ── DANGER ZONE section ──
                    SettingsSectionLabel(text: "DANGER ZONE", isDanger: true)

                    Spacer().frame(height: 10)

                    // Factory Reset button
                    Button(action: {
                        showResetConfirmation = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.sgDanger)
                                .frame(width: 20)

                            Text("Factory Reset")
                                .font(.custom("Outfit-Regular", size: 12))
                                .foregroundColor(.sgDanger)

                            Spacer()

                            Text("\u{203A}")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(.sgDanger.opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.sgDangerBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.sgDangerBorder, lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .alert("Factory Reset", isPresented: $showResetConfirmation) {
                        Button("Cancel", role: .cancel) { }
                        Button("Reset Card", role: .destructive) {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.warning)
                            // Factory reset is handled by the card APDU layer
                            // This would need to trigger a card scan + reset command
                        }
                    } message: {
                        Text("This will erase all secrets from the card. This action cannot be undone. You must scan the card to confirm.")
                    }

                    Spacer().frame(height: 40)
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
            .foregroundColor(.sgTextMuted)
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SETTINGS")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
            }
        }
    }
}

// MARK: - Section Label

private struct SettingsSectionLabel: View {
    let text: String
    var isDanger: Bool = false

    var body: some View {
        HStack {
            Text(text)
                .font(.custom("Outfit-Regular", size: 9))
                .tracking(3)
                .foregroundColor(isDanger ? .sgDanger.opacity(0.7) : .sgTextGhost)
            Spacer()
        }
    }
}

// MARK: - Settings Row

private struct SettingsRow: View {
    let icon: String
    let label: String
    var detail: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.sgTextFaint)
                    .frame(width: 20)

                Text(label)
                    .font(.custom("Outfit-Regular", size: 12))
                    .foregroundColor(.sgTextBody)

                Spacer()

                if let detail = detail {
                    Text(detail)
                        .font(.custom("Outfit-Light", size: 11))
                        .foregroundColor(.sgTextFaint)
                }

                Text("\u{203A}")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.sgTextGhost)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.sgBgRaised)
        }
    }
}

// MARK: - Settings Row (Disabled / Coming Soon)

private struct SettingsRowDisabled: View {
    let icon: String
    let label: String
    let badge: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.sgTextGhost)
                .frame(width: 20)

            Text(label)
                .font(.custom("Outfit-Regular", size: 12))
                .foregroundColor(.sgTextGhost)

            Spacer()

            Text(badge)
                .font(.custom("Outfit-Regular", size: 8))
                .tracking(1)
                .foregroundColor(.sgTextGhost)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sgBgRaised)
        .opacity(0.5)
    }
}

// MARK: - Version Row (with 7-tap debug unlock)

private struct SettingsRowVersion: View {
    let version: String
    let cardVersion: String
    @Binding var tapCount: Int
    @Binding var showDebugUnlocked: Bool
    let onDebugUnlocked: () -> Void

    var body: some View {
        Button(action: {
            tapCount += 1
            if tapCount >= 7 {
                tapCount = 0
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                showDebugUnlocked = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDebugUnlocked()
                }
            } else if tapCount >= 4 {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.sgTextFaint)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Version")
                        .font(.custom("Outfit-Regular", size: 12))
                        .foregroundColor(.sgTextBody)
                    Text("App \(version) \u{00B7} Card \(cardVersion)")
                        .font(.custom("Outfit-Light", size: 10))
                        .foregroundColor(.sgTextFaint)
                }

                Spacer()

                if showDebugUnlocked {
                    Text("DEBUG")
                        .font(.custom("Outfit-Regular", size: 8))
                        .tracking(2)
                        .foregroundColor(.sgBorderHover)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.sgBgRaised)
        }
    }
}

// MARK: - Legacy components (kept for backward compatibility)

struct MenuButton: View {
    let title: String
    let iconName: String
    let iconWidth: CGFloat
    let iconHeight: CGFloat
    let backgroundColor: Color
    let action: () -> Void
    var forcedHeight: CGFloat = 120
    var subTitle: String? = nil

    var body: some View {
        Button(action: action) {
            Group {
                if forcedHeight < 60 {
                    HStack {
                        Text(title)
                            .foregroundColor(.sgTextBright)
                            .font(.headline)
                            .lineLimit(2)
                            .padding([.leading, .trailing])
                        Spacer()
                        Image(iconName)
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.sgTextBright)
                            .frame(width: iconWidth, height: iconHeight)
                            .padding([.trailing])
                    }
                } else {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(title)
                                .foregroundColor(.sgTextBright)
                                .font(.headline)
                                .lineLimit(2)
                                .padding([.top, .leading, .trailing])
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            if let subTitle = subTitle {
                                Text(subTitle)
                                    .foregroundColor(.sgTextBright)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                    .padding([.leading, .trailing])
                            }
                            Spacer()
                            Image(iconName)
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.sgTextBright)
                                .frame(width: iconWidth, height: iconHeight)
                                .padding([.trailing, .bottom])
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: forcedHeight, maxHeight: forcedHeight)
            .background(backgroundColor)
            .cornerRadius(Dimensions.cardCornerRadius)
        }
    }
}

struct SmallMenuButton: View {
    let text: String
    let backgroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SatoText(text: text, style: .extraLightSubtitle)
                .padding()
        }
        .frame(maxWidth: .infinity, minHeight: 57)
        .background(backgroundColor)
        .cornerRadius(Dimensions.cardCornerRadius)
    }
}

struct ProductButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image("bg_btn_product")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 155)
                    .cornerRadius(Dimensions.cardCornerRadius)
                    .clipped()

                VStack {
                    HStack {
                        Text(String(localized: "allOurProducts"))
                            .font(
                                Font.custom("Outfit", size: 20)
                                    .weight(.medium)
                            )
                            .foregroundColor(.sgTextBright)
                            .padding([.top, .leading])
                        Spacer()
                    }
                    Spacer()
                }.frame(height: 155)

            }.frame(height: 155)
        }
    }
}
