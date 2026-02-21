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
//  SecureTextInput.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 17/04/2024.
//

import SwiftUI

struct SecureTextInput: View {
    // MARK: - Properties
    let placeholder: String
    @State private var showText: Bool = false
    @Binding var text: String
    var onCommit: (()->Void)?

    var body: some View {

        HStack {
            ZStack {
                SecureField(placeholder, text: $text, onCommit: {
                    onCommit?()
                })
                .opacity(showText ? 0 : 1)


                if showText {
                    HStack {
                        Text(text)
                            .lineLimit(1)

                        Spacer()
                    }
                }
            }

            Button(action: {
                showText.toggle()
            }, label: {
                Image(systemName: showText ? "eye.slash" : "eye")
            })
            .accentColor(.hcTextBright)
        }
        .padding()
        .background(Color.hcBgSurface)
        .overlay(RoundedRectangle(cornerRadius: Dimensions.inputCornerRadius)
                    .stroke(Color.hcBorder, lineWidth: 1)
                    .foregroundColor(.clear))
        .cornerRadius(Dimensions.inputCornerRadius)
    }

}
