// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  AddConnectionView.swift
//  Signstr — Scan or paste a nostrconnect:// / bunker:// URI, review, approve

import SwiftUI
import AVFoundation

struct AddConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var nip46Service: NIP46Service

    enum Step {
        case scan
        case review(NIP46ConnectionInfo)
        case connecting
        case error(String)
    }

    @State private var step: Step = .scan
    @State private var pasteText = ""
    @State private var showPasteField = false

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            switch step {
            case .scan:
                scanContent
            case .review(let info):
                reviewContent(info)
            case .connecting:
                connectingContent
            case .error(let message):
                errorContent(message)
            }
        }
    }

    // MARK: - Scan step

    private var scanContent: some View {
        ZStack {
            QRCameraPreview(onCodeFound: { code in
                handleScannedCode(code)
            })
            .ignoresSafeArea()

            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.sgTextBright)
                            .frame(width: 36, height: 36)
                            .background(Color.sgBgRaised.opacity(0.8))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("ADD CONNECTION")
                        .font(.outfit(.regular, size: 10))
                        .tracking(4)
                        .foregroundColor(.sgTextBright)

                    Spacer()

                    // Balance the close button
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Scan frame (centred in the space above controls)
                VStack(spacing: 24) {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.sgBorderHover, lineWidth: 2)
                        .frame(width: 240, height: 240)

                    Text("Scan a Nostr Connect QR code")
                        .font(.outfit(.light, size: 14))
                        .foregroundColor(.sgTextMuted)
                }

                Spacer()

                // Paste toggle
                if showPasteField {
                    pasteFieldContent
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPasteField = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 12))
                            Text("PASTE URI")
                                .font(.outfit(.regular, size: 10))
                                .tracking(3)
                        }
                        .foregroundColor(.sgTextBright)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.sgBgRaised.opacity(0.9))
                        .cornerRadius(Dimensions.buttonCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                                .stroke(Color.sgBorderHover, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 40)
                }

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Paste field

    private var pasteFieldContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("nostrconnect:// or bunker://", text: $pasteText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.sgTextBody)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Button(action: {
                    if let clip = UIPasteboard.general.string {
                        pasteText = clip
                    }
                }) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.sgTextMuted)
                }
            }
            .padding(12)
            .background(Color.sgBgSurface)
            .cornerRadius(Dimensions.inputCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Dimensions.inputCornerRadius)
                    .stroke(Color.sgBorder, lineWidth: 1)
            )

            Button(action: {
                handleScannedCode(pasteText)
            }) {
                Text("CONNECT")
                    .font(.outfit(.regular, size: 10))
                    .tracking(3)
                    .foregroundColor(.sgTextBright)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.sgBorder)
                    .cornerRadius(Dimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                            .stroke(Color.sgBorderHover, lineWidth: 1)
                    )
            }
            .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1.0)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Review step

    private func reviewContent(_ info: NIP46ConnectionInfo) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            // App icon
            Circle()
                .fill(Color.sgBgSurface)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "app.connected.to.app.below.fill")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.sgTextMuted)
                )

            Spacer().frame(height: 20)

            Text("CONNECTION REQUEST")
                .font(.outfit(.regular, size: 10))
                .tracking(5)
                .foregroundColor(.sgTextGhost)

            Spacer().frame(height: 24)

            // App name
            VStack(spacing: 6) {
                Text(info.name ?? "Unknown App")
                    .font(.outfit(.regular, size: 20))
                    .foregroundColor(.sgTextBright)

                Text("wants to connect to your signer")
                    .font(.outfit(.light, size: 13))
                    .foregroundColor(.sgTextFaint)
            }

            Spacer().frame(height: 32)

            // Details card
            VStack(alignment: .leading, spacing: 16) {
                detailRow(label: "APP", value: info.name ?? "Unknown")
                detailRow(label: "RELAY", value: formatRelay(info.relays.first ?? ""))
                if let perms = info.permissions, !perms.isEmpty {
                    detailRow(label: "PERMISSIONS", value: formatPermissions(perms))
                }
                detailRow(label: "FLOW", value: info.flow == .clientInitiated ? "Client-initiated" : "Signer-initiated")
            }
            .padding(Dimensions.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.sgBgRaised)
            .cornerRadius(Dimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                    .stroke(Color.sgBorder, lineWidth: 1)
            )

            Spacer()

            // Approve / Reject buttons
            VStack(spacing: 12) {
                SKButton(text: "Approve", style: .confirm) {
                    approveConnection(info)
                }

                SKButton(text: "Reject", style: .danger) {
                    dismiss()
                }
            }

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 24)
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.outfit(.regular, size: 9))
                .tracking(3)
                .foregroundColor(.sgTextGhost)

            Text(value)
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextBody)
                .lineLimit(2)
        }
    }

    private func formatRelay(_ relay: String) -> String {
        relay
            .replacingOccurrences(of: "wss://", with: "")
            .replacingOccurrences(of: "ws://", with: "")
    }

    private func formatPermissions(_ perms: String) -> String {
        perms.replacingOccurrences(of: ",", with: ", ")
    }

    // MARK: - Connecting step

    private var connectingContent: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .sgTextMuted))
                .scaleEffect(1.2)

            Text("Establishing connection...")
                .font(.outfit(.light, size: 14))
                .foregroundColor(.sgTextMuted)
        }
    }

    // MARK: - Error step

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(.sgDanger)

            Text("CONNECTION FAILED")
                .font(.outfit(.regular, size: 11))
                .tracking(5)
                .foregroundColor(.sgTextMuted)

            Text(message)
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer().frame(height: 16)

            SKButton(text: "Try Again", style: .confirm) {
                step = .scan
                pasteText = ""
                showPasteField = false
            }
            .padding(.horizontal, 24)

            SKButton(text: "Cancel", style: .danger) {
                dismiss()
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Logic

    private func handleScannedCode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let info = try NIP46ConnectionParser.parse(trimmed)
            withAnimation(.easeInOut(duration: 0.2)) {
                step = .review(info)
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                step = .error(error.localizedDescription)
            }
        }
    }

    private func approveConnection(_ info: NIP46ConnectionInfo) {
        step = .connecting

        Task {
            do {
                let im = IdentityManager.shared
                let activeIdentity = im.activeIdentity

                // Load private key: prefer IdentityManager, fall back to SecureEnclaveKeyStore
                let privateKey: Data
                if let identity = activeIdentity, let nsec = im.loadNsec(for: identity.id) {
                    privateKey = nsec
                } else {
                    privateKey = try SecureEnclaveKeyStore.load()
                }

                _ = try nip46Service.addConnection(
                    from: info,
                    signerPrivateKey: privateKey,
                    identityId: activeIdentity?.id
                )

                // Zero the key
                let mutable = NSMutableData(data: privateKey)
                memset(mutable.mutableBytes, 0, mutable.length)

                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dismiss()
            } catch {
                step = .error("Failed to establish connection: \(error.localizedDescription)")
            }
        }
    }
}
