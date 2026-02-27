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
//  AuhenticityView.swift
//  Signstr
//
//  Created by Lionel Delvaux on 02/05/2024.
//

import Foundation
import SwiftUI

struct AuthenticityView: View {
    // MARK: - Properties
    @EnvironmentObject var cardState: CardState
    @Binding var homeNavigationPath: NavigationPath
    @State var shouldShowDeviceInfo = false
    @State var shouldShowSubcaInfo = false

    func getCertificateInfo(cardState: CardState) -> String {
        var txt=""
        if (cardState.certificateCode == .success){
            txt += "Device authenticated successfully!"
            txt += "\n\n"
        } else {
            txt += "Failed to authenticate device!"
            txt += "\n\n"
            txt += cardState.getReasonFromPkiReturnCode(pkiReturnCode: cardState.certificateCode)
            txt += "\n\n"
        }
        txt += "Device info:"
        txt += "\n\n"
        txt += "Pubkey: \(cardState.certificateDic["devicePubkey"] ?? "(none)")"
        txt += "\n\n"
        txt += "Signature: \(cardState.certificateDic["deviceSig"] ?? "(none)")"
        txt += "\n\n"
        txt += "PEM: \(cardState.certificateDic["devicePem"] ?? "(none)")"
        txt += "\n\n"
        txt += "Subca info:"
        txt += "\n\n"
        txt += "Pubkey: \(cardState.certificateDic["subcaPubkey"] ?? "(none)")"
        txt += "\n\n"
        txt += "PEM: \(cardState.certificateDic["subcaPem"] ?? "(none)")"
        txt += "\n\n"
        return txt
    }

    // MARK: - Body
    var body: some View {
        ZStack {

            Color.sgBg.ignoresSafeArea()

            ScrollView{
                VStack {
                    Spacer()
                        .frame(height: 29)

                    Image("logo_signstr")
                        .resizable()
                        .frame(width: 250, height: 116)

                    Spacer()
                        .frame(height: 22)

                    // If condition to display authenticity state
                    Image(cardState.certificateCode == .success ? "il_authentic" : "il_not_authentic")
                        .resizable()
                        .frame(width: 150, height: 150)
                    Spacer()
                        .frame(height: 38)
                    SatoText(text: cardState.certificateCode == .success ? "authenticationSuccessText" : "authenticationFailedText", style: .SKStrongBodyDark)

                    Spacer()
                        .frame(height: 22)

                    // DEVICE CERT
                    CardInfoBox(
                        text: self.shouldShowDeviceInfo ? "hideDeviceCert" : "showDeviceCert",
                        backgroundColor: Color.sgDanger)
                    {
                        self.shouldShowDeviceInfo.toggle()
                    }
                        .padding([.leading, .trailing], 57)

                    if self.shouldShowDeviceInfo {
                        VStack {

                            HStack {
                                Spacer()

                                Image(systemName: "square.on.square")
                                    .frame(width: 15, height: 15)
                                    .foregroundColor(.sgTextMuted)
                                    .onTapGesture(count: 1) {
                                        // Copy to clipboard
                                    }
                            }

                            SatoText(text: "Pubkey: \n\(cardState.certificateDic["devicePubkey"] ?? "(none)")",style: .SKStrongBodyDark)

                            SatoText(text: "PEM: \n\(cardState.certificateDic["devicePem"] ?? "(none)")",style: .SKStrongBodyDark)
                        }
                        .padding(30)
                        .overlay(
                            RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                                .stroke(Color.sgDanger, lineWidth: 1)
                                .padding(15)
                        )
                    }

                    Spacer()
                        .frame(height: 33)

                    CardInfoBox(
                        text: self.shouldShowSubcaInfo ? "hideSubcaCert" : "showSubcaCert",
                        backgroundColor: Color.sgDanger)
                    {
                        self.shouldShowSubcaInfo.toggle()
                    }
                        .padding([.leading, .trailing], 57)

                    if self.shouldShowSubcaInfo {
                        VStack {
                            HStack {
                                Spacer()

                                Image(systemName: "square.on.square")
                                    .frame(width: 15, height: 15)
                                    .foregroundColor(.sgTextMuted)
                                    .onTapGesture(count: 1) {
                                        ClipboardManager.shared.copy(getCertificateInfo(cardState: cardState))
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                            }

                            SatoText(text: "Pubkey: \(cardState.certificateDic["subcaPubkey"] ?? "(none)")",style: .SKStrongBodyDark)

                            SatoText(text: "PEM: \(cardState.certificateDic["subcaPem"] ?? "(none)")",style: .SKStrongBodyDark)

                        }
                        .padding(30)
                        .overlay(
                            RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                                .stroke(Color.sgDanger, lineWidth: 1)
                                .padding(15)
                        )
                    }

                }
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
                Text("AUTHENTICITY")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
            }
        }
    }
}

