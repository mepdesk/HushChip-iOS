// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  SigningRequestView.swift
//  Signstr — Approval UI for NIP-46 sign_event requests

import SwiftUI

struct SigningRequestView: View {
    let request: PendingSigningRequest
    let onApprove: () -> Void
    let onReject: () -> Void

    @State private var isSigning = false

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                // App icon
                Circle()
                    .fill(Color.sgBgSurface)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "signature")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(.sgTextMuted)
                    )

                Spacer().frame(height: 20)

                Text("SIGNING REQUEST")
                    .font(.outfit(.regular, size: 10))
                    .tracking(5)
                    .foregroundColor(.sgTextGhost)

                Spacer().frame(height: 24)

                // App name + action
                VStack(spacing: 6) {
                    Text(request.appName)
                        .font(.outfit(.regular, size: 20))
                        .foregroundColor(.sgTextBright)

                    Text("wants to sign an event")
                        .font(.outfit(.light, size: 13))
                        .foregroundColor(.sgTextFaint)
                }

                Spacer().frame(height: 32)

                // Event details card
                eventDetailsCard

                Spacer()

                if isSigning {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .sgTextMuted))
                        Text("Signing with Face ID...")
                            .font(.outfit(.light, size: 12))
                            .foregroundColor(.sgTextMuted)
                    }
                } else {
                    // Approve / Reject buttons
                    VStack(spacing: 12) {
                        SKButton(text: "Approve & Sign", style: .confirm) {
                            isSigning = true
                            onApprove()
                        }

                        SKButton(text: "Reject", style: .danger) {
                            onReject()
                        }
                    }
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Event details

    private var eventDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(label: "APP", value: request.appName)

            detailRow(label: "EVENT KIND", value: request.kindDescription)

            if !request.contentPreview.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONTENT")
                        .font(.outfit(.regular, size: 9))
                        .tracking(3)
                        .foregroundColor(.sgTextGhost)

                    Text(request.contentPreview)
                        .font(.outfit(.light, size: 13))
                        .foregroundColor(.sgTextBody)
                        .lineLimit(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            detailRow(label: "CLIENT PUBKEY", value: truncatePubkey(request.clientPubkey))
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

// MARK: - Pending signing request model

struct PendingSigningRequest: Identifiable {
    let id: String
    let appName: String
    let clientPubkey: String
    let eventKind: Int
    let content: String
    let requestJSON: String

    /// Continuation that the NIP46Service awaits — call with true (approved) or false (rejected).
    let completion: (Bool) -> Void

    var kindDescription: String {
        Self.humanReadableKind(eventKind)
    }

    var contentPreview: String {
        if content.count > 280 {
            return String(content.prefix(280)) + "..."
        }
        return content
    }

    static func humanReadableKind(_ kind: Int) -> String {
        switch kind {
        case 0: return "Profile metadata (kind 0)"
        case 1: return "Short note (kind 1)"
        case 2: return "Relay list (kind 2)"
        case 3: return "Contact list (kind 3)"
        case 4: return "Encrypted DM (kind 4)"
        case 5: return "Deletion (kind 5)"
        case 6: return "Repost (kind 6)"
        case 7: return "Reaction (kind 7)"
        case 8: return "Badge award (kind 8)"
        case 9735: return "Zap receipt (kind 9735)"
        case 10002: return "Relay list metadata (kind 10002)"
        case 22242: return "Auth challenge (kind 22242)"
        case 24133: return "NIP-46 request (kind 24133)"
        case 30023: return "Long-form article (kind 30023)"
        default: return "Event kind \(kind)"
        }
    }
}
