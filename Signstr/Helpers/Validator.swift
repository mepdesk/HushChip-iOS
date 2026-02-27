// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// Licensed under GPL-3.0
//
//
//  Validator.swift
//  Signstr
//
//  Created by Lionel Delvaux on 17/04/2024.
//

import Foundation

struct Validator {
    // Pin validation
    static func isPinValid(pin: String) -> Bool {
        return pin.count >= 4 && pin.count <= 16
    }
}
