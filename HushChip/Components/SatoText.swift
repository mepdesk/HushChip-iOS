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
//  SatoText.swift  (HushChip Ghost typography — Outfit only)
//  Seedkeeper
//
//  Created by Lionel Delvaux on 17/04/2024.
//

import Foundation
import SwiftUI

// MARK: - Text styles

enum SatoTextStyle {
    // ── New Ghost / SPINE styles ──────────────────────────────────────────
    case navTitle          // Outfit-Regular / 11pt / +5pt / uppercase / hcTextMuted
    case navButton         // Outfit-Regular / 10pt / +2pt / uppercase / hcTextMuted
    case sectionLabel      // Outfit-Regular /  9pt / +3pt / uppercase / hcTextMuted
    case cardTitle         // Outfit-Regular / 12pt /  0pt / none      / hcTextBody
    case body              // Outfit-Light   / 12pt /  0pt / none      / hcTextBody
    case onboardingHeading // Outfit-Light   / 16pt / +0.5pt / none    / hcTextBright
    case inputText         // Outfit-Light   / 13pt /  0pt / none      / hcTextBright
    case buttonText        // Outfit-Regular / 11pt / +4pt / uppercase / hcTextBright
    case tabBarLabel       // Outfit-Regular /  8pt / +1pt / uppercase / hcTextMuted
    case tagBadge          // Outfit-Regular /  9pt / +1pt / uppercase / hcTextMuted
    case counterText       // Outfit-Regular /  9pt / +1.5pt / uppercase / hcTextMuted

    // ── Legacy styles — backward compat, remapped to Ghost ───────────────
    case title             // → onboardingHeading  (Outfit-Light 16pt hcTextBright)
    case lightTitle        // → navTitle            (Outfit-Regular 11pt uppercase)
    case lightTitleDark    // → navTitle            (toolbar principal)
    case lightTitleSmall   // → navTitle small
    case subtitle          // → body
    case lightSubtitle     // → body
    case lightSubtitleDark // → sectionLabel
    case extraLightSubtitle// → small body
    case subtitleBold      // → buttonText
    case viewTitle         // → onboardingHeading
    case cellTitle         // → cardTitle
    case slotTitle         // → onboardingHeading large
    case balanceLarge      // → onboardingHeading
    case cellSmallTitle    // → small body
    case SKMenuItemTitle   // → cardTitle
    case SKMenuItemSubtitle// → small body / hcTextMuted
    case SKStrongBodyDark  // → body / hcTextBody
    case SKStrongBodyLight // → body / hcTextBody

    // MARK: Font

    var font: Font {
        switch self {
        // Outfit-Regular (400)
        case .navTitle, .navButton, .sectionLabel, .cardTitle, .buttonText,
             .tabBarLabel, .tagBadge, .counterText,
             .lightTitle, .lightTitleDark, .lightTitleSmall,
             .SKMenuItemTitle, .cellTitle, .subtitleBold:
            return .custom("Outfit-Regular", size: fontSize)

        // Outfit-Light (300)
        case .body, .onboardingHeading, .inputText,
             .title, .viewTitle, .balanceLarge,
             .subtitle, .lightSubtitle, .lightSubtitleDark,
             .extraLightSubtitle, .SKStrongBodyDark, .SKStrongBodyLight,
             .SKMenuItemSubtitle, .cellSmallTitle:
            return .custom("Outfit-Light", size: fontSize)

        // Outfit-ExtraLight (200)
        case .slotTitle:
            return .custom("Outfit-ExtraLight", size: fontSize)
        }
    }

    // MARK: Size

    var fontSize: CGFloat {
        switch self {
        case .tabBarLabel:                                                 return 8
        case .navButton:                                                   return 10
        case .navTitle, .lightTitle, .lightTitleDark, .lightTitleSmall:   return 11
        case .sectionLabel, .tagBadge, .counterText,
             .cellSmallTitle, .extraLightSubtitle:                        return 9
        case .buttonText, .subtitleBold, .SKMenuItemSubtitle:             return 11
        case .cardTitle, .SKMenuItemTitle, .cellTitle,
             .body, .subtitle, .lightSubtitle, .lightSubtitleDark,
             .SKStrongBodyDark, .SKStrongBodyLight:                        return 12
        case .inputText:                                                   return 13
        case .onboardingHeading, .title, .viewTitle,
             .slotTitle, .balanceLarge:                                   return 16
        }
    }

    // MARK: Letter spacing

    var letterSpacing: CGFloat {
        switch self {
        case .navTitle, .lightTitle, .lightTitleDark, .lightTitleSmall:   return 5
        case .navButton:                                                   return 2
        case .sectionLabel, .lightSubtitleDark:                           return 3
        case .buttonText, .subtitleBold:                                  return 4
        case .tabBarLabel, .tagBadge:                                     return 1
        case .counterText:                                                 return 1.5
        case .onboardingHeading, .title, .viewTitle, .balanceLarge:       return 0.5
        default:                                                           return 0
        }
    }

    // MARK: Uppercase

    var isUppercase: Bool {
        switch self {
        case .navTitle, .navButton, .sectionLabel, .buttonText,
             .tabBarLabel, .tagBadge, .counterText,
             .lightTitle, .lightTitleDark, .lightTitleSmall,
             .lightSubtitleDark, .subtitleBold:
            return true
        default:
            return false
        }
    }

    // MARK: Colour

    var textColor: Color {
        switch self {
        // Muted — navigation chrome, labels, secondary info
        case .navTitle, .navButton, .sectionLabel,
             .lightTitle, .lightTitleDark, .lightTitleSmall,
             .lightSubtitleDark, .tabBarLabel, .tagBadge, .counterText,
             .SKMenuItemSubtitle, .extraLightSubtitle, .cellSmallTitle:
            return .hcTextMuted

        // Body — primary content, card text
        case .body, .subtitle, .lightSubtitle, .cardTitle, .cellTitle,
             .inputText, .SKStrongBodyDark, .SKStrongBodyLight, .SKMenuItemTitle:
            return .hcTextBody

        // Bright — headings, buttons, emphasis
        case .onboardingHeading, .title, .viewTitle, .balanceLarge,
             .slotTitle, .buttonText, .subtitleBold:
            return .hcTextBright
        }
    }

    // MARK: Line spacing

    var lineSpacing: CGFloat { return 6 }
}

// MARK: - SatoText view

struct SatoText: View {
    var text: String
    var style: SatoTextStyle
    var alignment: TextAlignment = .center
    var forcedColor: Color? = nil

    var body: some View {
        Text(.init(text))
            .font(style.font)
            .tracking(style.letterSpacing)
            .lineSpacing(style.lineSpacing)
            .multilineTextAlignment(alignment)
            .foregroundColor(forcedColor ?? style.textColor)
            .textCase(style.isUppercase ? .uppercase : nil)
    }
}
