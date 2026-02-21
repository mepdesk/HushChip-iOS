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
//  SKLabel.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 21/06/2024.
//

import Foundation
import SwiftUI

struct SKLabel: View {
    let title: String
    let content: String

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                SatoText(text: title, style: .SKStrongBodyDark)
                Spacer()
            }
            Text(content)
                .font(.custom("Outfit-Regular", size: 16))
                .lineSpacing(24)
                .multilineTextAlignment(.leading)
                .foregroundColor(.hcTextBright)
                .frame(maxWidth: .infinity, minHeight: 33, maxHeight: 33)
                .background(Color.hcBgSurface)
                .cornerRadius(Dimensions.inputCornerRadius)
        }

    }
}
