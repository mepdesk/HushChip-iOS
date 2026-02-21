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
//  ScanButton.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 17/04/2024.
//

import Foundation
import SwiftUI

struct ScanButton: View {
    let action: () -> Void
    @State private var animate = false

    private let initialSize: CGFloat = 85
    private let animationCircleSize: CGFloat = 85 * 2.5

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.hcBgRaised)
                    .overlay(Circle().stroke(Color.hcBorderHover, lineWidth: 1))
                    .frame(width: initialSize, height: initialSize)
                    .shadow(radius: 10)

                Text(String(localized: "clickNScan"))
                    .foregroundColor(.hcTextBright)
                    .fontWeight(.bold)
            }
            .contentShape(Rectangle())
            .frame(width: initialSize, height: initialSize)
        }
        .onAppear {
             animate = true
        }
    }
}
