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
//  PinCodeView.swift
//  Signstr — PIN unlock screen (existing card)

import Foundation
import SwiftUI

// MARK: - Small lock illustration (reused by all PIN screens)

struct SmallLockIcon: View {
    var color: Color = .sgTextFaint

    var body: some View {
        ZStack {
            // Shackle arc — trim(0.5 → 1.0) traces the top half (∩)
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 24, height: 24)
                .offset(y: -14)

            // Left leg
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 14)
                .offset(x: -12, y: -6)

            // Right leg
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 14)
                .offset(x: 12, y: -6)

            // Lock body
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.sgBgRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 6).stroke(color, lineWidth: 1.5)
                )
                .frame(width: 38, height: 30)
                .offset(y: 12)

            // Keyhole dot
            Circle()
                .fill(Color.sgBgSurface)
                .frame(width: 8, height: 8)
                .offset(y: 11)
        }
        .frame(width: 52, height: 52)
    }
}

// MARK: - PIN dot row (reused by all PIN screens)

struct PinDotRow: View {
    let pinCount: Int
    var wrongFlash: Bool = false

    /// Always show at least 4 slots so the row has a stable minimum width.
    private var slotCount: Int { max(min(pinCount, 16), 4) }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<slotCount, id: \.self) { i in
                let filled = i < pinCount
                Circle()
                    .fill(filled
                          ? (wrongFlash ? Color.sgDanger : Color.sgTextMuted)
                          : Color.clear)
                    .overlay(
                        Circle().stroke(
                            filled
                                ? Color.clear
                                : (wrongFlash ? Color.sgDanger.opacity(0.5) : Color.sgBorder),
                            lineWidth: 1
                        )
                    )
                    .frame(width: 10, height: 10)
            }
        }
    }
}

// MARK: - PIN unlock view

struct PinCodeView: View {
    @EnvironmentObject var cardState: CardState
    @Binding var homeNavigationPath: NavigationPath

    @State private var pinCode: String = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var wrongFlash: Bool = false
    @FocusState private var isInputFocused: Bool

    @State private var useKeyboard: Bool = false

    var actionAfterPin: ActionAfterPin

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Lock icon
                SmallLockIcon()
                    .padding(.bottom, 32)

                // Heading
                Text("ENTER YOUR PIN")
                    .font(.outfit(.regular, size: 14))
                    .tracking(3)
                    .foregroundColor(.sgTextBright)

                Spacer().frame(height: 36)

                // ── Dot row ────────────────────────────────────────────
                PinDotRow(pinCount: pinCode.count, wrongFlash: wrongFlash)
                    .offset(x: shakeOffset)
                    .frame(height: 24)
                    .contentShape(Rectangle())
                    .onTapGesture { if useKeyboard { isInputFocused = true } }
                    .background(
                        Group {
                            if useKeyboard {
                                SecureField("", text: $pinCode)
                                    .opacity(0.001)
                                    .focused($isInputFocused)
                                    .onChange(of: pinCode) { _ in
                                        if pinCode.count > 16 {
                                            pinCode = String(pinCode.prefix(16))
                                            return
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                            }
                        }
                    )

                Spacer().frame(height: 20)

                // ── Numeric keypad or system keyboard ─────────────────────
                if !useKeyboard {
                    NumericKeypad(text: $pinCode)
                        .padding(.horizontal, 8)

                    Spacer().frame(height: 12)

                    Button(action: {
                        useKeyboard = true
                        pinCode = ""
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isInputFocused = true
                        }
                    }) {
                        Text("Use keyboard instead")
                            .font(.custom("Outfit-Light", size: 11))
                            .foregroundColor(.sgTextGhost)
                    }

                    Spacer().frame(height: 8)
                }

                // Attempts remaining — shown only after at least one wrong attempt
                if cardState.consecutiveWrongPins > 0 {
                    let remaining = max(5 - cardState.consecutiveWrongPins, 0)
                    Text("\(remaining) attempt\(remaining == 1 ? "" : "s") remaining")
                        .font(.outfit(.light, size: 11))
                        .foregroundColor(remaining <= 3 ? .sgDanger : .sgTextFaint)
                        .transition(.opacity)
                        .animation(.easeIn(duration: 0.2), value: cardState.consecutiveWrongPins)
                }

                Spacer()

                // Confirm button — disabled until minimum PIN length met
                Button(action: confirmPin) {
                    Text("CONFIRM")
                        .font(.outfit(.regular, size: 11))
                        .tracking(4)
                        .foregroundColor(pinCode.count >= 4 ? .sgTextBright : .sgTextGhost)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(pinCode.count >= 4 ? Color.sgBorder : Color.sgBgSurface)
                        .cornerRadius(Dimensions.buttonCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                                .stroke(pinCode.count >= 4 ? Color.sgBorderHover : Color.sgBorder,
                                        lineWidth: 1)
                        )
                }
                .disabled(pinCode.count < 4)
                .padding(.horizontal, 24)

                Spacer().frame(height: 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            homeNavigationPath.removeLast()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                Text("Back")
                    .font(.custom("Outfit-Regular", size: 12))
            }
            .foregroundColor(.sgTextMuted)
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("UNLOCK")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
            }
        }
        .onAppear {
            if useKeyboard { isInputFocused = true }
            // Play wrong-PIN feedback if navigated here after a failed attempt
            if cardState.wrongPinAttempt {
                cardState.wrongPinAttempt = false
                wrongFlash = true
                triggerShake()
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                    withAnimation(.easeOut(duration: 0.3)) { wrongFlash = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func confirmPin() {
        guard Validator.isPinValid(pin: pinCode) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        switch actionAfterPin {
        case .rescanCard:
            cardState.pinForMasterCard = pinCode
            homeNavigationPath = .init()
            cardState.scan()
        case .continueBackupFlow:
            cardState.pinForBackupCard = pinCode
            homeNavigationPath.removeLast()
        }
    }

    // MARK: - Shake animation  (right → left → right smaller → centre)

    private func triggerShake() {
        let d: Double = 0.06
        withAnimation(.easeOut(duration: d))           { shakeOffset =  9 }
        DispatchQueue.main.asyncAfter(deadline: .now() + d) {
            withAnimation(.easeInOut(duration: d * 2)) { shakeOffset = -7 }
            DispatchQueue.main.asyncAfter(deadline: .now() + d * 2) {
                withAnimation(.easeInOut(duration: d * 2)) { shakeOffset =  4 }
                DispatchQueue.main.asyncAfter(deadline: .now() + d * 2) {
                    withAnimation(.easeOut(duration: d * 2)) { shakeOffset =  0 }
                }
            }
        }
    }
}
