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
//  BackupWizardView.swift
//  Signstr — 3-step backup wizard

import SwiftUI
import UIKit

// MARK: - Wizard step enum

enum BackupWizardStep: Int, CaseIterable {
    case source = 0
    case backup = 1
    case done = 2

    var label: String {
        switch self {
        case .source: return "Source"
        case .backup: return "Backup"
        case .done: return "Done"
        }
    }
}

// MARK: - BackupWizardView

struct BackupWizardView: View {
    @EnvironmentObject var cardState: CardState
    @Binding var homeNavigationPath: NavigationPath

    @State private var showIntro = true
    @State private var currentStep: BackupWizardStep = .source
    @State private var showError = false
    @State private var errorText = ""
    @State private var secretsCopied = 0
    @State private var totalSecrets = 0
    @State private var showStepCheckmark = false

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            if showIntro {
                introContent
            } else if showError {
                errorContent
            } else {
                wizardContent
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
                Text("BACKUP")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
            }
        }
        .onChange(of: cardState.mode) { newMode in
            handleModeChange(newMode)
        }
        .onReceive(NotificationCenter.default.publisher(for: .backupError)) { notification in
            if let msg = notification.object as? String {
                errorText = msg
                showError = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .backupComplete)) { notification in
            let count = notification.object as? Int ?? cardState.secretsForBackup.count
            secretsCopied = count
            totalSecrets = count
            currentStep = .done
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Intro Screen (Part A)

    private var introContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Two card icons with arrow
            HStack(spacing: 16) {
                cardIcon
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.sgTextFaint)
                cardIcon
            }

            Spacer().frame(height: 32)

            Text("Back Up Your Card")
                .font(.custom("Outfit-Regular", size: 16))
                .foregroundColor(.sgTextBright)

            Spacer().frame(height: 12)

            Text("Create an encrypted copy of all your secrets on a second card. You will need two cards.")
                .font(.custom("Outfit-Light", size: 12))
                .foregroundColor(.sgTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 24)

            // Warning box
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundColor(.sgDanger)
                Text("Both cards must be set up with a PIN before starting.")
                    .font(.custom("Outfit-Light", size: 11))
                    .foregroundColor(.sgDanger)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.sgDangerBg)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.sgDangerBorder, lineWidth: 1)
            )
            .cornerRadius(8)
            .padding(.horizontal, 24)

            Spacer()

            // Start Backup button
            SKButton(text: "Start Backup", style: .regular, action: {
                showIntro = false
                currentStep = .source
                cardState.mode = .start
            })
            .padding(.horizontal, 24)

            Spacer().frame(height: 32)
        }
    }

    // MARK: - Wizard Content (Part B)

    private var wizardContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            // Step indicators
            stepIndicators

            Spacer().frame(height: 32)

            // Step content
            switch currentStep {
            case .source:
                stepSourceContent
            case .backup:
                stepBackupContent
            case .done:
                stepDoneContent
            }
        }
    }

    // MARK: - Step Indicators

    private var stepIndicators: some View {
        HStack(spacing: 0) {
            ForEach(BackupWizardStep.allCases, id: \.rawValue) { step in
                if step.rawValue > 0 {
                    // Connecting line
                    Rectangle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.sgBorderHover : Color.sgBorder)
                        .frame(height: 1)
                }

                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(step.rawValue <= currentStep.rawValue ? Color.sgBorderHover : Color.clear)
                            .overlay(
                                Circle()
                                    .stroke(step.rawValue <= currentStep.rawValue ? Color.sgBorderHover : Color.sgBorder, lineWidth: 1)
                            )
                            .frame(width: 24, height: 24)

                        if step.rawValue < currentStep.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.sgTextBright)
                        } else if step.rawValue == currentStep.rawValue {
                            Circle()
                                .fill(Color.sgTextBright)
                                .frame(width: 6, height: 6)
                        }
                    }

                    Text(step.label)
                        .font(.custom("Outfit-Light", size: 10))
                        .foregroundColor(step.rawValue <= currentStep.rawValue ? Color.sgTextMuted : Color.sgTextGhost)
                }
            }
        }
        .padding(.horizontal, 48)
    }

    // MARK: - Step 1: Source

    private var stepSourceContent: some View {
        VStack(spacing: 0) {
            Spacer()

            NFCRipple()

            Spacer().frame(height: 16)

            Text("Tap your source card")
                .font(.custom("Outfit-Light", size: 14))
                .foregroundColor(.sgTextMuted)

            Spacer().frame(height: 6)

            Text("This is the card you want to copy FROM")
                .font(.custom("Outfit-Light", size: 11))
                .foregroundColor(.sgTextFaint)

            Spacer()

            SKButton(text: "Scan Source Card", style: .regular, action: {
                cardState.requestFetchSecretsForBackup()
            })
            .padding(.horizontal, 24)

            Spacer().frame(height: 32)
        }
    }

    // MARK: - Step 2: Backup

    private var backupPinReady: Bool {
        cardState.pinForBackupCard != nil
    }

    private var stepBackupContent: some View {
        VStack(spacing: 0) {
            Spacer()

            if backupPinReady {
                NFCRipple()

                Spacer().frame(height: 16)

                Text("Now tap your backup card")
                    .font(.custom("Outfit-Light", size: 14))
                    .foregroundColor(.sgTextMuted)

                Spacer().frame(height: 6)

                Text("This is the card you want to copy TO")
                    .font(.custom("Outfit-Light", size: 11))
                    .foregroundColor(.sgTextFaint)
            } else {
                // Backup card PIN not yet entered — prompt user
                SmallLockIcon()

                Spacer().frame(height: 24)

                Text("Enter your backup card's PIN")
                    .font(.custom("Outfit-Light", size: 14))
                    .foregroundColor(.sgTextMuted)

                Spacer().frame(height: 6)

                Text("This is the PIN for the card you want to copy TO")
                    .font(.custom("Outfit-Light", size: 11))
                    .foregroundColor(.sgTextFaint)
            }

            Spacer().frame(height: 16)

            if totalSecrets > 0 && backupPinReady {
                Text("Copying secret \(secretsCopied + 1) of \(totalSecrets)...")
                    .font(.custom("Outfit-Regular", size: 11))
                    .foregroundColor(.sgTextBody)

                Spacer().frame(height: 8)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.sgBgSurface)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.sgBorderHover)
                            .frame(width: geo.size.width * CGFloat(secretsCopied) / CGFloat(max(1, totalSecrets)), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 48)
            }

            Spacer()

            if backupPinReady {
                SKButton(text: "Scan Backup Card", style: .regular, action: {
                    totalSecrets = cardState.secretsForBackup.count
                    cardState.requestImportSecretsToBackupCard()
                })
                .padding(.horizontal, 24)
            } else {
                SKButton(text: "Enter Backup PIN", style: .regular, action: {
                    homeNavigationPath.append(NavigationRoutes.pinCode(.continueBackupFlow))
                })
                .padding(.horizontal, 24)
            }

            Spacer().frame(height: 32)
        }
    }

    // MARK: - Step 3: Done

    private var stepDoneContent: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.sgBorderHover)

            Spacer().frame(height: 20)

            Text("Backup Complete")
                .font(.custom("Outfit-Regular", size: 16))
                .foregroundColor(.sgTextBright)

            Spacer().frame(height: 8)

            Text("\(secretsCopied) secrets copied successfully")
                .font(.custom("Outfit-Light", size: 12))
                .foregroundColor(.sgTextFaint)

            Spacer()

            SKButton(text: "Done", style: .regular, action: {
                cardState.resetStateForBackupCard(clearPin: true)
                cardState.mode = .start
                homeNavigationPath = .init()
            })
            .padding(.horizontal, 24)

            Spacer().frame(height: 32)
        }
    }

    // MARK: - Error Content (Part C)

    private var errorContent: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Text("Backup Failed")
                    .font(.custom("Outfit-Regular", size: 14))
                    .foregroundColor(.sgDanger)

                Text(errorText)
                    .font(.custom("Outfit-Light", size: 11))
                    .foregroundColor(.sgTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                if secretsCopied > 0 {
                    Text("\(secretsCopied) of \(totalSecrets) secrets were copied before the error.")
                        .font(.custom("Outfit-Light", size: 11))
                        .foregroundColor(.sgTextFaint)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.sgBgRaised)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.sgDangerBorder, lineWidth: 1)
            )
            .cornerRadius(12)
            .padding(.horizontal, 24)

            Spacer()

            // Try Again
            SKButton(text: "Try Again", style: .regular, action: {
                showError = false
                errorText = ""
            })
            .padding(.horizontal, 24)

            Spacer().frame(height: 12)

            // Cancel
            Button(action: {
                cardState.resetStateForBackupCard(clearPin: true)
                cardState.mode = .start
                homeNavigationPath.removeLast()
            }) {
                Text("Cancel")
                    .font(.custom("Outfit-Light", size: 12))
                    .foregroundColor(.sgTextFaint)
            }

            Spacer().frame(height: 32)
        }
    }

    // MARK: - Card icon shape

    private var cardIcon: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.sgBgRaised)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.sgTextFaint, lineWidth: 1)
            )
            .overlay(
                // Mini chip
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.sgTextFaint.opacity(0.4))
                    .frame(width: 14, height: 10)
                    .offset(x: -12, y: -6),
                alignment: .center
            )
            .frame(width: 60, height: 40)
    }

    // MARK: - Mode change handler

    private func handleModeChange(_ newMode: BackupMode) {
        switch newMode {
        case .backupExport:
            // Source card scanned successfully — advance to step 2
            withAnimation {
                currentStep = .backup
                totalSecrets = cardState.secretsForBackup.count
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .backupImport:
            // Backup card paired — ready for import, stay on step 2
            break
        default:
            break
        }
    }
}

// MARK: - NFC Ripple Animation (reusable)

private struct NFCRipple: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.sgBorderHover, lineWidth: 1)
                    .frame(width: 80, height: 80)
                    .scaleEffect(animate ? 2.4 : 1.0)
                    .opacity(animate ? 0.0 : Double(0.55 - Double(i) * 0.14))
                    .animation(
                        .easeOut(duration: 2.2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.72),
                        value: animate
                    )
            }
        }
        .frame(width: 200, height: 200)
        .onAppear { animate = true }
    }
}

// MARK: - Notifications for backup progress

extension Notification.Name {
    static let backupError = Notification.Name("backupError")
    static let backupComplete = Notification.Name("backupComplete")
}
