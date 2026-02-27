// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// Licensed under GPL-3.0
//
//
//  Constants.swift
//  Signstr
//
//  Created by Lionel Delvaux on 21/06/2024.
//

import Foundation

struct Constants {
    static let moreInfo = "https://signstr.com"

    struct Keys {
        static let firstTimeUse = "isFirstTimeUse"
        // True once the user has tapped "I understand" on the last onboarding screen.
        // On a fresh install this key is absent, so bool(forKey:) returns false → show onboarding.
        static let onboardingComplete = "onboardingComplete"
        // True once the user has created or imported a key.
        static let keySetupComplete = "keySetupComplete"
        // Biometrics (Face ID / Touch ID) enabled for signing approval. Defaults to true.
        static let biometricsEnabled = "signstr.biometrics_enabled"
    }
}
