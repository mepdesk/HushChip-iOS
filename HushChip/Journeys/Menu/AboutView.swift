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
//  AboutView.swift
//  HushChip
//
//  Created for the HushChip iOS app.
//

import SwiftUI
import UIKit

struct AboutView: View {
    @Binding var homeNavigationPath: NavigationPath

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            Color.hcBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 32)

                    // Logo + version
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(.hcTextGhost)

                    Spacer().frame(height: 12)

                    Text("HUSHCHIP")
                        .font(.custom("Outfit-Regular", size: 14))
                        .tracking(6)
                        .foregroundColor(.hcTextBright)

                    Spacer().frame(height: 4)

                    Text(appVersion)
                        .font(.custom("Outfit-Light", size: 11))
                        .foregroundColor(.hcTextFaint)

                    Spacer().frame(height: 36)

                    // ── OPEN SOURCE section ──
                    AboutSectionLabel(text: "OPEN SOURCE")

                    Spacer().frame(height: 10)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("This application is free software, distributed under the GNU General Public License v3.0. You are free to use, modify, and redistribute it under the terms of the licence.")
                            .font(.custom("Outfit-Light", size: 12))
                            .foregroundColor(.hcTextBody)
                            .lineSpacing(4)

                        Spacer().frame(height: 4)

                        AboutLinkRow(
                            label: "Source Code",
                            detail: "github.com/hushchip",
                            url: HushChipURL.sourceCode.url
                        )

                        AboutLinkRow(
                            label: "Licence",
                            detail: "GPL-3.0",
                            url: HushChipURL.licence.url
                        )
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.hcBgRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.hcBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)

                    Spacer().frame(height: 28)

                    // ── ATTRIBUTION section ──
                    AboutSectionLabel(text: "ATTRIBUTION")

                    Spacer().frame(height: 10)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("HushChip is based on SeedKeeper-iOS, an open-source project by Toporin, developed and maintained by Satochip S.R.L.")
                            .font(.custom("Outfit-Light", size: 12))
                            .foregroundColor(.hcTextBody)
                            .lineSpacing(4)

                        Spacer().frame(height: 4)

                        AboutLinkRow(
                            label: "Original Project",
                            detail: "SeedKeeper-iOS by Toporin",
                            url: URL(string: "https://github.com/Toporin/Seedkeeper-iOS")
                        )

                        AboutLinkRow(
                            label: "Satochip",
                            detail: "satochip.io",
                            url: URL(string: "https://satochip.io")
                        )

                        AboutLinkRow(
                            label: "SatochipSwift",
                            detail: "NFC & APDU library",
                            url: URL(string: "https://github.com/Toporin/SatochipSwift")
                        )
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.hcBgRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.hcBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)

                    Spacer().frame(height: 28)

                    // ── LEGAL section ──
                    AboutSectionLabel(text: "LEGAL")

                    Spacer().frame(height: 10)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("HushChip is a trading name of Gridmark Technologies Ltd, registered in England and Wales.")
                            .font(.custom("Outfit-Light", size: 12))
                            .foregroundColor(.hcTextBody)
                            .lineSpacing(4)

                        Spacer().frame(height: 4)

                        AboutLinkRow(
                            label: "Privacy Policy",
                            detail: "hushchip.co.uk/privacy",
                            url: HushChipURL.privacy.url
                        )

                        AboutLinkRow(
                            label: "Terms of Service",
                            detail: "hushchip.co.uk/terms",
                            url: HushChipURL.terms.url
                        )

                        AboutLinkRow(
                            label: "Website",
                            detail: "hushchip.co.uk",
                            url: HushChipURL.howToUse.url
                        )
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.hcBgRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.hcBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)

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
            .foregroundColor(.hcTextMuted)
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("ABOUT")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.hcTextMuted)
                    .textCase(.uppercase)
            }
        }
    }
}

// MARK: - Section Label

private struct AboutSectionLabel: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(.custom("Outfit-Regular", size: 9))
                .tracking(3)
                .foregroundColor(.hcTextGhost)
            Spacer()
        }
    }
}

// MARK: - Link Row

private struct AboutLinkRow: View {
    let label: String
    let detail: String
    let url: URL?

    var body: some View {
        Button(action: {
            guard let url = url else { return }
            UIApplication.shared.open(url)
        }) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.hcTextGhost)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.custom("Outfit-Regular", size: 12))
                        .foregroundColor(.hcTextBody)
                    Text(detail)
                        .font(.custom("Outfit-Light", size: 10))
                        .foregroundColor(.hcTextFaint)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}
