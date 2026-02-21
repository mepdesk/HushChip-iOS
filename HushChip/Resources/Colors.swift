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
//  Colors.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 17/04/2024.
//

import Foundation
import SwiftUI

// MARK: - HushChip Ghost Palette

extension Color {
    static let hcBg           = Color(hex: "#09090b") // App background
    static let hcBgRaised     = Color(hex: "#0e0e10") // Cards, list items
    static let hcBgSurface    = Color(hex: "#111113") // Card interiors, input backgrounds
    static let hcBorder       = Color(hex: "#1a1a1e") // Default borders, dividers
    static let hcBorderHover  = Color(hex: "#28282e") // Active borders, selected states
    static let hcTextGhost    = Color(hex: "#38383e") // Section labels, placeholders
    static let hcTextFaint    = Color(hex: "#5a5a64") // Secondary text, descriptions
    static let hcTextMuted    = Color(hex: "#8a8a96") // Nav titles, body text
    static let hcTextBody     = Color(hex: "#b8b8c4") // Secret labels, primary content
    static let hcTextBright   = Color(hex: "#d8d8e0") // Headings, emphasis
    static let hcTextWhite    = Color(hex: "#e4e4ec") // Maximum emphasis (rare)
    static let hcDanger       = Color(hex: "#c45555") // Wrong PIN, delete, warnings
    static let hcDangerBorder = Color(hex: "#3d2020") // Warning box borders
    static let hcDangerBg     = Color(red: 60/255, green: 30/255, blue: 30/255, opacity: 0.15)
}

// MARK: - Color(hex:) initializer

extension Color {
    init(hex: String) {
        let r, g, b, a: Double
        let start = hex.hasPrefix("#") ? hex.index(hex.startIndex, offsetBy: 1) : hex.startIndex
        let hexColor = String(hex[start...])
        let scanner = Scanner(string: hexColor)
        var hexNumber: UInt64 = 0
        guard scanner.scanHexInt64(&hexNumber) else {
            self = .red
            return
        }
        if hexColor.count == 8 {
            r = Double((hexNumber & 0xff000000) >> 24) / 255
            g = Double((hexNumber & 0x00ff0000) >> 16) / 255
            b = Double((hexNumber & 0x0000ff00) >> 8) / 255
            a = Double(hexNumber & 0x000000ff) / 255
        } else {
            r = Double((hexNumber & 0xff0000) >> 16) / 255
            g = Double((hexNumber & 0x00ff00) >> 8) / 255
            b = Double(hexNumber & 0x0000ff) / 255
            a = 1.0
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Outfit font helper (SPINE typography)

extension Font {
    static func outfit(_ weight: Font.Weight, size: CGFloat) -> Font {
        let name: String
        switch weight {
        case .ultraLight: name = "Outfit-ExtraLight"
        case .light:      name = "Outfit-Light"
        case .regular:    name = "Outfit-Regular"
        case .medium:     name = "Outfit-Medium"
        default:          name = "Outfit-Regular"
        }
        return .custom(name, size: size)
    }
}

// MARK: - Legacy color aliases (backward compatibility — mapped to Ghost values)

struct Colors {
    static let darkPurple: Color     = .hcBgRaised
    static let lightPurple: Color    = .hcBorderHover
    static let darkMenuButton: Color = .hcBgRaised
    static let lightMenuButton: Color = .hcBgSurface
    static let menuSeparator: Color  = .hcBorder
    static let ledGreen: Color       = .hcBorderHover
    static let ledRed: Color         = .hcDanger
    static let buttonDefault: Color  = .hcBorder
    static let buttonRegular: Color  = .hcBorder
    static let buttonInform: Color   = .hcBorderHover
    static let separator: Color      = .hcBorder
    static let purpleBtn: Color      = .hcBorder
}
