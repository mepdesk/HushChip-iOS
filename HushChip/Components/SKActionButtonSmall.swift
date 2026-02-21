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
//  SKActionButtonSmall.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 21/06/2024.
//

import Foundation
import SwiftUI

struct SKActionButtonSmall: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            HStack {
                Text(title)
                    .foregroundColor(.hcTextBright)
                    .font(.custom("Outfit-Regular", size: 18))
                    .lineLimit(1)
                    .padding(.leading, 10)

                Spacer()
                    .frame(width: 4)

                Image(icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.hcTextBright)
                    .padding(.trailing, 10)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 40)
            .background(Color.hcBorder)
            .cornerRadius(Dimensions.buttonCornerRadius)
        }
    }
}
