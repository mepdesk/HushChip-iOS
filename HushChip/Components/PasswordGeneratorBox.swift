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
//  PasswordGeneratorBox.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 25/05/2024.
//

import Foundation
import SwiftUI

class PasswordOptions: ObservableObject {
    @Published var passwordLength: Double = 16
    @Published var includeLowercase: Bool = true
    @Published var includeUppercase: Bool = true
    @Published var includeNumbers: Bool = true
    @Published var includeSymbols: Bool = false

    func userSelectedAtLeastOneIncludeOption() -> Bool {
        return includeLowercase || includeUppercase || includeNumbers || includeSymbols
    }
}

struct PasswordGeneratorBox: View {
    @ObservedObject var options: PasswordOptions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Length slider
            HStack {
                Text("LENGTH")
                    .font(.custom("Outfit-Regular", size: 9))
                    .tracking(3)
                    .foregroundColor(.hcTextGhost)
                Spacer()
                Text("\(Int(options.passwordLength))")
                    .font(.custom("Outfit-Regular", size: 12))
                    .foregroundColor(.hcTextBright)
            }

            Slider(value: $options.passwordLength, in: 8...64, step: 1)
                .tint(.hcBorderHover)

            // Character set toggles
            VStack(spacing: 8) {
                PasswordToggleRow(label: "Uppercase (A-Z)", isOn: $options.includeUppercase)
                PasswordToggleRow(label: "Lowercase (a-z)", isOn: $options.includeLowercase)
                PasswordToggleRow(label: "Numbers (0-9)", isOn: $options.includeNumbers)
                PasswordToggleRow(label: "Symbols (!@#$...)", isOn: $options.includeSymbols)
            }
        }
        .padding(16)
        .background(Color.hcBgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.hcBorder, lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

private struct PasswordToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.custom("Outfit-Light", size: 12))
                .foregroundColor(.hcTextBody)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .hcBorderHover))
                .labelsHidden()
        }
    }
}
