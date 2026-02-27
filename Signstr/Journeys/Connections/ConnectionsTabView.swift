// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  ConnectionsTabView.swift
//  Signstr — List of connected Nostr client apps (NIP-46 sessions)

import SwiftUI

struct ConnectionsTabView: View {
    @EnvironmentObject var nip46Service: NIP46Service

    @State private var showAddConnection = false
    @State private var selectedSession: NIP46Session?
    @State private var hasKey = KeyManager.keyExists()

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            if !hasKey {
                noKeyContent
            } else if nip46Service.activeSessions.isEmpty {
                emptyContent
            } else {
                sessionListContent
            }
        }
        .onAppear { hasKey = KeyManager.keyExists() }
        .fullScreenCover(isPresented: $showAddConnection) {
            AddConnectionView()
                .environmentObject(nip46Service)
        }
        .fullScreenCover(item: $nip46Service.pendingRequest) { request in
            SigningRequestView(
                request: request,
                onApprove: { nip46Service.approvePendingRequest() },
                onReject: { nip46Service.rejectPendingRequest() }
            )
        }
        .sheet(item: $selectedSession) { session in
            NavigationStack {
                AppSettingsView(session: session) {
                    nip46Service.removeSession(clientPubkey: session.clientPubkey)
                }
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

            Text("Generate or import a key in Settings before connecting apps.")
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Empty state

    private var emptyContent: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "link.badge.plus")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(.sgTextGhost)

            Text("NO CONNECTIONS")
                .font(.outfit(.regular, size: 11))
                .tracking(5)
                .foregroundColor(.sgTextMuted)

            Text("Scan a Nostr Connect QR from your favourite client to get started.")
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer().frame(height: 24)

            addConnectionButton

            Spacer()
        }
    }

    // MARK: - Session list

    private var sessionListContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                Text("CONNECTED APPS")
                    .font(.outfit(.regular, size: 10))
                    .tracking(5)
                    .foregroundColor(.sgTextGhost)

                Spacer().frame(height: 20)

                ForEach(nip46Service.activeSessions) { session in
                    Button(action: { selectedSession = session }) {
                        sessionRow(session)
                    }

                    if session.id != nip46Service.activeSessions.last?.id {
                        Rectangle()
                            .fill(Color.sgBorder)
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }

                Spacer().frame(height: 24)

                addConnectionButton

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Session row

    private func sessionRow(_ session: NIP46Session) -> some View {
        HStack(spacing: 12) {
            // App icon placeholder
            Circle()
                .fill(Color.sgBgSurface)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "app.connected.to.app.below.fill")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.sgTextMuted)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName)
                    .font(.outfit(.regular, size: 14))
                    .foregroundColor(.sgTextBright)

                Text(truncatePubkey(session.clientPubkey))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.sgTextFaint)
            }

            Spacer()

            // Connected indicator
            Circle()
                .fill(Color(hex: "#2d5a3d"))
                .frame(width: 8, height: 8)
        }
        .padding(Dimensions.cardPadding)
        .background(Color.sgBgRaised)
        .cornerRadius(Dimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                .stroke(Color.sgBorder, lineWidth: 1)
        )
    }

    // MARK: - Add connection button

    private var addConnectionButton: some View {
        Button(action: {
            showAddConnection = true
        }) {
            HStack(spacing: 10) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 14))
                Text("ADD CONNECTION")
                    .font(.outfit(.regular, size: 11))
                    .tracking(4)
            }
            .foregroundColor(.sgTextBright)
            .frame(width: 220, height: 50)
            .background(Color.sgBorder)
            .cornerRadius(Dimensions.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                    .stroke(Color.sgBorderHover, lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private func truncatePubkey(_ pubkey: String) -> String {
        guard pubkey.count > 16 else { return pubkey }
        let prefix = pubkey.prefix(8)
        let suffix = pubkey.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}
