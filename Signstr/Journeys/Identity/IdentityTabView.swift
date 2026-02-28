// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  IdentityTabView.swift
//  Signstr — Identity tab: shows details for the active identity

import SwiftUI
import CoreImage.CIFilterBuiltins
import LocalAuthentication

struct IdentityTabView: View {
    @EnvironmentObject var nip46Service: NIP46Service
    @ObservedObject var identityManager = IdentityManager.shared

    @State private var showCopiedFeedback = false
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var showBackupNsec = false
    @State private var backupNsec: String?
    @State private var selectedIdentityId: String?
    @State private var showAddIdentity = false
    @State private var showSafeKindsEditor = false

    private var identity: NostrIdentity? {
        guard let id = selectedIdentityId else { return identityManager.activeIdentity }
        return identityManager.identity(for: id) ?? identityManager.activeIdentity
    }

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            if !identityManager.hasIdentities {
                noIdentityContent
            } else if let identity = identity {
                VStack(spacing: 0) {
                    IdentityPickerView(
                        identityManager: identityManager,
                        selectedIdentityId: $selectedIdentityId,
                        onIdentityTap: { _ in },
                        onAddIdentity: { showAddIdentity = true }
                    )
                    .environmentObject(nip46Service)

                    Rectangle()
                        .fill(Color.sgBorder)
                        .frame(height: 1)

                    identityContent(identity: identity)
                }
            } else {
                noIdentityContent
            }
        }
        .onAppear {
            if selectedIdentityId == nil {
                selectedIdentityId = identityManager.activeIdentity?.id
            }
        }
        .fullScreenCover(isPresented: $showAddIdentity) {
            AddIdentityView()
                .environmentObject(nip46Service)
        }
        .alert("Rename Identity", isPresented: $showRenameAlert) {
            TextField("Display name", text: $renameText)
            Button("Save") {
                if let id = identity?.id, !renameText.isEmpty {
                    identityManager.renameIdentity(id: id, name: renameText)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Identity?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let id = identity?.id {
                    try? identityManager.removeIdentity(id: id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this identity and all its connections. This cannot be undone.")
        }
        .sheet(isPresented: $showBackupNsec) {
            if let nsec = backupNsec {
                BackupNsecSheetView(nsec: nsec, onDismiss: {
                    showBackupNsec = false
                    backupNsec = nil
                })
            }
        }
    }

    // MARK: - No identity

    private var noIdentityContent: some View {
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

    private func identityContent(identity: NostrIdentity) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                Text("YOUR IDENTITY")
                    .font(.outfit(.regular, size: 10))
                    .tracking(5)
                    .foregroundColor(.sgTextGhost)

                Spacer().frame(height: 24)

                // Large avatar
                ProfileAvatarView(
                    pictureURL: identity.pictureURL,
                    initials: identity.initials,
                    size: 80,
                    fontSize: 28,
                    isSelected: true
                )

                Spacer().frame(height: 16)

                // Display name
                Text(identity.displayName)
                    .font(.outfit(.regular, size: 20))
                    .foregroundColor(.sgTextWhite)

                Spacer().frame(height: 8)

                // Connection count
                let connectionCount = nip46Service.sessions(forIdentity: identity.id).count
                Text("\(connectionCount) connection\(connectionCount == 1 ? "" : "s")")
                    .font(.outfit(.light, size: 12))
                    .foregroundColor(.sgTextFaint)

                Spacer().frame(height: 24)

                // QR code
                if let npub = identity.npub {
                    qrCodeView(for: npub)
                    Spacer().frame(height: 24)
                    npubCard(npub: npub)
                    Spacer().frame(height: 16)
                    copyButton(npub: npub)
                }

                Spacer().frame(height: 32)

                // Actions
                actionsSection(identity: identity)

                Spacer().frame(height: 32)

                // Signing Policy
                signingPolicySection(identity: identity)

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

            Text(truncateNpub(npub))
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.sgTextBody)

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
            UIPasteboard.general.string = npub
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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

    // MARK: - Actions

    private func actionsSection(identity: NostrIdentity) -> some View {
        VStack(spacing: 1) {
            actionRow(icon: "pencil", label: "RENAME") {
                renameText = identity.displayName
                showRenameAlert = true
            }

            actionRow(icon: "doc.on.doc", label: "COPY NPUB") {
                if let npub = identity.npub {
                    UIPasteboard.general.string = npub
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }

            actionRow(icon: "key", label: "BACK UP NSEC") {
                backUpKey(identity: identity)
            }

            if identityManager.identities.count > 1 {
                actionRow(icon: "trash", label: "DELETE IDENTITY", isDanger: true) {
                    showDeleteConfirm = true
                }
            }
        }
        .cornerRadius(Dimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                .stroke(Color.sgBorder, lineWidth: 1)
        )
    }

    private func actionRow(icon: String, label: String, isDanger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(isDanger ? .sgDanger : .sgTextMuted)
                    .frame(width: 24)

                Text(label)
                    .font(.outfit(.regular, size: 10))
                    .tracking(3)
                    .foregroundColor(isDanger ? .sgDanger : .sgTextBody)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.sgTextGhost)
            }
            .padding(.horizontal, Dimensions.cardPadding)
            .padding(.vertical, 14)
            .background(Color.sgBgRaised)
        }
    }

    // MARK: - Signing Policy

    private func signingPolicySection(identity: NostrIdentity) -> some View {
        VStack(spacing: 0) {
            // Section label
            Text("SIGNING POLICY")
                .font(.outfit(.regular, size: 9))
                .tracking(3)
                .foregroundColor(.sgTextGhost)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            Spacer().frame(height: 8)

            VStack(spacing: 1) {
                // Require approval for all toggle
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(.sgTextMuted)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("REQUIRE APPROVAL FOR ALL")
                            .font(.outfit(.regular, size: 10))
                            .tracking(3)
                            .foregroundColor(.sgTextBody)

                        Text("Override safe kinds — prompt for every event")
                            .font(.outfit(.light, size: 10))
                            .foregroundColor(.sgTextFaint)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { identity.approvalPolicy.requireApprovalForAll },
                        set: { newValue in
                            var policy = identity.approvalPolicy
                            policy.requireApprovalForAll = newValue
                            identityManager.updateApprovalPolicy(id: identity.id, policy: policy)
                        }
                    ))
                    .toggleStyle(SKToggleStyle(
                        onColor: Color.sgBorderHover,
                        offColor: Color.sgBgSurface,
                        thumbColor: Color.sgTextMuted
                    ))
                    .labelsHidden()
                    .frame(width: 50)
                }
                .padding(.horizontal, Dimensions.cardPadding)
                .padding(.vertical, 14)
                .background(Color.sgBgRaised)

                // Safe event types row
                Button(action: { showSafeKindsEditor = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(.sgTextMuted)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("SAFE EVENT TYPES")
                                .font(.outfit(.regular, size: 10))
                                .tracking(3)
                                .foregroundColor(.sgTextBody)

                            Text("\(identity.approvalPolicy.safeKinds.count) kind\(identity.approvalPolicy.safeKinds.count == 1 ? "" : "s") auto-approved")
                                .font(.outfit(.light, size: 10))
                                .foregroundColor(.sgTextFaint)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.sgTextGhost)
                    }
                    .padding(.horizontal, Dimensions.cardPadding)
                    .padding(.vertical, 14)
                    .background(Color.sgBgRaised)
                }
            }
            .cornerRadius(Dimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                    .stroke(Color.sgBorder, lineWidth: 1)
            )
        }
        .sheet(isPresented: $showSafeKindsEditor) {
            SafeKindsEditorView(identityId: identity.id)
        }
    }

    // MARK: - Go Air-Gapped upsell

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

    private func backUpKey(identity: NostrIdentity) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fallback: load without biometrics (e.g. simulator)
            if let nsec = identityManager.loadNsec(for: identity.id),
               let nsecStr = try? NostrKeyUtils.nsecEncode(nsec) {
                backupNsec = nsecStr
                showBackupNsec = true
            }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to back up your key") { success, _ in
            guard success else { return }
            DispatchQueue.main.async {
                if let nsec = identityManager.loadNsec(for: identity.id),
                   let nsecStr = try? NostrKeyUtils.nsecEncode(nsec) {
                    backupNsec = nsecStr
                    showBackupNsec = true
                }
            }
        }
    }

    private func truncateNpub(_ npub: String) -> String {
        guard npub.count > 20 else { return npub }
        return "\(npub.prefix(12))...\(npub.suffix(8))"
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

// MARK: - Backup nsec sheet

struct BackupNsecSheetView: View {
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

// MARK: - Safe kinds editor

struct SafeKindsEditorView: View {
    let identityId: String
    @ObservedObject private var identityManager = IdentityManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAddKind = false
    @State private var newKindText = ""

    private var identity: NostrIdentity? {
        identityManager.identity(for: identityId)
    }

    private var sortedKinds: [Int] {
        (identity?.approvalPolicy.safeKinds ?? []).sorted()
    }

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                Spacer().frame(height: 12)

                Capsule()
                    .fill(Color.sgBorder)
                    .frame(width: 36, height: 4)

                Spacer().frame(height: 24)

                Text("SAFE EVENT TYPES")
                    .font(.outfit(.regular, size: 9))
                    .tracking(3)
                    .foregroundColor(.sgTextGhost)

                Spacer().frame(height: 8)

                Text("Events with these kinds are signed automatically.")
                    .font(.outfit(.light, size: 12))
                    .foregroundColor(.sgTextFaint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                // Kind list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(sortedKinds, id: \.self) { kind in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(SigningApprovalPolicy.label(for: kind))
                                        .font(.outfit(.regular, size: 13))
                                        .foregroundColor(.sgTextBright)

                                    Text("Kind \(kind)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.sgTextFaint)
                                }

                                Spacer()

                                Button(action: { removeKind(kind) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.sgDanger)
                                }
                            }
                            .padding(.horizontal, Dimensions.cardPadding)
                            .padding(.vertical, 10)

                            if kind != sortedKinds.last {
                                Rectangle()
                                    .fill(Color.sgBorder)
                                    .frame(height: 1)
                                    .padding(.horizontal, Dimensions.cardPadding)
                            }
                        }

                        if sortedKinds.isEmpty {
                            Text("No safe kinds configured.\nAll events will require approval.")
                                .font(.outfit(.light, size: 12))
                                .foregroundColor(.sgTextFaint)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 20)
                        }
                    }
                    .background(Color.sgBgRaised)
                    .cornerRadius(Dimensions.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 16)

                    // Add kind button
                    Button(action: { showAddKind = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                            Text("ADD KIND")
                                .font(.outfit(.regular, size: 10))
                                .tracking(3)
                        }
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
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 16)

                    // Reset to defaults button
                    Button(action: resetToDefaults) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12))
                            Text("RESET TO DEFAULTS")
                                .font(.outfit(.regular, size: 10))
                                .tracking(3)
                        }
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
                    .padding(.horizontal, 24)
                }
            }
        }
        .alert("Add Event Kind", isPresented: $showAddKind) {
            TextField("Kind number (e.g. 1)", text: $newKindText)
                .keyboardType(.numberPad)
            Button("Add") {
                if let kind = Int(newKindText) {
                    addKind(kind)
                }
                newKindText = ""
            }
            Button("Cancel", role: .cancel) {
                newKindText = ""
            }
        } message: {
            Text("Enter the numeric event kind to auto-approve.")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func removeKind(_ kind: Int) {
        guard var policy = identity?.approvalPolicy else { return }
        policy.safeKinds.remove(kind)
        identityManager.updateApprovalPolicy(id: identityId, policy: policy)
    }

    private func addKind(_ kind: Int) {
        guard var policy = identity?.approvalPolicy else { return }
        policy.safeKinds.insert(kind)
        identityManager.updateApprovalPolicy(id: identityId, policy: policy)
    }

    private func resetToDefaults() {
        guard var policy = identity?.approvalPolicy else { return }
        policy.safeKinds = SigningApprovalPolicy.default.safeKinds
        identityManager.updateApprovalPolicy(id: identityId, policy: policy)
    }
}
