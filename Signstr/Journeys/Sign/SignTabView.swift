// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  SignTabView.swift
//  Signstr — Compose, sign, and broadcast kind-1 Nostr notes

import SwiftUI

struct SignTabView: View {
    @State private var noteText = ""
    @State private var signState: SignState = .idle
    @State private var relayResults: [NostrRelayPool.PublishResult] = []
    @State private var signedEventId: String?

    private let maxCharacters = 1000

    enum SignState {
        case idle
        case signing
        case broadcasting
        case success
        case error(String)
    }

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            if !KeyManager.keyExists() {
                noKeyContent
            } else {
                signContent
            }
        }
    }

    // MARK: - No key state

    private var noKeyContent: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "key.slash")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(.sgTextGhost)

            Text("NO KEY")
                .font(.outfit(.regular, size: 11))
                .tracking(5)
                .foregroundColor(.sgTextMuted)

            Text("Generate or import a key in Settings to start signing.")
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Main sign content

    private var signContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                Text("COMPOSE NOTE")
                    .font(.outfit(.regular, size: 10))
                    .tracking(5)
                    .foregroundColor(.sgTextGhost)

                Spacer().frame(height: 20)

                // Text input area
                composeCard

                Spacer().frame(height: 12)

                // Character count
                characterCount

                Spacer().frame(height: 24)

                // Sign & Post button
                signButton

                Spacer().frame(height: 24)

                // Status / results area
                statusArea

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Compose card

    private var composeCard: some View {
        VStack(spacing: 0) {
            TextEditor(text: $noteText)
                .font(.outfit(.light, size: 15))
                .foregroundColor(.sgTextBright)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 140, maxHeight: 200)
                .padding(12)
                .disabled(isActionInProgress)
        }
        .background(Color.sgBgSurface)
        .cornerRadius(Dimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                .stroke(Color.sgBorder, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            if noteText.isEmpty {
                Text("What's on your mind?")
                    .font(.outfit(.light, size: 15))
                    .foregroundColor(.sgTextGhost)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Character count

    private var characterCount: some View {
        HStack {
            Spacer()
            Text("\(noteText.count) / \(maxCharacters)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(noteText.count > maxCharacters ? .sgDanger : .sgTextGhost)
        }
    }

    // MARK: - Sign button

    private var signButton: some View {
        Button(action: signAndPost) {
            HStack(spacing: 10) {
                if isActionInProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .sgTextMuted))
                        .scaleEffect(0.8)
                }
                Text(signButtonLabel)
                    .font(.outfit(.regular, size: 11))
                    .tracking(4)
            }
            .foregroundColor(canSign ? .sgTextBright : .sgTextGhost)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(canSign ? Color.sgBorder : Color.sgBgRaised)
            .cornerRadius(Dimensions.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                    .stroke(canSign ? Color.sgBorderHover : Color.sgBorder, lineWidth: 1)
            )
        }
        .disabled(!canSign)
    }

    // MARK: - Status area

    private var statusArea: some View {
        VStack(spacing: 16) {
            switch signState {
            case .idle:
                EmptyView()
            case .signing:
                HStack(spacing: 8) {
                    Image(systemName: "faceid")
                        .font(.system(size: 14))
                        .foregroundColor(.sgTextMuted)
                    Text("Authenticating...")
                        .font(.outfit(.light, size: 13))
                        .foregroundColor(.sgTextMuted)
                }
            case .broadcasting:
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .sgTextMuted))
                        .scaleEffect(0.8)
                    Text("Broadcasting to relays...")
                        .font(.outfit(.light, size: 13))
                        .foregroundColor(.sgTextMuted)
                }
            case .success:
                successView
            case .error(let message):
                errorView(message: message)
            }

            // Relay results
            if !relayResults.isEmpty {
                relayStatusList
            }
        }
    }

    // MARK: - Success view

    private var successView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundColor(.sgBorderHover)

            Text("Event signed and posted")
                .font(.outfit(.light, size: 15))
                .foregroundColor(.sgTextBright)

            if let eventId = signedEventId {
                VStack(alignment: .leading, spacing: 6) {
                    Text("EVENT ID")
                        .font(.outfit(.regular, size: 9))
                        .tracking(3)
                        .foregroundColor(.sgTextGhost)

                    Text(eventId)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.sgTextFaint)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: {
                        ClipboardManager.shared.copy(eventId)
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                            Text("COPY ID")
                                .font(.outfit(.regular, size: 8))
                                .tracking(2)
                        }
                        .foregroundColor(.sgTextMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.sgBgSurface)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.sgBorder, lineWidth: 1)
                        )
                    }
                    .padding(.top, 2)
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

            // New note button
            Button(action: resetForNewNote) {
                Text("NEW NOTE")
                    .font(.outfit(.regular, size: 10))
                    .tracking(3)
                    .foregroundColor(.sgTextMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.sgBgSurface)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Error view

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20, weight: .ultraLight))
                .foregroundColor(.sgDanger)

            Text(message)
                .font(.outfit(.light, size: 12))
                .foregroundColor(.sgDanger)
                .multilineTextAlignment(.center)

            Button(action: { signState = .idle }) {
                Text("DISMISS")
                    .font(.outfit(.regular, size: 9))
                    .tracking(2)
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

    // MARK: - Relay status list

    private var relayStatusList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RELAY STATUS")
                .font(.outfit(.regular, size: 9))
                .tracking(3)
                .foregroundColor(.sgTextGhost)
                .padding(.bottom, 10)

            ForEach(Array(relayResults.enumerated()), id: \.element.relayURL) { _, result in
                HStack(spacing: 10) {
                    Circle()
                        .fill(result.success ? Color(hex: "#2d5a3d") : Color.sgDanger)
                        .frame(width: 6, height: 6)

                    Text(result.relayURL.host ?? result.relayURL.absoluteString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(result.success ? .sgTextBody : .sgTextFaint)

                    Spacer()

                    Text(result.success ? "OK" : "FAIL")
                        .font(.outfit(.regular, size: 9))
                        .tracking(2)
                        .foregroundColor(result.success ? Color(hex: "#2d5a3d") : .sgDanger)
                }
                .padding(.vertical, 6)

                if result.relayURL != relayResults.last?.relayURL {
                    Rectangle()
                        .fill(Color.sgBorder)
                        .frame(height: 1)
                }
            }
        }
        .padding(Dimensions.cardPadding)
        .background(Color.sgBgRaised)
        .cornerRadius(Dimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                .stroke(Color.sgBorder, lineWidth: 1)
        )
    }

    // MARK: - Computed properties

    private var canSign: Bool {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maxCharacters && !isActionInProgress
    }

    private var isActionInProgress: Bool {
        switch signState {
        case .signing, .broadcasting: return true
        default: return false
        }
    }

    private var signButtonLabel: String {
        switch signState {
        case .signing: return "SIGNING..."
        case .broadcasting: return "BROADCASTING..."
        default: return "SIGN & POST"
        }
    }

    // MARK: - Actions

    private func signAndPost() {
        guard canSign else { return }

        signState = .signing
        relayResults = []
        signedEventId = nil

        let content = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let signer = SoftwareSigner()

        Task {
            do {
                // 1. Get public key (triggers Face ID)
                let pubkeyData = try await signer.getPublicKey()
                let pubkeyHex = NostrKeyUtils.hexEncode(pubkeyData)

                // 2. Construct unsigned event
                let unsigned = NostrEvent.unsigned(
                    pubkey: pubkeyHex,
                    kind: 1,
                    content: content
                )

                // 3. Compute event ID
                let eventIdData = NostrEventSerializer.computeEventId(for: unsigned)
                let eventIdHex = NostrKeyUtils.hexEncode(eventIdData)

                // 4. Sign the event hash
                let sigData = try await signer.signHash(eventIdData)
                let sigHex = NostrKeyUtils.hexEncode(sigData)

                // 5. Assemble signed event
                let signedEvent = unsigned.signed(id: eventIdHex, sig: sigHex)

                await MainActor.run {
                    signedEventId = eventIdHex
                    signState = .broadcasting
                }

                // 6. Broadcast to relays
                let pool = NostrRelayPool()
                pool.addDefaultRelays()
                pool.connectAll()

                // Brief delay for WebSocket connections to establish
                try await Task.sleep(nanoseconds: 500_000_000)

                let results = await pool.publish(signedEvent)

                pool.disconnectAll()

                await MainActor.run {
                    relayResults = results
                    signState = .success

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }

            } catch {
                await MainActor.run {
                    signState = .error(error.localizedDescription)

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }

    private func resetForNewNote() {
        noteText = ""
        signState = .idle
        relayResults = []
        signedEventId = nil
    }
}
