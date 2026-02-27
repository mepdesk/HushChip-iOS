// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  EmergencyExportView.swift
//  Signstr — Emergency nsec export with QR code display

import SwiftUI
import CoreImage.CIFilterBuiltins

struct EmergencyExportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var nsec: String?
    @State private var isRevealed = false
    @State private var isCopied = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // Warning icon
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(.sgDanger)

                    Spacer().frame(height: 16)

                    Text("EMERGENCY EXPORT")
                        .font(.outfit(.regular, size: 10))
                        .tracking(5)
                        .foregroundColor(.sgDanger)

                    Spacer().frame(height: 24)

                    // Warning box
                    warningBox

                    Spacer().frame(height: 32)

                    if let nsec = nsec {
                        // nsec display
                        nsecDisplayCard(nsec)

                        Spacer().frame(height: 24)

                        // QR code
                        qrCodeCard(nsec)
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
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
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
                Text("EXPORT KEY")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
            }
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

            Text("This will display your raw private key. Anyone who sees this screen controls your Nostr identity. Only do this if you need to recover your key or move it to another device.")
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
        SKButton(text: "Reveal nsec (Face ID)", style: .danger) {
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

            Button(action: { isRevealed.toggle() }) {
                Text(isRevealed ? nsecString : maskNsec(nsecString))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.sgTextBody)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
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

    // MARK: - QR code

    private func qrCodeCard(_ nsecString: String) -> some View {
        VStack(spacing: 12) {
            Text("SCAN TO IMPORT")
                .font(.outfit(.regular, size: 9))
                .tracking(3)
                .foregroundColor(.sgTextGhost)

            if let qrImage = generateQR(for: nsecString) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(Dimensions.cardCornerRadius)
            }

            Text("Point another device's camera at this QR code to import your key.")
                .font(.outfit(.light, size: 11))
                .foregroundColor(.sgTextFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(Dimensions.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.sgBgRaised)
        .cornerRadius(Dimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                .stroke(Color.sgBorder, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func revealNsec() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let nsecData = try SecureEnclaveKeyStore.load()
                let nsecString = try NostrKeyUtils.nsecEncode(nsecData)
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

    private func generateQR(for string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }

        let scale = 10.0
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func maskNsec(_ nsec: String) -> String {
        guard nsec.count > 12 else { return nsec }
        let prefix = nsec.prefix(8)
        let dots = String(repeating: "\u{2022}", count: 32)
        let suffix = nsec.suffix(4)
        return "\(prefix)\(dots)\(suffix)"
    }
}
