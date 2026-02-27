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
//  SKButton.swift
//  Signstr
//
//  Created by Lionel Delvaux on 17/04/2024.
//

import Foundation
import SwiftUI

enum ButtonStyle {
    case confirm
    case inform
    case danger
    case regular

    var backgroundColor: Color {
        switch self {
        case .confirm, .inform, .regular: return .sgBorder
        case .danger: return .clear
        }
    }

    var borderColor: Color {
        switch self {
        case .danger: return .sgDangerBorder
        default: return .sgBorderHover
        }
    }

    var textColor: Color {
        switch self {
        case .danger: return .sgDanger
        default: return .sgTextBright
        }
    }

    var cornerRadius: CGFloat {
        return Dimensions.buttonCornerRadius
    }
}

struct SKButton: View {
    var text: String
    var style: ButtonStyle
    var horizontalPadding: CGFloat = 16
    var staticWidth: CGFloat?
    var isEnabled: Bool?
    var action: () -> Void

    var body: some View {
        Button(action: {
            if isEnabled ?? true {
                action()
            }
        }) {
            Text(text.uppercased())
                .font(.custom("Outfit-Regular", size: 11))
                .tracking(4)
                .foregroundColor(isEnabled != nil ? (isEnabled! ? style.textColor : Color.sgTextMuted) : style.textColor)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 8)
                .frame(maxWidth: staticWidth ?? .infinity, minHeight: 46, maxHeight: 46)
                .background(isEnabled != nil ? (isEnabled! ? style.backgroundColor : Color.sgBorder.opacity(0.5)) : style.backgroundColor)
                .cornerRadius(style.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .stroke(style.borderColor, lineWidth: 1)
                )
                .opacity(isEnabled != nil ? (isEnabled! ? 1.0 : 0.5) : 1.0)
        }
        .frame(height: 46)
        .frame(maxWidth: staticWidth ?? .infinity)
        .disabled(isEnabled == nil ? false : !(isEnabled!))
    }
}
