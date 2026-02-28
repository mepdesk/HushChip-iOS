// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  IdentityManager.swift
//  Signstr — Manages multiple Nostr identities (nsec/npub pairs)

import Foundation

// MARK: - Per-identity signing approval policy

/// Controls which event kinds are auto-approved for a given identity.
struct SigningApprovalPolicy: Codable, Equatable {
    /// Event kinds considered safe (auto-approved without user prompt).
    var safeKinds: Set<Int>

    /// When true, every signing request requires manual approval regardless of safe kinds.
    var requireApprovalForAll: Bool

    /// Default policy for new identities.
    static let `default` = SigningApprovalPolicy(
        safeKinds: [0, 3, 10000, 10001, 10002, 22242],
        requireApprovalForAll: false
    )

    /// Human-readable labels for well-known event kinds.
    static let kindLabels: [Int: String] = [
        0: "Profile",
        3: "Contacts",
        10000: "Mute List",
        10001: "Pin List",
        10002: "Relay List",
        22242: "Relay Auth",
    ]

    /// Returns a label for the given kind, or "Kind <n>" for unknown kinds.
    static func label(for kind: Int) -> String {
        kindLabels[kind] ?? "Kind \(kind)"
    }
}

// MARK: - NostrIdentity model

/// Represents a single Nostr identity (key pair).
/// The nsec is stored in Keychain keyed by `id`; only metadata lives here.
struct NostrIdentity: Identifiable, Codable, Equatable {
    /// Unique identifier for this identity.
    let id: String
    /// User-editable display name (defaults to truncated npub).
    var displayName: String
    /// Hex-encoded 32-byte x-only public key.
    let pubkeyHex: String
    /// When this identity was created/imported.
    let createdAt: Date

    /// Per-identity signing approval policy (which kinds to auto-approve).
    var approvalPolicy: SigningApprovalPolicy

    init(id: String, displayName: String, pubkeyHex: String, createdAt: Date,
         approvalPolicy: SigningApprovalPolicy = .default) {
        self.id = id
        self.displayName = displayName
        self.pubkeyHex = pubkeyHex
        self.createdAt = createdAt
        self.approvalPolicy = approvalPolicy
    }

    /// Decode with fallback: if `approvalPolicy` is missing (pre-migration data),
    /// use the default policy.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        pubkeyHex = try container.decode(String.self, forKey: .pubkeyHex)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        approvalPolicy = try container.decodeIfPresent(SigningApprovalPolicy.self, forKey: .approvalPolicy) ?? .default
    }

    /// The npub (bech32-encoded public key). Derived from pubkeyHex.
    var npub: String? {
        guard let data = try? NostrKeyUtils.hexDecode(pubkeyHex) else { return nil }
        return try? NostrKeyUtils.npubEncode(data)
    }

    /// Two-letter initials derived from the display name.
    var initials: String {
        let words = displayName.split(separator: " ").prefix(2)
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    /// Truncated npub for display (e.g. "npub1abc...xyz").
    var truncatedNpub: String {
        guard let n = npub else { return pubkeyHex.prefix(8) + "..." }
        guard n.count > 20 else { return n }
        return "\(n.prefix(12))...\(n.suffix(8))"
    }
}

// MARK: - IdentityManager

/// Manages a list of Nostr identities. Metadata is stored in UserDefaults;
/// nsec private keys are stored in Keychain keyed by identity UUID.
@MainActor
final class IdentityManager: ObservableObject {

    static let shared = IdentityManager()

    // MARK: - Published state

    /// All identities, ordered by creation date.
    @Published private(set) var identities: [NostrIdentity] = []

    /// The UUID of the currently active identity.
    @Published var activeIdentityId: String?

    // MARK: - UserDefaults keys

    private static let identitiesKey = "signstr.identities"
    private static let activeIdentityKey = "signstr.active_identity_id"
    private static let keychainPrefix = "signstr.identity.nsec."

    // MARK: - Init

    private init() {
        loadFromDefaults()
    }

    // MARK: - Computed

    /// The currently active identity, if any.
    var activeIdentity: NostrIdentity? {
        guard let id = activeIdentityId else { return identities.first }
        return identities.first { $0.id == id } ?? identities.first
    }

