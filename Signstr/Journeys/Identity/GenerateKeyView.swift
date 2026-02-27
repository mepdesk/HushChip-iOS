// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  GenerateKeyView.swift
//  Signstr — Generate a new Nostr keypair

import SwiftUI

struct GenerateKeyView: View {
    @EnvironmentObject var cardState: CardState

    enum GenerateState {
        case ready
        case generating
        case success(npub: String)
        case error(message: String)
    }

    @State private var state: GenerateState = .ready

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

                Spacer()

                switch state {
                case .ready:
                    readyContent
                case .generating:
                    generatingContent
                case .success(let npub):
                    successContent(npub: npub)
                case .error(let message):
                    errorContent(message: message)
                }

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Ready state

    private var readyContent: some View {
        VStack(spacing: 0) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(.sgBorderHover)

            Spacer().frame(height: 32)

            Text("Create new identity")
                .font(.outfit(.light, size: 22))
                .tracking(0.3)
                .foregroundColor(.sgTextBright)

            Spacer().frame(height: 12)

            Text("A new Nostr keypair will be generated and stored securely in the Secure Enclave.")
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 40)

            Spacer().frame(height: 48)

            Button(action: generateKey) {
                Text("GENERATE KEYPAIR")
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
        }
    }

    // MARK: - Generating state

    private var generatingContent: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .sgTextMuted))
                .scaleEffect(1.2)

            Text("Generating keypair...")
                .font(.outfit(.light, size: 14))
                .foregroundColor(.sgTextMuted)
        }
    }

    // MARK: - Success state

    private func successContent(npub: String) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(.sgBorderHover)

            Spacer().frame(height: 24)

            Text("Identity created")
                .font(.outfit(.light, size: 22))
                .tracking(0.3)
                .foregroundColor(.sgTextBright)

            Spacer().frame(height: 8)

            Text("Your public key (npub) is how others find you on Nostr.")
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

                // Copy button
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

            Button(action: completeSetup) {
                Text("CONTINUE")
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
        }
    }

    // MARK: - Error state

    private func errorContent(message: String) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(.sgDanger)

            Spacer().frame(height: 24)

            Text("Something went wrong")
                .font(.outfit(.light, size: 22))
                .tracking(0.3)
                .foregroundColor(.sgTextBright)

            Spacer().frame(height: 12)

            Text(message)
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgDanger)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer().frame(height: 32)

            Button(action: { state = .ready }) {
                Text("TRY AGAIN")
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
        }
    }

    // MARK: - Actions

    private func generateKey() {
        state = .generating

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let npub = try KeyManager.generateKey()
                DispatchQueue.main.async {
                    state = .success(npub: npub)
                }
            } catch KeyManager.KeyManagerError.keyAlreadyExists {
                DispatchQueue.main.async {
                    // Key already exists — try to derive npub and proceed
                    do {
                        let npub = try KeyManager.deriveNpub()
                        state = .success(npub: npub)
                    } catch {
                        state = .error(message: "A key already exists. Delete it in Settings to generate a new one.")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    state = .error(message: error.localizedDescription)
                }
            }
        }
    }

    private func completeSetup() {
        UserDefaults.standard.set(true, forKey: Constants.Keys.keySetupComplete)
        // Clear navigation and go to Sign tab
        cardState.homeNavigationPath = .init()
    }
}
