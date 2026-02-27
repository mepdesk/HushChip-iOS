// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  BackUpKeyView.swift
//  Signstr — Back up your key: reveal nsec (Face ID), copy, confirm

import SwiftUI
import CoreImage.CIFilterBuiltins

struct BackUpKeyView: View {
    /// When true, this is shown as part of the post-generation flow (requires confirmation).
    /// When false, it's accessed from Settings (can dismiss freely).
    let isPostSetup: Bool
    var onComplete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var nsec: String?
    @State private var isRevealed = false
    @State private var isCopied = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSkipWarning = false

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // Key icon
                    Image(systemName: "key.viewfinder")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(.sgDanger)

                    Spacer().frame(height: 16)

                    Text("BACK UP YOUR KEY")
                        .font(.outfit(.regular, size: 10))
                        .tracking(5)
                        .foregroundColor(.sgTextMuted)

                    Spacer().frame(height: 24)

                    // Warning box
                    warningBox

                    Spacer().frame(height: 32)

                    // nsec reveal section
                    if let nsec = nsec {
                        nsecDisplayCard(nsec)
                    } else if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .sgTextMuted))
                    } else {
                        revealButton
                    }

                    if let error = errorMessage {
                        Spacer().frame(height: 16)
                        Text(error)
                            .font(.outfit(.light, size: 12))
                            .foregroundColor(.sgDanger)
                    }

                    Spacer().frame(height: 40)

                    // Action buttons
                    actionButtons

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isPostSetup)
        .navigationBarItems(leading: isPostSetup ? nil : Button(action: {
            dismiss()
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
                Text("KEY BACKUP")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
            }
        }
        .alert("Skip Backup?", isPresented: $showSkipWarning) {
            Button("Go Back", role: .cancel) {}
            Button("I understand the risk", role: .destructive) {
                onComplete?()
            }
        } message: {
            Text("You can export your nsec from Settings at any time. But if you lose this device first, your identity is gone.")
        }
    }

    // MARK: - Warning box

    private var warningBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.sgDanger)
                Text("WARNING")
                    .font(.outfit(.regular, size: 9))
                    .tracking(3)
                    .foregroundColor(.sgDanger)
            }

            Text("Your Nostr identity depends on this key. If you lose this device and have no backup, your identity is gone forever. There is no recovery. No password reset. No support ticket.")
                .font(.outfit(.light, size: 12))
                .foregroundColor(.sgTextBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Dimensions.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sgDangerBg)
        .cornerRadius(Dimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                .stroke(Color.sgDangerBorder, lineWidth: 1)
        )
    }

    // MARK: - Reveal button

    private var revealButton: some View {
        SKButton(text: "Reveal nsec (Face ID)", style: .inform) {
            revealNsec()
        }
    }

    // MARK: - nsec display

    private func nsecDisplayCard(_ nsecString: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR NSEC")
                .font(.outfit(.regular, size: 9))
                .tracking(3)
                .foregroundColor(.sgTextGhost)

            // Masked / revealed nsec
            Button(action: { isRevealed.toggle() }) {
                Text(isRevealed ? nsecString : maskNsec(nsecString))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.sgTextBody)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                // Reveal toggle
                Button(action: { isRevealed.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                        Text(isRevealed ? "HIDE" : "REVEAL")
                            .font(.outfit(.regular, size: 9))
                            .tracking(2)
                    }
                    .foregroundColor(.sgTextMuted)
                }

                Spacer()

                // Copy button
                Button(action: {
                    ClipboardManager.shared.copy(nsecString)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(isCopied ? "COPIED" : "COPY")
                            .font(.outfit(.regular, size: 9))
                            .tracking(2)
                    }
                    .foregroundColor(isCopied ? Color(hex: "#2d5a3d") : .sgTextMuted)
                }
            }
        }
        .padding(Dimensions.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sgBgRaised)
        .cornerRadius(Dimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                .stroke(Color.sgBorder, lineWidth: 1)
        )
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if nsec != nil && isPostSetup {
                SKButton(text: "I have saved it somewhere safe", style: .confirm) {
                    onComplete?()
                }
            }

            if isPostSetup {
                Button(action: {
                    showSkipWarning = true
                }) {
                    Text("I'LL DO THIS LATER")
                        .font(.outfit(.regular, size: 11))
                        .tracking(4)
                        .foregroundColor(.sgTextFaint)
                        .frame(height: 46)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Helpers

    private func revealNsec() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let nsecData = try SecureEnclaveKeyStore.load()
                let nsecString = try NostrKeyUtils.nsecEncode(nsecData)
                // Zero the raw data
                let mutable = NSMutableData(data: nsecData)
                memset(mutable.mutableBytes, 0, mutable.length)

                await MainActor.run {
                    self.nsec = nsecString
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to access key. Try again."
                    self.isLoading = false
                }
            }
        }
    }

    private func maskNsec(_ nsec: String) -> String {
        guard nsec.count > 12 else { return nsec }
        let prefix = nsec.prefix(8)
        let dots = String(repeating: "\u{2022}", count: 32)
        let suffix = nsec.suffix(4)
        return "\(prefix)\(dots)\(suffix)"
    }
}