    /// Returns an identity by its UUID.
    func identity(for id: String) -> NostrIdentity? {
        identities.first { $0.id == id }
    }

    /// Whether any identities exist.
    var hasIdentities: Bool { !identities.isEmpty }

    // MARK: - Add identity

    /// Adds a new identity from a raw 32-byte nsec. Returns the new identity.
    @discardableResult
    func addIdentity(nsec: Data, displayName: String? = nil) throws -> NostrIdentity {
        guard nsec.count == 32 else {
            throw IdentityError.invalidKeyLength
        }

        // Derive pubkey
        let pubkeyData = try SchnorrSigner.derivePublicKey(from: nsec)
        let pubkeyHex = NostrKeyUtils.hexEncode(pubkeyData)

        // Check for duplicate pubkey
        if identities.contains(where: { $0.pubkeyHex == pubkeyHex }) {
            throw IdentityError.duplicateIdentity
        }

        let id = UUID().uuidString

        // Determine display name
        let name: String
        if let dn = displayName, !dn.isEmpty {
            name = dn
        } else {
            let npub = (try? NostrKeyUtils.npubEncode(pubkeyData)) ?? pubkeyHex
            name = "\(npub.prefix(8))...\(npub.suffix(4))"
        }

        let identity = NostrIdentity(
            id: id,
            displayName: name,
            pubkeyHex: pubkeyHex,
            createdAt: Date(),
            approvalPolicy: .default
        )

        // Store nsec in Keychain
        let nsecHex = NostrKeyUtils.hexEncode(nsec)
        KeychainHelper.shared.save(key: Self.keychainPrefix + id, value: nsecHex)

        // Add to list
        identities.append(identity)

        // If this is the first identity, make it active
        if identities.count == 1 {
            activeIdentityId = id
        }

        saveToDefaults()
        print("[IdentityManager] Added identity '\(name)' (\(pubkeyHex.prefix(8))...)")
        return identity
    }

    // MARK: - Remove identity

    /// Removes an identity. Cannot remove the last identity.
    func removeIdentity(id: String) throws {
        guard identities.count > 1 else {
            throw IdentityError.cannotRemoveLast
        }
        guard let index = identities.firstIndex(where: { $0.id == id }) else {
            throw IdentityError.notFound
        }

        // Delete nsec from Keychain
        KeychainHelper.shared.delete(key: Self.keychainPrefix + id)

        identities.remove(at: index)

        // If the active identity was removed, switch to the first remaining
        if activeIdentityId == id {
            activeIdentityId = identities.first?.id
        }

        saveToDefaults()
        print("[IdentityManager] Removed identity \(id.prefix(8))...")
    }

    // MARK: - Set active

    /// Sets the active identity by UUID.
    func setActive(id: String) {
        guard identities.contains(where: { $0.id == id }) else { return }
        activeIdentityId = id
        UserDefaults.standard.set(id, forKey: Self.activeIdentityKey)
        print("[IdentityManager] Active identity set to \(id.prefix(8))...")
    }

    // MARK: - Rename

    /// Renames an identity.
    func renameIdentity(id: String, name: String) {
        guard let index = identities.firstIndex(where: { $0.id == id }) else { return }
        identities[index].displayName = name
        saveToDefaults()
        print("[IdentityManager] Renamed identity \(id.prefix(8))... to '\(name)'")
    }

    /// Updates the signing approval policy for an identity.
    func updateApprovalPolicy(id: String, policy: SigningApprovalPolicy) {
        guard let index = identities.firstIndex(where: { $0.id == id }) else { return }
        identities[index].approvalPolicy = policy
        saveToDefaults()
        print("[IdentityManager] Updated approval policy for \(id.prefix(8))... (safeKinds: \(policy.safeKinds.sorted()), requireAll: \(policy.requireApprovalForAll))")
    }

    // MARK: - Key access

    /// Loads the raw 32-byte nsec for an identity from Keychain.
    func loadNsec(for identityId: String) -> Data? {
        guard let hex = KeychainHelper.shared.load(key: Self.keychainPrefix + identityId) else {
            return nil
        }
        return try? NostrKeyUtils.hexDecode(hex)
    }

