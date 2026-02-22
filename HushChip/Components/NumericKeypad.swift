// Copyright (c) 2026 Gridmark Technologies Ltd (HushChip)
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// Licensed under GPL-3.0
//
// Copyright (c) 2026 Gridmark Technologies Ltd (HushChip)
// https://github.com/hushchip/HushChip-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  NumericKeypad.swift
//  HushChip — Custom 3×4 numeric keypad for PIN entry

import SwiftUI
import UIKit

struct NumericKeypad: View {
    @Binding var text: String
    var maxLength: Int = 16

    private let rows: [[KeypadKey]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.blank,      .digit("0"), .delete],
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<rows.count, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(0..<rows[row].count, id: \.self) { col in
                        keyView(for: rows[row][col])
                    }
                }
            }
        }
        .frame(maxWidth: 320)
    }

    @ViewBuilder
    private func keyView(for key: KeypadKey) -> some View {
        switch key {
        case .digit(let d):
            Button(action: { appendDigit(d) }) {
                Text(d)
                    .font(.custom("Outfit-Regular", size: 20))
                    .foregroundColor(.hcTextBright)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.hcBgRaised)
                    .cornerRadius(10)
            }
            .buttonStyle(KeypadButtonStyle())

        case .delete:
            Button(action: { deleteLast() }) {
                Image(systemName: "delete.left")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.hcTextBright)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.hcBgRaised)
                    .cornerRadius(10)
            }
            .buttonStyle(KeypadButtonStyle())

        case .blank:
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
    }

    private func appendDigit(_ d: String) {
        guard text.count < maxLength else { return }
        text.append(d)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func deleteLast() {
        guard !text.isEmpty else { return }
        text.removeLast()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Key types

private enum KeypadKey {
    case digit(String)
    case delete
    case blank
}

// MARK: - Highlight style

struct KeypadButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(configuration.isPressed ? Color.hcBorderHover.opacity(0.35) : Color.clear)
            )
    }
}
