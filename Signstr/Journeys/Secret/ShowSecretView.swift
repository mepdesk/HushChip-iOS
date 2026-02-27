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
//  ShowSecretView.swift
//  Signstr
//
//  Created by Lionel Delvaux on 04/05/2024.
//

import Foundation
import CoreGraphics
import QRCode
import SwiftUI
import UIKit

struct ShowSecretView: View {
    // MARK: - Properties
    @EnvironmentObject var cardState: CardState
    @Binding var homeNavigationPath: NavigationPath
    var secret: SeedkeeperSecretHeaderDto
    @State private var shouldShowSeedQR: Bool = false
    @State private var isRevealed: Bool = false
    @State private var autoHideTimer: Timer?
    @State private var secondsRemaining: Int = 60
    @State private var showDeleteConfirm: Bool = false
    @State private var wordAnimationFlags: [Bool] = []

    // MARK: - Computed

    private var fingerprintHex: String {
        secret.fingerprintBytes.map { String(format: "%02x", $0) }.joined()
    }

    private var exportRightsText: String {
        switch secret.exportRights {
        case .exportPlaintextAllowed:
            return "Plaintext export allowed"
        case .exportEncryptedOnly:
            return "Encrypted only"
        case .exportForbidden:
            return "Export forbidden"
        case .exportAuthenticatedOnly:
            return "Authenticated export only"
        @unknown default:
            return "Unknown"
        }
    }

    private var secretTypeName: String {
        switch secret.type {
        case .bip39Mnemonic: return "BIP39 Mnemonic"
        case .password: return "Password"
        case .masterPassword: return "Master Password"
        case .walletDescriptor: return "Wallet Descriptor"
        case .data: return "Free Text"
        case .secret2FA: return "2FA Secret"
        case .masterseed: return "Master Seed"
        case .electrumMnemonic: return "Electrum Mnemonic"
        case .privkey: return "Private Key"
        case .pubkey, .pubkeyAuthenticated: return "Public Key"
        case .key: return "Key"
        case .certificate: return "Certificate"
        case .shamirSecretShare: return "Shamir Share"
        default: return "Secret"
        }
    }

