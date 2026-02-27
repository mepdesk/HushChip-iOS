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
//  AboutView.swift
//  Signstr
//
//  Created for the Signstr iOS app.
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
            Color.sgBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 32)

                    // Logo + version
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(.sgTextGhost)

                    Spacer().frame(height: 12)

                    Text("SIGNSTR")
                        .font(.custom("Outfit-Regular", size: 14))
                        .tracking(6)
                        .foregroundColor(.sgTextBright)

                    Spacer().frame(height: 4)

                    Text(appVersion)
                        .font(.custom("Outfit-Light", size: 11))
                        .foregroundColor(.sgTextFaint)

                    Spacer().frame(height: 36)

                    // ── OPEN SOURCE section ──
                    AboutSectionLabel(text: "OPEN SOURCE")

                    Spacer().frame(height: 10)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("This application is free software, distributed under the GNU General Public License v3.0. You are free to use, modify, and redistribute it under the terms of the licence.")
                            .font(.custom("Outfit-Light", size: 12))
                            .foregroundColor(.sgTextBody)
                            .lineSpacing(4)

                        Spacer().frame(height: 4)

                        AboutLinkRow(
                            label: "Source Code",
                            detail: "github.com/hushchip",
                            url: SignstrURL.sourceCode.url
                        )

                        AboutLinkRow(
                            label: "Licence",
                            detail: "GPL-3.0",
                            url: SignstrURL.licence.url
                        )
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.sgBgRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)

                    Spacer().frame(height: 28)

                    // ── ATTRIBUTION section ──
                    AboutSectionLabel(text: "ATTRIBUTION")

                    Spacer().frame(height: 10)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Signstr is based on SeedKeeper-iOS, an open-source project by Toporin, developed and maintained by Satochip S.R.L.")
                            .font(.custom("Outfit-Light", size: 12))
                            .foregroundColor(.sgTextBody)
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
                    .background(Color.sgBgRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)

                    Spacer().frame(height: 28)

                    // ── LEGAL section ──
                    AboutSectionLabel(text: "LEGAL")

                    Spacer().frame(height: 10)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Signstr is a product of Gridmark Technologies Ltd, registered in England and Wales.")
                            .font(.custom("Outfit-Light", size: 12))
                            .foregroundColor(.sgTextBody)
                            .lineSpacing(4)

                        Spacer().frame(height: 4)

                        AboutLinkRow(
                            label: "Privacy Policy",
                            detail: "signstr.com/privacy",
                            url: SignstrURL.privacy.url
                        )

                        AboutLinkRow(
                            label: "Terms of Service",
                            detail: "signstr.com/terms",
                            url: SignstrURL.terms.url
                        )

                        AboutLinkRow(
                            label: "Website",
                            detail: "signstr.com",
                            url: SignstrURL.howToUse.url
                        )
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.sgBgRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.sgBorder, lineWidth: 1)
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
            .foregroundColor(.sgTextMuted)
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("ABOUT")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
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
                .foregroundColor(.sgTextGhost)
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
                    .foregroundColor(.sgTextGhost)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.custom("Outfit-Regular", size: 12))
                        .foregroundColor(.sgTextBody)
                    Text(detail)
                        .font(.custom("Outfit-Light", size: 10))
                        .foregroundColor(.sgTextFaint)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}
