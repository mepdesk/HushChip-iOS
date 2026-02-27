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
//  HeaderView.swift
//  Signstr
//
//  Created by Lionel Delvaux on 17/04/2024.
//

import Foundation
import SwiftUI

// MARK: - Card-mark icon (card outline with chip rectangle)

struct CardMarkIcon: View {
    var width: CGFloat = 28
    var height: CGFloat = 19
    var color: Color = .sgTextMuted

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3)
                .stroke(color, lineWidth: 1.2)
                .frame(width: width, height: height)

            // EMV chip rectangle
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color.opacity(0.6))
                .frame(width: 8, height: 6)
                .padding(.top, 4)
                .padding(.leading, 5)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Header View

struct HeaderView: View {
    @EnvironmentObject var cardState: CardState
    @Binding var homeNavigationPath: NavigationPath

    var body: some View {
        HStack {
            // Left: Card-mark icon
            CardMarkIcon()
                .padding(.leading, Dimensions.lateralPadding)

            Spacer()

            // Centre: HUSHCHIP wordmark
            Text("HUSHCHIP")
                .font(.custom("Outfit-Regular", size: 11))
                .tracking(5)
                .foregroundColor(.sgTextBright)

            Spacer()

            // Right: Rescan + Settings
            HStack(spacing: 14) {
                if cardState.cardStatus != nil {
                    Button(action: {
                        cardState.scan()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.sgTextMuted)
                    }
                }

                Button(action: {
                    homeNavigationPath.append(NavigationRoutes.menu)
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.sgTextMuted)
                }
            }
            .padding(.trailing, Dimensions.lateralPadding)
        }
        .frame(height: 52)
        .background(Color.sgBg)
        .overlay(
            Rectangle()
                .fill(Color.sgBorder.opacity(0.6))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
