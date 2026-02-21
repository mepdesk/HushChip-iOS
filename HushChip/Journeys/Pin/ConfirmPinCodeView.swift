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
//  ConfirmPinCodeView.swift
//  HushChip — PIN confirmation screen (new card / PIN update)

import Foundation
import SwiftUI

struct ConfirmPinCodeView: View {
    @EnvironmentObject var cardState: CardState
    @Binding var homeNavigationPath: NavigationPath

    @State private var pinCodeConfirmation: String = ""
    @State private var shouldShowPinCodeError: Bool = false
    @FocusState private var isInputFocused: Bool

    @State private var useKeyboard: Bool = false

    var pinCodeNavigationData: PinCodeNavigationData

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.hcBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Lock icon
                SmallLockIcon()
                    .padding(.bottom, 28)

                // Heading
                Text("CONFIRM YOUR PIN")
                    .font(.outfit(.regular, size: 14))
                    .tracking(3)
                    .foregroundColor(.hcTextBright)

                Spacer().frame(height: 36)

                // ── Dot row ────────────────────────────────────────────
                PinDotRow(pinCount: pinCodeConfirmation.count,
                          wrongFlash: shouldShowPinCodeError)
                    .frame(height: 24)
                    .contentShape(Rectangle())
                    .onTapGesture { if useKeyboard { isInputFocused = true } }
                    .background(
                        Group {
                            if useKeyboard {
                                SecureField("", text: $pinCodeConfirmation)
                                    .opacity(0.001)
                                    .focused($isInputFocused)
                                    .onChange(of: pinCodeConfirmation) { _ in
                                        shouldShowPinCodeError = false
                                        if pinCodeConfirmation.count > 16 {
                                            pinCodeConfirmation = String(pinCodeConfirmation.prefix(16))
                                            return
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                            }
                        }
                    )
                    .onChange(of: pinCodeConfirmation) { _ in
                        if !useKeyboard { shouldShowPinCodeError = false }
                    }

                Spacer().frame(height: 20)

                // ── Numeric keypad or system keyboard ─────────────────────
                if !useKeyboard {
                    NumericKeypad(text: $pinCodeConfirmation)
                        .padding(.horizontal, 8)

                    Spacer().frame(height: 12)

                    Button(action: {
                        useKeyboard = true
                        pinCodeConfirmation = ""
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isInputFocused = true
                        }
                    }) {
                        Text("Use keyboard instead")
                            .font(.custom("Outfit-Light", size: 11))
                            .foregroundColor(.hcTextGhost)
                    }

                    Spacer().frame(height: 8)
                }

                // Mismatch error
                if shouldShowPinCodeError {
                    Text(String(localized: "pinCodeDoesNotMatch"))
                        .font(.outfit(.light, size: 11))
                        .foregroundColor(.hcDanger)
                        .transition(.opacity)
                }

                Spacer()

                // Confirm button
                Button(action: handleConfirm) {
                    Text("CONFIRM")
                        .font(.outfit(.regular, size: 11))
                        .tracking(4)
                        .foregroundColor(pinCodeConfirmation.count >= 4 ? .hcTextBright : .hcTextGhost)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(pinCodeConfirmation.count >= 4 ? Color.hcBorder : Color.hcBgSurface)
                        .cornerRadius(Dimensions.buttonCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                                .stroke(pinCodeConfirmation.count >= 4 ? Color.hcBorderHover : Color.hcBorder,
                                        lineWidth: 1)
                        )
                }
                .disabled(pinCodeConfirmation.count < 4)
                .padding(.horizontal, 24)

                Spacer().frame(height: 32)
            }
            .padding([.leading, .trailing], 24)
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
            .foregroundColor(.hcTextMuted)
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SETUP")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.hcTextMuted)
                    .textCase(.uppercase)
            }
        }
        .onAppear { if useKeyboard { isInputFocused = true } }
    }

    // MARK: - Actions

    private func handleConfirm() {
        guard let pinCodeToValidate = pinCodeNavigationData.pinCode,
              Validator.isPinValid(pin: pinCodeConfirmation),
              pinCodeConfirmation == pinCodeToValidate else {
            shouldShowPinCodeError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        cardState.pinCodeToSetup = pinCodeConfirmation

        if pinCodeNavigationData.mode == .confirmPinCode {
            cardState.requestInitPinOnCard()
        } else if pinCodeNavigationData.mode == .updatePinCodeConfirmNew {
            cardState.requestUpdatePinOnCard(newPin: pinCodeToValidate)
        } else if pinCodeNavigationData.mode == .confirmPinCodeForBackupCard {
            cardState.requestInitPinOnBackupCard()
        }
    }
}
