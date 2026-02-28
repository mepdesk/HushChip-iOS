// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  NIP46ConnectionStore.swift
//  Signstr — Persists NIP-46 connection state across app launches.
//  Signer private keys are stored in Keychain; metadata goes to UserDefaults.

import Foundation

/// Serialisable snapshot of a NIP-46 connection (everything needed to restore a session).
struct SavedNIP46Connection: Codable, Equatable {
    /// Hex-encoded public key of the connected client app.
    let clientPubkey: String
    /// Human-readable name of the connected app (e.g. "Primal").
    let clientName: String?
    /// Relay URLs used for this connection.
    let relayURLs: [String]
    /// Hex-encoded public key of the signer (our key).
    let signerPubkey: String
    /// Encryption preference detected for this client.
    let encryption: String // "nip04" or "nip44"
    /// Connection flow type.
    let flow: String // "clientInitiated" or "signerInitiated"
    /// Permissions string from the original connection URI.
    let permissions: String?
}

/// Manages persistence of NIP-46 connections.
///
/// - **UserDefaults:** stores an array of `SavedNIP46Connection` (metadata only).
/// - **Keychain:** stores the signer private key (hex) per `clientPubkey`, keyed as
///   `signstr.nip46.privkey.<clientPubkey>`. The conversation key is rederived on restore.
enum NIP46ConnectionStore {

    private static let userDefaultsKey = "signstr.nip46_saved_connections"
    private static let keychainKeyPrefix = "signstr.nip46.privkey."

    // MARK: - Save

    /// Persists a connection. Stores metadata in UserDefaults and the signer private key
    /// in the Keychain.
    static func save(_ connection: SavedNIP46Connection, signerPrivateKey: Data) {
        // Store signer private key in Keychain
        let privkeyHex = NostrKeyUtils.hexEncode(signerPrivateKey)
        let keychainKey = keychainKeyPrefix + connection.clientPubkey
        KeychainHelper.shared.save(key: keychainKey, value: privkeyHex)
        print("[NIP46-Store] Saved signer privkey to Keychain: \(keychainKey)")

        // Load existing, replace or append, then save
        var connections = loadAll()
        connections.removeAll { $0.clientPubkey == connection.clientPubkey }
        connections.append(connection)
        saveAll(connections)
        print("[NIP46-Store] Saved connection metadata: \(connection.clientName ?? connection.clientPubkey.prefix(8).description) (\(connections.count) total)")
    }

    // MARK: - Load

    /// Returns all saved connection metadata.
    static func loadAll() -> [SavedNIP46Connection] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return [] }
        do {
            return try JSONDecoder().decode([SavedNIP46Connection].self, from: data)
        } catch {
            print("[NIP46-Store] Failed to decode saved connections: \(error)")
            return []
        }
    }

    /// Loads the signer private key for a given client pubkey from Keychain.
    /// Returns raw 32-byte key data, or nil if not found.
    static func loadSignerPrivateKey(for clientPubkey: String) -> Data? {
        let keychainKey = keychainKeyPrefix + clientPubkey
        guard let hex = KeychainHelper.shared.load(key: keychainKey) else {
            print("[NIP46-Store] No Keychain entry for \(keychainKey)")
            return nil
        }
        do {
            return try NostrKeyUtils.hexDecode(hex)
        } catch {
            print("[NIP46-Store] Failed to decode privkey hex for \(clientPubkey): \(error)")
            return nil
        }
    }

    // MARK: - Delete

    /// Removes a saved connection by client pubkey from both UserDefaults and Keychain.
    static func delete(clientPubkey: String) {
        // Remove from Keychain
        let keychainKey = keychainKeyPrefix + clientPubkey
        KeychainHelper.shared.delete(key: keychainKey)
        print("[NIP46-Store] Deleted Keychain entry: \(keychainKey)")

        // Remove from UserDefaults
        var connections = loadAll()
        connections.removeAll { $0.clientPubkey == clientPubkey }
        saveAll(connections)
        print("[NIP46-Store] Deleted connection: \(clientPubkey.prefix(8))... (\(connections.count) remaining)")
    }

    /// Removes all saved connections.
    static func deleteAll() {
        let connections = loadAll()
        for conn in connections {
            let keychainKey = keychainKeyPrefix + conn.clientPubkey
            KeychainHelper.shared.delete(key: keychainKey)
        }
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("[NIP46-Store] Deleted all saved connections")
    }

    // MARK: - Private

    private static func saveAll(_ connections: [SavedNIP46Connection]) {
        do {
            let data = try JSONEncoder().encode(connections)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("[NIP46-Store] Failed to encode connections: \(error)")
        }
    }
}
