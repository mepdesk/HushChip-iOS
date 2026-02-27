// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  ImportNsecView.swift
//  Signstr — Import an existing nsec1... private key

import SwiftUI

struct ImportNsecView: View {
    @EnvironmentObject var cardState: CardState

    @State private var nsecInput: String = ""
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var importedNpub: String?
    @State private var showQRScanner = false
    @State private var showBackup = false

    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Back button ─────────────────────────────────────
                HStack {
                    Button(action: {
                        cardState.homeNavigationPath.removeLast()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .medium))
                            Text("BACK")
                                .font(.outfit(.regular, size: 10))
                                .tracking(3)
                        }
                        .foregroundColor(.sgTextMuted)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                if let npub = importedNpub {
                    successContent(npub: npub)
                } else {
                    importContent
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showQRScanner) {
            QRScannerView { scannedValue in
                showQRScanner = false
                nsecInput = scannedValue
            }
        }
        .fullScreenCover(isPresented: $showBackup) {
            NavigationStack {
                BackUpKeyView(isPostSetup: true) {
                    showBackup = false
                    completeSetup()
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Import content

    private var importContent: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(.sgBorderHover)

            Spacer().frame(height: 32)

            Text("Import your nsec")
                .font(.outfit(.light, size: 22))
                .tracking(0.3)
                .foregroundColor(.sgTextBright)

            Spacer().frame(height: 12)

            Text("Paste your nsec1... private key or scan a QR code.")
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 40)

            Spacer().frame(height: 36)

            // ── nsec input field ─────────────────────────────────
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    TextField("nsec1...", text: $nsecInput)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.sgTextBright)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($inputFocused)

                    if !nsecInput.isEmpty {
                        Button(action: { nsecInput = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.sgTextGhost)
                        }
                    }
                }
                .padding(14)
                .background(Color.sgBgSurface)
                .cornerRadius(Dimensions.inputCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Dimensions.inputCornerRadius)
                        .stroke(Color.sgBorder, lineWidth: 1)
                )

                // Action buttons row
                HStack(spacing: 12) {
                    // Paste button
                    Button(action: pasteFromClipboard) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 12))
                            Text("PASTE")
                                .font(.outfit(.regular, size: 10))
                                .tracking(2)
                        }
                        .foregroundColor(.sgTextMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.sgBgRaised)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.sgBorder, lineWidth: 1)
                        )
                    }

                    // QR scan button
                    Button(action: { showQRScanner = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 12))
                            Text("SCAN QR")
                                .font(.outfit(.regular, size: 10))
                                .tracking(2)
                        }
                        .foregroundColor(.sgTextMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.sgBgRaised)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.sgBorder, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 24)

            // ── Error message ────────────────────────────────────
            if let error = errorMessage {
                Text(error)
                    .font(.outfit(.light, size: 12))
                    .foregroundColor(.sgDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
            }

            Spacer().frame(height: 32)

            // ── Import button ────────────────────────────────────
            if isImporting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .sgTextMuted))
                    .padding(.bottom, 20)
            } else {
                Button(action: importKey) {
                    Text("IMPORT KEY")
                        .font(.outfit(.regular, size: 11))
                        .tracking(4)
                        .foregroundColor(nsecInput.isEmpty ? .sgTextGhost : .sgTextBright)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(nsecInput.isEmpty ? Color.sgBorder.opacity(0.5) : Color.sgBorder)
                        .cornerRadius(Dimensions.buttonCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                                .stroke(Color.sgBorderHover, lineWidth: 1)
                        )
                        .opacity(nsecInput.isEmpty ? 0.5 : 1.0)
                }
                .disabled(nsecInput.isEmpty)
                .padding(.horizontal, 24)
            }

            Spacer()

            // ── Security note ────────────────────────────────────
            Text("Your key is encrypted with the Secure Enclave immediately after import. The raw nsec is never stored in plaintext.")
                .font(.outfit(.light, size: 11))
                .foregroundColor(.sgTextGhost)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .padding(.bottom, Dimensions.defaultBottomMargin)
        }
    }

    // MARK: - Success content

    private func successContent(npub: String) -> some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(.sgBorderHover)

            Spacer().frame(height: 24)

            Text("Key imported")
                .font(.outfit(.light, size: 22))
                .tracking(0.3)
                .foregroundColor(.sgTextBright)

            Spacer().frame(height: 8)

            Text("Your nsec has been encrypted and stored securely.")
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer().frame(height: 28)

            // npub display card
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR NPUB")
                    .font(.outfit(.regular, size: 9))
                    .tracking(3)
                    .foregroundColor(.sgTextGhost)

                Text(npub)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.sgTextBody)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: {
                    ClipboardManager.shared.copy(npub)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                        Text("COPY")
                            .font(.outfit(.regular, size: 9))
                            .tracking(2)
                    }
                    .foregroundColor(.sgTextMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.sgBgSurface)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )
                }
                .padding(.top, 4)
            }
            .padding(Dimensions.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.sgBgRaised)
            .cornerRadius(Dimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                    .stroke(Color.sgBorder, lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer().frame(height: 40)

            Button(action: { showBackup = true }) {
                Text("BACK UP YOUR KEY")
                    .font(.outfit(.regular, size: 11))
                    .tracking(4)
                    .foregroundColor(.sgTextBright)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.sgBorder)
                    .cornerRadius(Dimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                            .stroke(Color.sgBorderHover, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        if let content = UIPasteboard.general.string {
            nsecInput = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func importKey() {
        inputFocused = false
        errorMessage = nil
        isImporting = true

        let trimmed = nsecInput.trimmingCharacters(in: .whitespacesAndNewlines)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let npub = try KeyManager.importNsec(trimmed)
                DispatchQueue.main.async {
                    isImporting = false
                    importedNpub = npub
                    // Clear the input and clipboard for security
                    nsecInput = ""
                    UIPasteboard.general.string = ""
                }
            } catch KeyManager.KeyManagerError.keyAlreadyExists {
                DispatchQueue.main.async {
                    isImporting = false
                    errorMessage = "A key already exists. Delete it in Settings first."
                }
            } catch KeyManager.KeyManagerError.invalidNsecString {
                DispatchQueue.main.async {
                    isImporting = false
                    errorMessage = "Invalid nsec string. Make sure it starts with nsec1..."
                }
            } catch {
                DispatchQueue.main.async {
                    isImporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func completeSetup() {
        UserDefaults.standard.set(true, forKey: Constants.Keys.keySetupComplete)
        cardState.homeNavigationPath = .init()
    }
}
