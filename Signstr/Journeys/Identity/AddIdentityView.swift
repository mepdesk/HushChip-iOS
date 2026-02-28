// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  AddIdentityView.swift
//  Signstr — Add a new Nostr identity (generate or import nsec)

import SwiftUI

struct AddIdentityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var nip46Service: NIP46Service
    @ObservedObject var identityManager = IdentityManager.shared

    enum Step {
        case choose
        case importNsec
        case nameIdentity(Data) // carries the nsec
        case success(NostrIdentity)
        case error(String)
    }

    @State private var step: Step = .choose
    @State private var nsecText = ""
    @State private var displayNameText = ""

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            switch step {
            case .choose:
                chooseContent
            case .importNsec:
                importContent
            case .nameIdentity(let nsec):
                nameContent(nsec: nsec)
            case .success(let identity):
                successContent(identity)
            case .error(let message):
                errorContent(message)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Choose step

    private var chooseContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.sgTextBright)
                        .frame(width: 36, height: 36)
                        .background(Color.sgBgRaised)
                        .clipShape(Circle())
                }
                Spacer()
                Text("ADD IDENTITY")
                    .font(.outfit(.regular, size: 10))
                    .tracking(4)
                    .foregroundColor(.sgTextBright)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            Image(systemName: "person.badge.plus")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(.sgTextMuted)

            Spacer().frame(height: 24)

            Text("NEW IDENTITY")
                .font(.outfit(.regular, size: 10))
                .tracking(5)
                .foregroundColor(.sgTextGhost)

            Spacer().frame(height: 32)

            VStack(spacing: 16) {
                Button(action: { generateNewKey() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 14))
                        Text("GENERATE NEW KEY")
                            .font(.outfit(.regular, size: 11))
                            .tracking(4)
                    }
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

                Button(action: { step = .importNsec }) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14))
                        Text("IMPORT NSEC")
                            .font(.outfit(.regular, size: 11))
                            .tracking(4)
                    }
                    .foregroundColor(.sgTextMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.sgBgSurface)
                    .cornerRadius(Dimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Import step

    private var importContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { step = .choose }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.sgTextBright)
                        .frame(width: 36, height: 36)
                        .background(Color.sgBgRaised)
                        .clipShape(Circle())
                }
                Spacer()
                Text("IMPORT NSEC")
                    .font(.outfit(.regular, size: 10))
                    .tracking(4)
                    .foregroundColor(.sgTextBright)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    TextField("nsec1...", text: $nsecText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.sgTextBody)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Button(action: {
                        if let clip = UIPasteboard.general.string {
                            nsecText = clip
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

                Button(action: { importNsec() }) {
                    Text("IMPORT")
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
                .disabled(nsecText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(nsecText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1.0)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Name step

    private func nameContent(nsec: Data) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("NAME YOUR IDENTITY")
                    .font(.outfit(.regular, size: 10))
                    .tracking(4)
                    .foregroundColor(.sgTextBright)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            Spacer()

            VStack(spacing: 16) {
                Text("Give this identity a name so you can tell it apart from others.")
                    .font(.outfit(.light, size: 13))
                    .foregroundColor(.sgTextFaint)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                TextField("e.g. Personal, Work, Anon", text: $displayNameText)
                    .font(.outfit(.regular, size: 14))
                    .foregroundColor(.sgTextBody)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(Color.sgBgSurface)
                    .cornerRadius(Dimensions.inputCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimensions.inputCornerRadius)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )

                Button(action: { saveIdentity(nsec: nsec) }) {
                    Text("SAVE")
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
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Success step

    private func successContent(_ identity: NostrIdentity) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.sgBgSurface)
                    .frame(width: 72, height: 72)

                Text(identity.initials)
                    .font(.outfit(.medium, size: 24))
                    .foregroundColor(.sgTextBright)
            }

            Text("IDENTITY ADDED")
                .font(.outfit(.regular, size: 10))
                .tracking(5)
                .foregroundColor(.sgTextGhost)

            Text(identity.displayName)
                .font(.outfit(.regular, size: 18))
                .foregroundColor(.sgTextBright)

            if let npub = identity.npub {
                Text(identity.truncatedNpub)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.sgTextFaint)
            }

            Spacer().frame(height: 16)

            Button(action: { dismiss() }) {
                Text("DONE")
                    .font(.outfit(.regular, size: 10))
                    .tracking(3)
                    .foregroundColor(.sgTextBright)
                    .frame(width: 200, height: 44)
                    .background(Color.sgBorder)
                    .cornerRadius(Dimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                            .stroke(Color.sgBorderHover, lineWidth: 1)
                    )
            }

            Spacer()
        }
    }

    // MARK: - Error step

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(.sgDanger)

            Text("ERROR")
                .font(.outfit(.regular, size: 11))
                .tracking(5)
                .foregroundColor(.sgTextMuted)

            Text(message)
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer().frame(height: 16)

            Button(action: { step = .choose }) {
                Text("TRY AGAIN")
                    .font(.outfit(.regular, size: 10))
                    .tracking(3)
                    .foregroundColor(.sgTextBright)
                    .frame(width: 200, height: 44)
                    .background(Color.sgBorder)
                    .cornerRadius(Dimensions.buttonCornerRadius)
                }

            Button(action: { dismiss() }) {
                Text("CANCEL")
                    .font(.outfit(.regular, size: 10))
                    .tracking(3)
                    .foregroundColor(.sgTextMuted)
                    .frame(width: 200, height: 44)
            }

            Spacer()
        }
    }

    // MARK: - Logic

    private func generateNewKey() {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            step = .error("Failed to generate random key")
            return
        }
        let nsec = Data(bytes)
        step = .nameIdentity(nsec)
    }

    private func importNsec() {
        let trimmed = nsecText.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let nsec = try NostrKeyUtils.nsecDecode(trimmed)
            step = .nameIdentity(nsec)
        } catch {
            step = .error("Invalid nsec: \(error.localizedDescription)")
        }
    }

    private func saveIdentity(nsec: Data) {
        let name = displayNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let identity = try identityManager.addIdentity(
                nsec: nsec,
                displayName: name.isEmpty ? nil : name
            )

            // Register the key with the NIP46 service so it can handle events immediately
            nip46Service.registerIdentityKey(pubkeyHex: identity.pubkeyHex, privateKey: nsec)

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            step = .success(identity)
        } catch {
            step = .error(error.localizedDescription)
        }
    }
}
