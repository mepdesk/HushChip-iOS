// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/hushchip/Signstr-iOS
//
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// https://github.com/Toporin/Seedkeeper-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  ClipboardToast.swift
//  Signstr — "Clipboard cleared" toast overlay

import SwiftUI

/// A small bottom toast that fades in/out when the clipboard is auto-cleared.
struct ClipboardToast: View {
    @ObservedObject private var clipboard = ClipboardManager.shared

    var body: some View {
        VStack {
            Spacer()
            if clipboard.showClearedToast {
                Text("Clipboard cleared")
                    .font(.custom("Outfit-Light", size: 11))
                    .foregroundColor(.sgTextFaint)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.sgBgRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )
                    .cornerRadius(8)
                    .transition(.opacity)
                    .padding(.bottom, 24)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: clipboard.showClearedToast)
        .allowsHitTesting(false)
    }
}
