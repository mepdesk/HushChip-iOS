// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  IdentityPickerView.swift
//  Signstr — Horizontal scrollable identity picker chips

import SwiftUI
import LocalAuthentication

struct IdentityPickerView: View {
    @ObservedObject var identityManager: IdentityManager
    @EnvironmentObject var nip46Service: NIP46Service

    /// The identity currently being viewed (controls which connections show below).
    @Binding var selectedIdentityId: String?

    /// Called when user taps an identity chip (navigates to identity detail).
    var onIdentityTap: ((NostrIdentity) -> Void)?

    /// Called when user taps the + button (add new identity).
    var onAddIdentity: (() -> Void)?

    @State private var showRenameAlert = false
    @State private var renameTargetId: String?
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var deleteTargetId: String?
    @State private var showBackupNsec = false
    @State private var backupNsec: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(identityManager.identities) { identity in
                    identityChip(identity)
                }

                // Add button
                addButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .alert("Rename Identity", isPresented: $showRenameAlert) {
            TextField("Display name", text: $renameText)
            Button("Save") {
                if let id = renameTargetId, !renameText.isEmpty {
                    identityManager.renameIdentity(id: id, name: renameText)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Identity?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let id = deleteTargetId {
                    try? identityManager.removeIdentity(id: id)
                    if selectedIdentityId == id {
                        selectedIdentityId = identityManager.identities.first?.id
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this identity and all its connections. This cannot be undone.")
        }
        .sheet(isPresented: $showBackupNsec) {
            if let nsec = backupNsec {
                BackupNsecSheet(nsec: nsec, onDismiss: {
                    showBackupNsec = false
                    backupNsec = nil
                })
            }
        }
    }

    // MARK: - Identity chip

    private func identityChip(_ identity: NostrIdentity) -> some View {
        let isSelected = selectedIdentityId == identity.id
        let connectionCount = nip46Service.sessions(forIdentity: identity.id).count

        return Button(action: {
            selectedIdentityId = identity.id
            identityManager.setActive(id: identity.id)
            onIdentityTap?(identity)
        }) {
            VStack(spacing: 6) {
                // Avatar circle with initials
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.sgBorderHover : Color.sgBgSurface)
                        .frame(width: 48, height: 48)

                    if isSelected {
                        Circle()
                            .stroke(Color.sgTextBright, lineWidth: 2)
                            .frame(width: 52, height: 52)
                    }

                    Text(identity.initials)
                        .font(.outfit(.medium, size: 16))
                        .foregroundColor(isSelected ? .sgTextWhite : .sgTextMuted)
                }

                // Name
                Text(identity.displayName)
                    .font(.outfit(.regular, size: 10))
                    .foregroundColor(isSelected ? .sgTextBright : .sgTextFaint)
                    .lineLimit(1)
                    .frame(maxWidth: 60)

                // Connection count
                if connectionCount > 0 {
                    Text("\(connectionCount)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.sgTextGhost)
                }
            }
        }
        .contextMenu {
            Button {
                renameTargetId = identity.id
                renameText = identity.displayName
                showRenameAlert = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                if let npub = identity.npub {
                    UIPasteboard.general.string = npub
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } label: {
                Label("Copy npub", systemImage: "doc.on.doc")
            }

            Button {
                backUpKey(identity: identity)
            } label: {
                Label("Back Up Key", systemImage: "key")
            }

            if identityManager.identities.count > 1 {
                Divider()
                Button(role: .destructive) {
                    deleteTargetId = identity.id
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Add button

    private var addButton: some View {
        Button(action: { onAddIdentity?() }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.sgBgSurface)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(Color.sgBorder, lineWidth: 1)
                        )

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.sgTextMuted)
                }

                Text("Add")
                    .font(.outfit(.regular, size: 10))
                    .foregroundColor(.sgTextFaint)
            }
        }
    }

    // MARK: - Key backup

    private func backUpKey(identity: NostrIdentity) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to back up your key") { success, _ in
            guard success else { return }
            DispatchQueue.main.async {
                if let nsec = identityManager.loadNsec(for: identity.id) {
                    if let nsecStr = try? NostrKeyUtils.nsecEncode(nsec) {
                        backupNsec = nsecStr
                        showBackupNsec = true
                    }
                }
            }
        }
    }
}

// MARK: - Backup nsec sheet

private struct BackupNsecSheet: View {
    let nsec: String
    let onDismiss: () -> Void

    @State private var revealed = false
    @State private var showCopied = false

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                Image(systemName: "key.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.sgDanger)

                Text("PRIVATE KEY")
                    .font(.outfit(.regular, size: 10))
                    .tracking(5)
                    .foregroundColor(.sgDanger)

                VStack(alignment: .leading, spacing: 8) {
                    Text("WARNING")
                        .font(.outfit(.regular, size: 9))
                        .tracking(3)
                        .foregroundColor(.sgDanger)

                    Text("Anyone who sees this key controls your Nostr identity. Copy it to a secure password manager.")
                        .font(.outfit(.light, size: 12))
                        .foregroundColor(.sgTextFaint)
                        .lineSpacing(4)
                }
                .padding(Dimensions.cardPadding)
                .background(Color.sgDangerBg)
                .cornerRadius(Dimensions.cardCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                        .stroke(Color.sgDangerBorder, lineWidth: 1)
                )

                // nsec display
                VStack(alignment: .leading, spacing: 8) {
                    Text("NSEC")
                        .font(.outfit(.regular, size: 9))
                        .tracking(3)
                        .foregroundColor(.sgTextGhost)

                    Text(revealed ? nsec : String(repeating: "\u{2022}", count: 32))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.sgTextBody)
                        .lineLimit(4)
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
                .onTapGesture { revealed.toggle() }

                HStack(spacing: 12) {
                    Button(action: {
                        UIPasteboard.general.string = nsec
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showCopied = true
                        // Auto-clear clipboard after 30 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                            if UIPasteboard.general.string == nsec {
                                UIPasteboard.general.string = ""
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(showCopied ? "COPIED" : "COPY")
                                .font(.outfit(.regular, size: 10))
                                .tracking(3)
                        }
                        .foregroundColor(.sgTextBright)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.sgBorder)
                        .cornerRadius(Dimensions.buttonCornerRadius)
                    }

                    Button(action: onDismiss) {
                        Text("DONE")
                            .font(.outfit(.regular, size: 10))
                            .tracking(3)
                            .foregroundColor(.sgTextMuted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.sgBgSurface)
                            .cornerRadius(Dimensions.buttonCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                                    .stroke(Color.sgBorder, lineWidth: 1)
                            )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
    }
}
