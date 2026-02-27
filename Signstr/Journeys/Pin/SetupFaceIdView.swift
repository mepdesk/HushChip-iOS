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
//  SetupFaceIdView.swift
//  Signstr
//
//  Created by Lionel Delvaux on 21/04/2024.
//

import Foundation
import SwiftUI

struct FaceIdNavData: Hashable {
    let pinCode: String
    let authentiKey: String
}

struct SetupFaceIdView: View {
    // MARK: - Properties
    @Binding var homeNavigationPath: NavigationPath
    var navData: FaceIdNavData

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            VStack {

                Spacer()

                SatoText(text: "unlockWithFaceIdTitle", style: .title)

                Spacer().frame(height: 10)

                SatoText(text: "unlockWithFaceIdSubtitle", style: .SKMenuItemTitle)

                Spacer().frame(height: 24)

                Image("il_face_id")
                    .resizable()
                    .frame(width: 100, height: 100)

                Spacer()

                Button(action: {
                    homeNavigationPath = .init()
                }) {
                    SatoText(text: "notNow", style: .SKMenuItemTitle)
                }

                Spacer()
                    .frame(height: 16)

                SKButton(text: String(localized: "enable"), style: .regular, horizontalPadding: 66, action: {
                    // TODO: trigger faceId logic
                })

                Spacer().frame(height: 16)

            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            homeNavigationPath = .init()
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
                Text("SETUP")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
            }
        }
    }
}