    /// Loads the raw nsec for the active identity.
    func loadActiveNsec() -> Data? {
        guard let id = activeIdentity?.id else { return nil }
        return loadNsec(for: id)
    }

    /// Loads nsec for the identity matching a given pubkey hex.
    func loadNsec(forPubkey pubkeyHex: String) -> Data? {
        guard let identity = identities.first(where: { $0.pubkeyHex == pubkeyHex }) else {
            return nil
        }
        return loadNsec(for: identity.id)
    }

    /// Returns the identity that matches a given pubkey hex.
    func identity(forPubkey pubkeyHex: String) -> NostrIdentity? {
        identities.first { $0.pubkeyHex == pubkeyHex }
    }

    // MARK: - Migration

    /// Migrates a single existing key (from SecureEnclaveKeyStore) into the
    /// identity system. Called on first launch after the multi-identity update.
    func migrateExistingKey() {
        // Already migrated?
        guard identities.isEmpty else { return }

        // Check if old single key exists
        guard SecureEnclaveKeyStore.hasStoredKey() else { return }

        do {
            let nsec = try SecureEnclaveKeyStore.load()
            defer {
                let mutable = NSMutableData(data: nsec)
                memset(mutable.mutableBytes, 0, mutable.length)
            }

            let identity = try addIdentity(nsec: nsec, displayName: "Main")
            activeIdentityId = identity.id
            saveToDefaults()

            print("[IdentityManager] Migrated existing key as 'Main' identity")
        } catch {
            print("[IdentityManager] Migration failed: \(error)")
        }
    }

    /// Ensures every identity has a persisted approval policy.
    /// Called on launch; the `init(from:)` decoder already fills in defaults for
    /// identities saved before this feature existed, so we just re-save to persist.
    func migrateApprovalPolicies() {
        guard !identities.isEmpty else { return }
        // Re-save so that any default-filled policies are written to disk
        saveToDefaults()
        print("[IdentityManager] Ensured approval policies are persisted for \(identities.count) identities")
    }

    /// Migrates existing NIP-46 connections to belong to a specific identity.
    /// Called after migrateExistingKey() to associate connections with identity #1.
    func migrateExistingConnections(identityId: String) {
        var connections = NIP46ConnectionStore.loadAll()
        guard !connections.isEmpty else { return }

        // Re-save each connection with the identity UUID
        var updated: [SavedNIP46Connection] = []
        for conn in connections {
            let migrated = SavedNIP46Connection(
                clientPubkey: conn.clientPubkey,
                clientName: conn.clientName,
                relayURLs: conn.relayURLs,
                signerPubkey: conn.signerPubkey,
                encryption: conn.encryption,
                flow: conn.flow,
                permissions: conn.permissions,
                identityId: identityId
            )
            updated.append(migrated)
        }
        NIP46ConnectionStore.replaceAll(updated)
        print("[IdentityManager] Migrated \(updated.count) connections to identity \(identityId.prefix(8))...")
    }

    // MARK: - Persistence

    private func saveToDefaults() {
        do {
            let data = try JSONEncoder().encode(identities)
            UserDefaults.standard.set(data, forKey: Self.identitiesKey)
            if let activeId = activeIdentityId {
                UserDefaults.standard.set(activeId, forKey: Self.activeIdentityKey)
            }
        } catch {
            print("[IdentityManager] Failed to save identities: \(error)")
        }
    }

    private func loadFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: Self.identitiesKey) {
            do {
                identities = try JSONDecoder().decode([NostrIdentity].self, from: data)
            } catch {
                print("[IdentityManager] Failed to decode identities: \(error)")
            }
        }
        activeIdentityId = UserDefaults.standard.string(forKey: Self.activeIdentityKey)
    }

    // MARK: - Errors

    enum IdentityError: Error, LocalizedError {
        case invalidKeyLength
        case duplicateIdentity
        case cannotRemoveLast
        case notFound

        var errorDescription: String? {
            switch self {
            case .invalidKeyLength: return "Invalid key length (expected 32 bytes)"
            case .duplicateIdentity: return "This identity already exists"
            case .cannotRemoveLast: return "Cannot remove the last identity"
            case .notFound: return "Identity not found"
            }
        }
    }
}
