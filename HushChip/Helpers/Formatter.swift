// Copyright (c) 2026 Gridmark Technologies Ltd (HushChip)
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// Licensed under GPL-3.0
//
//
//  Formatter.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 02/05/2024.
//

import Foundation

private struct FormatterConstants {
    static let dateTimeFormat = "dd/MM/yyyy HH:mm:ss"
}

public class Formatter {
    func dateTimeToString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = FormatterConstants.dateTimeFormat
        return formatter.string(from: date)
    }
}
