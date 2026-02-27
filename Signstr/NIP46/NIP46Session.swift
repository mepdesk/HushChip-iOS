// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  NIP46Session.swift
//  Signstr — Represents one connected NIP-46 client session

import CryptoKit
import Foundation

/// Which encryption scheme a NIP-46 client uses for kind 24133 communication.
enum NIP46Encryption: String, Sendable {
    /// NIP-04: ECDH + AES-256-CBC, format `base64(ct)?iv=base64(iv)`.
    case nip04
    /// NIP-44: Versioned envelope with ChaCha20 + HMAC-SHA256.
    case nip44
}

/// A single NIP-46 client connection.
///
/// Each session represents one remote Nostr client (e.g. Damus, Primal) that has
/// connected to Signstr and can send signing requests.
final class NIP46Session: Identifiable, Hashable, Sendable {
    static func == (lhs: NIP46Session, rhs: NIP46Session) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Unique session identifier.
    let id: UUID

    /// Human-readable name of the connected app (e.g. "Damus").
    let appName: String?

    /// 32-byte hex public key of the remote client.
    let clientPubkey: String

    /// Relay URLs used for this session's NIP-46 communication.
    let relays: [String]

    /// NIP-44 conversation key (pre-computed for this client-signer pair).
    let conversationKey: SymmetricKey

    /// When the session was established.
    let connectedAt: Date

    /// Permissions granted to this client (nil = ask for everything).
    let permissions: String?

    /// Detected encryption preference for this client.
    /// Defaults to `.nip04` (most clients). Updated when the first incoming request
    /// is successfully decrypted, so subsequent responses match the client's format.
    /// Only mutated from @MainActor NIP46Service.
    nonisolated(unsafe) var encryptionPreference: NIP46Encryption = .nip04

    init(
        id: UUID = UUID(),
        appName: String?,
        clientPubkey: String,
        relays: [String],
        conversationKey: SymmetricKey,
        connectedAt: Date = Date(),
        permissions: String? = nil
    ) {
        self.id = id
        self.appName = appName
        self.clientPubkey = clientPubkey
        self.relays = relays
        self.conversationKey = conversationKey
        self.connectedAt = connectedAt
        self.permissions = permissions
    }

    /// Creates a session from a parsed connection info and the signer's private key.
    convenience init(
        connectionInfo: NIP46ConnectionInfo,
        signerPrivateKey: Data
    ) throws {
        let convKey = try NIP44.conversationKey(
            privateKey: signerPrivateKey,
            publicKey: NostrKeyUtils.hexDecode(connectionInfo.pubkey)
        )
        self.init(
            appName: connectionInfo.name,
            clientPubkey: connectionInfo.pubkey,
            relays: connectionInfo.relays,
            conversationKey: convKey,
            permissions: connectionInfo.permissions
        )
    }

    /// Display name: app name if known, otherwise truncated client pubkey.
    var displayName: String {
        if let name = appName, !name.isEmpty { return name }
        let prefix = clientPubkey.prefix(8)
        let suffix = clientPubkey.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}