    private var hasRevealedContent: Bool {
        cardState.currentMnemonicCardData != nil || cardState.currentPasswordCardData != nil
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Spacer().frame(height: 8)

                    // Metadata card
                    metadataCard

                    // Action buttons
                    actionButtonsRow

                    // Revealed content
                    if isRevealed && hasRevealedContent {
                        revealedContentSection
                    }

                    // QR Code display
                    if shouldShowSeedQR {
                        qrCodeSection
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, Dimensions.lateralPadding)
            }
        }
        .onDisappear {
            autoHideTimer?.invalidate()
            cardState.cleanShowSecret()
        }
        .onReceive(cardState.$currentMnemonicCardData) { data in
            if data != nil {
                onSecretRevealed()
            }
        }
        .onReceive(cardState.$currentPasswordCardData) { data in
            if data != nil {
                onSecretRevealed()
            }
        }
        .alert("Delete Secret", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
                cardState.currentSecretHeader = secret
                cardState.requestDeleteSecret()
            }
        } message: {
            Text("This will permanently delete \"\(secret.label)\" from the card. This cannot be undone.")
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
                Text("SECRET")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
            }
        }
    }

    // MARK: - Metadata Card

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Label
            Text(secret.label)
                .font(.custom("Outfit-Regular", size: 14))
                .foregroundColor(.sgTextBright)

            // Type
            Text(secretTypeName)
                .font(.custom("Outfit-Light", size: 11))
                .foregroundColor(.sgTextFaint)

            // Fingerprint
            Text(fingerprintHex)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.sgTextGhost)

            // Export rights
            Text(exportRightsText)
                .font(.custom("Outfit-Light", size: 11))
                .foregroundColor(.sgTextFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.sgBgRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.sgBorder, lineWidth: 1)
        )
        .cornerRadius(12)
    }

    // MARK: - Action Buttons

    private var actionButtonsRow: some View {
        HStack(spacing: 8) {
            // Reveal
            Button(action: {
                cardState.requestGetSecret(with: secret)
            }) {
                Text("REVEAL")
                    .font(.custom("Outfit-Regular", size: 10))
                    .tracking(2)
                    .foregroundColor(.sgTextBright)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.sgBorder)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.sgBorderHover, lineWidth: 1)
                    )
                    .cornerRadius(8)
            }

            // QR Code
            Button(action: {
                if !hasRevealedContent {
                    cardState.requestGetSecret(with: secret)
                }
                shouldShowSeedQR.toggle()
            }) {
                Text("QR")
                    .font(.custom("Outfit-Regular", size: 10))
                    .tracking(2)
                    .foregroundColor(.sgTextBody)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.sgBorderHover, lineWidth: 1)
                    )
                    .cornerRadius(8)
            }

            // Copy
            Button(action: {
                copySecretToClipboard()
            }) {
                Text("COPY")
                    .font(.custom("Outfit-Regular", size: 10))
                    .tracking(2)
                    .foregroundColor(.sgTextBody)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.sgBorderHover, lineWidth: 1)
                    )
                    .cornerRadius(8)
            }

            // Delete
            if let version = cardState.cardStatus?.protocolVersion, version >= 0x0002 {
                Button(action: {
                    showDeleteConfirm = true
                }) {
                    Text("DELETE")
                        .font(.custom("Outfit-Regular", size: 10))
                        .tracking(2)
                        .foregroundColor(.sgDanger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.sgDangerBorder, lineWidth: 1)
                        )
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Revealed Content

    private var revealedContentSection: some View {
        VStack(spacing: 12) {
            if secret.type == .bip39Mnemonic, let mnemonicData = cardState.currentMnemonicCardData {
                mnemonicWordGrid(mnemonic: mnemonicData.mnemonic)
            } else if let password = cardState.currentPasswordCardData?.password {
                monospaceField(text: password)
            } else if let mnemonicData = cardState.currentMnemonicCardData {
                // Free text / wallet descriptor / other types that come through as mnemonic
                monospaceField(text: mnemonicData.mnemonic, scrollable: true)
            }

            // Auto-hide countdown
            Text("Auto-hiding in \(secondsRemaining)s")
                .font(.custom("Outfit-Light", size: 10))
                .foregroundColor(.sgTextGhost)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Mnemonic Word Grid

    private func mnemonicWordGrid(mnemonic: String) -> some View {
        let words = mnemonic.split(separator: " ").map(String.init)
        let columns = words.count <= 12 ? 3 : 4

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                HStack(spacing: 4) {
                    Text("\(index + 1)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.sgTextGhost)
                        .frame(width: 18, alignment: .trailing)
                    Text(word)
                        .font(.custom("Outfit-Regular", size: 13))
                        .foregroundColor(.sgTextBright)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(Color.sgBgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.sgBorder, lineWidth: 1)
                )
                .cornerRadius(8)
                .opacity(wordAnimationFlags.indices.contains(index) && wordAnimationFlags[index] ? 1 : 0)
            }
        }
    }

    // MARK: - Monospace Field

    private func monospaceField(text: String, scrollable: Bool = false) -> some View {
        Group {
            if scrollable {
                ScrollView {
                    Text(text)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.sgTextBright)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxHeight: 200)
                .background(Color.sgBgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.sgBorder, lineWidth: 1)
                )
                .cornerRadius(8)
            } else {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.sgTextBright)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.sgBgSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - QR Code

    private var qrCodeSection: some View {
        Group {
            if let content = qrContent, let cgImage = generateQR(from: content) {
                VStack(spacing: 8) {
                    Image(uiImage: UIImage(cgImage: cgImage))
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(16)
                        .background(Color.sgBgSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.sgBorder, lineWidth: 1)
                        )
                        .cornerRadius(12)
                }
            }
        }
    }

    private var qrContent: String? {
        if let mnemonicData = cardState.currentMnemonicCardData {
            return mnemonicData.getSeedQRContent()
        } else if let password = cardState.currentPasswordCardData?.password {
            return password
        }
        return nil
    }

    private func generateQR(from text: String) -> CGImage? {
        do {
            let doc = try QRCode.Document(utf8String: text, errorCorrection: .high)
            doc.design.foregroundColor(Color.sgBorder.cgColor!)
            doc.design.backgroundColor(Color.sgBgSurface.cgColor!)
            return try doc.cgImage(CGSize(width: 200, height: 200))
        } catch {
            return nil
        }
    }

    // MARK: - Actions

    private func onSecretRevealed() {
        // Haptic: secret revealed
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        isRevealed = true
        shouldShowSeedQR = false
        secondsRemaining = 60

        // Animate mnemonic words
        if secret.type == .bip39Mnemonic, let mnemonic = cardState.currentMnemonicCardData?.mnemonic {
            let wordCount = mnemonic.split(separator: " ").count
            wordAnimationFlags = Array(repeating: false, count: wordCount)
            for i in 0..<wordCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                    if wordAnimationFlags.indices.contains(i) {
                        withAnimation(.easeIn(duration: 0.15)) {
                            wordAnimationFlags[i] = true
                        }
                    }
                }
            }
        }

        // Auto-hide timer
        autoHideTimer?.invalidate()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                secondsRemaining -= 1
                if secondsRemaining <= 0 {
                    timer.invalidate()
                    isRevealed = false
                    wordAnimationFlags = []
                }
            }
        }
    }

    private func copySecretToClipboard() {
        var textToCopy: String?
        if let password = cardState.currentPasswordCardData?.password {
            textToCopy = password
        } else if let mnemonic = cardState.currentMnemonicCardData?.mnemonic {
            textToCopy = mnemonic
        }

        guard let text = textToCopy else {
            // No content revealed yet — trigger reveal first
            cardState.requestGetSecret(with: secret)
            return
        }

        ClipboardManager.shared.copy(text)

        // Haptic: secret copied
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
