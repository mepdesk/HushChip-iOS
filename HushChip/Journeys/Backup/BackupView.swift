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
//  BackupView.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 23/05/2024.
//

import Foundation

// BackupMode is used by CardState to track the backup state machine.
// The UI is now handled by BackupWizardView.
enum BackupMode {
    case start
    case pairBackupCard
    case backupImport
    case backupExport
}
