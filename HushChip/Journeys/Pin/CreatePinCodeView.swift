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
//  CreatePinCodeView.swift
//  HushChip — PIN creation screen (new card / PIN update)

import Foundation
import SwiftUI

// MARK: - Navigation types (used by CreatePinCode and ConfirmPinCode)

enum PinCodeNavigationPath: Hashable {
    case createPinCode
    case confirmPinCode
    case updatePinCodeDefineNew
    case updatePinCodeConfirmNew
    case createPinCodeForBackupCard
    case confirmPinCodeForBackupCard
}

struct PinCodeNavigationData: Hashable {
    let mode: PinCodeNavigationPath
    let pinCode: String?
}

// MARK: - Create PIN view

struct CreatePinCodeView: View {
    @Binding var homeNavigationPath: NavigationPath
    @State private var pinCode: String = ""
    @State private var shouldShowPinCodeError: Bool = false
    @FocusState private var isInputFocused: Bool

    @State private var useKeyboard: Bool = false

    var pinCodeNavigationData: PinCodeNavigationData

    // MARK: - Derived strings

    func getHeading() -> String {
        switch pinCodeNavigationData.mode {
        case .createPinCode, .createPinCodeForBackupCard:
            return "CHOOSE A PIN"
        case .updatePinCodeDefineNew:
            return "NEW PIN"
        default:
            return "CHOOSE A PIN"
        }
    }

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
                Text(getHeading())
                    .font(.outfit(.regular, size: 14))
                    .tracking(3)
                    .foregroundColor(.hcTextBright)

                Spacer().frame(height: 36)

                // ── Dot row ────────────────────────────────────────────
                PinDotRow(pinCount: pinCode.count)
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
                                        shouldShowPinCodeError = false
                                        if pinCode.count > 16 {
                                            pinCode = String(pinCode.prefix(16))
                                            return
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                            }
                        }
                    )
                    .onChange(of: pinCode) { _ in
                        if !useKeyboard { shouldShowPinCodeError = false }
                    }

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
                            .foregroundColor(.hcTextGhost)
                    }

                    Spacer().frame(height: 8)
                }

                // Inline validation error
                if shouldShowPinCodeError {
                    Text(String(localized: "invalidPinCode"))
                        .font(.outfit(.light, size: 11))
                        .foregroundColor(.hcDanger)
                        .transition(.opacity)
                }

                Spacer().frame(height: 28)

                // ── RED WARNING BOX ──────────────────────────────────────
                Text("If you forget your PIN, the card locks permanently. There is no recovery.")
                    .font(.outfit(.light, size: 12))
                    .foregroundColor(.hcDanger)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.hcDangerBg)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.hcDangerBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 0)

                Spacer()

                // Continue button
                Button(action: handleNext) {
                    Text("CONTINUE")
                        .font(.outfit(.regular, size: 11))
                        .tracking(4)
                        .foregroundColor(pinCode.count >= 4 ? .hcTextBright : .hcTextGhost)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(pinCode.count >= 4 ? Color.hcBorder : Color.hcBgSurface)
                        .cornerRadius(Dimensions.buttonCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                                .stroke(pinCode.count >= 4 ? Color.hcBorderHover : Color.hcBorder,
                                        lineWidth: 1)
                        )
                }
                .disabled(pinCode.count < 4)
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

    private func handleNext() {
        guard Validator.isPinValid(pin: pinCode) else {
            shouldShowPinCodeError = true
            return
        }
        if pinCodeNavigationData.mode == .createPinCode {
            homeNavigationPath.append(NavigationRoutes.confirmPinCode(
                PinCodeNavigationData(mode: .confirmPinCode, pinCode: pinCode)))
        } else if pinCodeNavigationData.mode == .createPinCodeForBackupCard {
            homeNavigationPath.append(NavigationRoutes.confirmPinCode(
                PinCodeNavigationData(mode: .confirmPinCodeForBackupCard, pinCode: pinCode)))
        } else if pinCodeNavigationData.mode == .updatePinCodeDefineNew {
            homeNavigationPath.append(NavigationRoutes.confirmPinCode(
                PinCodeNavigationData(mode: .updatePinCodeConfirmNew, pinCode: pinCode)))
        }
    }
}
