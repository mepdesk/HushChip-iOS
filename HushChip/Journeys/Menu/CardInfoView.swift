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
//  CardInfoView.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 02/05/2024.
//

import Foundation
import SwiftUI

struct CardInfoView: View {
    // MARK: - Properties
    @EnvironmentObject var cardState: CardState
    @Binding var homeNavigationPath: NavigationPath
    @State var shouldShowAuthenticityScreen = false

    // MARK: - Literals
    let title = "cardInfo"
    //let authentikeyTitle = "authentikeyTitle" //TODO: translate

    let ownerTitle = "cardOwnershipStatus"
    let ownerText = "youAreTheCardOwner"
    let notOwnerText = "youAreNotTheCardOwner"
    let unclaimedOwnershipText = "cardHasNoOwner"
    let unknownOwnershipText = "Scan card to get ownership status"

    let cardVersionTitle = "cardVersion"

    let cardGenuineTitle = "**cardAuthenticity**"
    let cardGenuineText = "thisCardIsGenuine"
    let cardNotGenuineText = "thisCardIsNotGenuine"
    let certButtonTitle = "certDetails"

    func getCardVersionString() -> String {
        if let cardStatus = cardState.cardStatus {
            let str = "HushChip v\(cardStatus.protocolMajorVersion).\(cardStatus.protocolMinorVersion)-\(cardStatus.appletMajorVersion).\(cardStatus.appletMinorVersion)"
            return str
        } else {
            return "n/a"
        }
    }

    // MARK: - View
    var body: some View {
        ZStack {
            Color.hcBg.ignoresSafeArea()

            VStack {
                Spacer()
                    .frame(height: 66)

                // CARD VERSION
                SatoText(text: "cardVersionTitle", style: .lightSubtitleDark)
                Spacer()
                    .frame(height: 14)
                CardInfoBox(text: self.getCardVersionString(), backgroundColor: Color.hcBgSurface)

                Spacer()
                    .frame(height: 20)

                SatoText(text: "cardLabel", style: .lightSubtitleDark)
                Spacer()
                    .frame(height: 14)

                EditableCardInfoBox(mode: .text(self.cardState.cardLabel), backgroundColor: Color.hcBgSurface) { result in
                    switch result {
                    case .text(let value):
                        self.cardState.requestSetCardLabel(label: value)
                    default:
                        break
                    }
                }

                Spacer()
                    .frame(height: 20)

                SatoText(text: "pinCodeBold", style: .lightSubtitleDark)
                Spacer()
                    .frame(height: 14)
                EditableCardInfoBox(mode: .pin, backgroundColor: Color.hcBgSurface) { result in
                    switch result {
                    case .pin:
                        guard let cardStatus = cardState.cardStatus else {
                            return
                        }
                        homeNavigationPath.append(NavigationRoutes.editPinCode)
                    default:
                        break
                    }
                }

                Spacer()

            }.padding([.leading, .trailing], 20)
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
                Text("CARD INFO")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.hcTextMuted)
                    .textCase(.uppercase)
            }
        }
    }
}
