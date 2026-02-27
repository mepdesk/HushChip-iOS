// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  AppSettingsView.swift
//  Signstr — Per-app settings: approval policy, disconnect

import SwiftUI

struct AppSettingsView: View {
    let session: NIP46Session
    let onDisconnect: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPolicy: ApprovalPolicy
    @State private var showDisconnectConfirm = false

    init(session: NIP46Session, onDisconnect: @escaping () -> Void) {
        self.session = session
        self.onDisconnect = onDisconnect
        _selectedPolicy = State(initialValue: ApprovalPolicyStore.policy(for: session.clientPubkey))
    }

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
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

                    Spacer().frame(height: 16)

                    Text(session.displayName)
                        .font(.outfit(.regular, size: 20))
                        .foregroundColor(.sgTextBright)

                    Spacer().frame(height: 32)

                    // Connection info card
                    connectionInfoCard

                    Spacer().frame(height: 24)

                    // Approval policy section
                    approvalPolicySection

                    Spacer().frame(height: 40)

                    // Disconnect button
                    disconnectSection

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
                Text("APP SETTINGS")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
            }
        }
        .alert("Disconnect App", isPresented: $showDisconnectConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                ApprovalPolicyStore.removePolicy(for: session.clientPubkey)
                onDisconnect()
                dismiss()
            }
        } message: {
            Text("This will revoke the session for \(session.displayName). The app will need to reconnect to request signatures.")
        }
    }

    // MARK: - Connection info

    private var connectionInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(label: "APP", value: session.displayName)

            detailRow(
                label: "CONNECTED SINCE",
                value: session.connectedAt.formatted(date: .abbreviated, time: .shortened)
            )

            if let relay = session.relays.first {
                detailRow(label: "RELAY", value: relay.replacingOccurrences(of: "wss://", with: ""))
            }

            detailRow(
                label: "CLIENT PUBKEY",
                value: truncatePubkey(session.clientPubkey)
            )
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

    // MARK: - Approval policy

    private var approvalPolicySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APPROVAL POLICY")
                .font(.outfit(.regular, size: 9))
                .tracking(3)
                .foregroundColor(.sgTextGhost)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(ApprovalPolicy.allCases) { policy in
                    Button(action: {
                        selectedPolicy = policy
                        ApprovalPolicyStore.setPolicy(policy, for: session.clientPubkey)
                        // Reset trust timer when policy changes
                        ApprovalPolicyStore.clearFirstApproval(for: session.clientPubkey)
                    }) {
                        HStack(spacing: 12) {
                            // Radio indicator
                            Circle()
                                .fill(selectedPolicy == policy ? Color.sgTextBright : Color.clear)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selectedPolicy == policy ? Color.sgTextBright : Color.sgTextGhost,
                                            lineWidth: 1
                                        )
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(policy.displayName)
                                    .font(.outfit(.regular, size: 13))
                                    .foregroundColor(
                                        selectedPolicy == policy ? .sgTextBright : .sgTextBody
                                    )

                                Text(policy.description)
                                    .font(.outfit(.light, size: 10))
                                    .foregroundColor(.sgTextFaint)
                                    .lineLimit(2)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, Dimensions.cardPadding)
                        .padding(.vertical, 10)
                    }

                    if policy != ApprovalPolicy.allCases.last {
                        Rectangle()
                            .fill(Color.sgBorder)
                            .frame(height: 1)
                            .padding(.horizontal, Dimensions.cardPadding)
                    }
                }
            }
            .background(Color.sgBgRaised)
            .cornerRadius(Dimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                    .stroke(Color.sgBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Disconnect

    private var disconnectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DANGER ZONE")
                .font(.outfit(.regular, size: 9))
                .tracking(3)
                .foregroundColor(.sgDanger)
                .padding(.leading, 4)

            SKButton(text: "Disconnect \(session.displayName)", style: .danger) {
                showDisconnectConfirm = true
            }
        }
    }

    // MARK: - Helpers

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.outfit(.regular, size: 9))
                .tracking(3)
                .foregroundColor(.sgTextGhost)

            Text(value)
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextBody)
        }
    }

    private func truncatePubkey(_ pubkey: String) -> String {
        guard pubkey.count > 16 else { return pubkey }
        return "\(pubkey.prefix(8))...\(pubkey.suffix(4))"
    }
}
