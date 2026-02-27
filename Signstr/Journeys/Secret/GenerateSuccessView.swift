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
//  GenerateSuccessView.swift
//  Signstr
//
//  Created by Lionel Delvaux on 09/05/2024.
//

import SwiftUI
import UIKit

struct GenerateSuccessView: View {
    // MARK: - Properties
    @Binding var homeNavigationPath: NavigationPath
    @State var secretLabel: String

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Success icon
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(.sgBorderHover)

                Spacer().frame(height: 24)

                Text("SECRET SAVED")
                    .font(.custom("Outfit-Regular", size: 14))
                    .tracking(3)
                    .foregroundColor(.sgTextBright)

                Spacer().frame(height: 8)

                Text("Your secret has been stored on the card")
                    .font(.custom("Outfit-Light", size: 12))
                    .foregroundColor(.sgTextFaint)

                Spacer().frame(height: 24)

                // Secret label display
                Text(secretLabel)
                    .font(.custom("Outfit-Regular", size: 12))
                    .foregroundColor(.sgTextBody)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.sgBgSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )
                    .cornerRadius(8)

                Spacer()

                SKButton(text: "Done", style: .regular, horizontalPadding: 66, action: {
                    homeNavigationPath = .init()
                })

                Spacer().frame(height: 30)
            }
            .padding(.horizontal, Dimensions.lateralPadding)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SUCCESS")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
            }
        }
        .onAppear {
            // Haptic: secret saved
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
