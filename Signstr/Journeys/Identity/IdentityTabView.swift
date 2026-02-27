// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  IdentityTabView.swift
//  Signstr — Identity tab: npub display, QR code, copy, Go Air-Gapped upsell

import SwiftUI
import CoreImage.CIFilterBuiltins

struct IdentityTabView: View {
    @State private var npub: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCopiedFeedback = false

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            if isLoading {
                loadingContent
            } else if let npub = npub {
                identityContent(npub: npub)
            } else {
                noKeyContent
            }
        }
        .onAppear(perform: loadNpub)
    }

    // MARK: - Loading

    private var loadingContent: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .sgTextMuted))
                .scaleEffect(1.2)

            Text("Loading identity...")
                .font(.outfit(.light, size: 14))
                .foregroundColor(.sgTextMuted)
        }
    }

    // MARK: - No key stored

    private var noKeyContent: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "key.slash")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(.sgTextGhost)

            Text("NO IDENTITY")
                .font(.outfit(.regular, size: 11))
                .tracking(5)
                .foregroundColor(.sgTextMuted)

            Text("Generate or import a key in Settings to get started.")
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Identity content

    private func identityContent(npub: String) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                // Section label
                Text("YOUR IDENTITY")
                    .font(.outfit(.regular, size: 10))
                    .tracking(5)
                    .foregroundColor(.sgTextGhost)

                Spacer().frame(height: 24)

                // QR code
                qrCodeView(for: npub)

                Spacer().frame(height: 24)

                // npub display card
                npubCard(npub: npub)

                Spacer().frame(height: 16)

                // Copy button
                copyButton(npub: npub)

                Spacer().frame(height: 40)

                // Go Air-Gapped upsell
                airGappedCard

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - QR Code

    private func qrCodeView(for npub: String) -> some View {
        Group {
            if let qrImage = generateQRCode(from: npub) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(Dimensions.cardCornerRadius)
            } else {
                RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                    .fill(Color.sgBgRaised)
                    .frame(width: 212, height: 212)
                    .overlay(
                        Text("QR unavailable")
                            .font(.outfit(.light, size: 12))
                            .foregroundColor(.sgTextFaint)
                    )
            }
        }
    }

    // MARK: - npub card

    private func npubCard(npub: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PUBLIC KEY")
                .font(.outfit(.regular, size: 9))
                .tracking(3)
                .foregroundColor(.sgTextGhost)

            // Truncated display
            Text(truncateNpub(npub))
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.sgTextBody)

            // Full npub (smaller)
            Text(npub)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.sgTextFaint)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Copy button

    private func copyButton(npub: String) -> some View {
        Button(action: {
            ClipboardManager.shared.copy(npub)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            showCopiedFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showCopiedFeedback = false
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                Text(showCopiedFeedback ? "COPIED" : "COPY NPUB")
                    .font(.outfit(.regular, size: 10))
                    .tracking(3)
            }
            .foregroundColor(showCopiedFeedback ? .sgBorderHover : .sgTextBright)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.sgBorder)
            .cornerRadius(Dimensions.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                    .stroke(Color.sgBorderHover, lineWidth: 1)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: showCopiedFeedback)
    }

    // MARK: - Go Air-Gapped upsell card

    private var airGappedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.sgTextMuted)
                Text("GO AIR-GAPPED")
                    .font(.outfit(.regular, size: 10))
                    .tracking(3)
                    .foregroundColor(.sgTextMuted)
            }

            Text("Your key lives on this device. Want it off?")
                .font(.outfit(.light, size: 15))
                .foregroundColor(.sgTextBright)

            Text("NostrKey card stores your nsec in a secure element. Your key never touches your phone again. Tap to sign. Nothing to hack.")
                .font(.outfit(.light, size: 12))
                .foregroundColor(.sgTextFaint)
                .lineSpacing(4)

            Spacer().frame(height: 4)

            HStack {
                Text("GBP 14.99")
                    .font(.outfit(.medium, size: 12))
                    .foregroundColor(.sgTextBody)

                Spacer()

                Link(destination: URL(string: "https://signstr.com/card")!) {
                    HStack(spacing: 6) {
                        Text("LEARN MORE")
                            .font(.outfit(.regular, size: 9))
                            .tracking(2)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .medium))
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

    // MARK: - Helpers

    private func loadNpub() {
        guard KeyManager.keyExists() else {
            isLoading = false
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let derivedNpub = try KeyManager.deriveNpub()
                DispatchQueue.main.async {
                    npub = derivedNpub
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func truncateNpub(_ npub: String) -> String {
        guard npub.count > 20 else { return npub }
        let prefix = npub.prefix(12)
        let suffix = npub.suffix(8)
        return "\(prefix)...\(suffix)"
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = 200.0 / outputImage.extent.size.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
