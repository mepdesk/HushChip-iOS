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
//  CardInfoBox.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 02/05/2024.
//

import SwiftUI

struct CardInfoBox: View {
    let text: String
    let backgroundColor: Color
    var width: CGFloat?
    var action: (() -> Void)?

    var body: some View {
        SatoText(text: text, style: .SKStrongBodyLight)
            .padding()
            .frame(width: width, height: 55)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .background(backgroundColor)
            .cornerRadius(Dimensions.cardCornerRadius)
            .lineLimit(1)
            .foregroundColor(.hcTextBright)
            .onTapGesture {
                action?()
            }
    }
}
