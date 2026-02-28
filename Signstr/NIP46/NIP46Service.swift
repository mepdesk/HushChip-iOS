// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  NIP46Service.swift
//  Signstr — NIP-46 remote signer service: subscribe to kind 24133 events,
//  route to sessions, sign, and respond.

import CryptoKit
import Foundation
import LocalAuthentication
import UIKit
import UserNotifications

/// The main NIP-46 service that listens for signing requests from connected clients.
///
/// Lifecycle:
/// 1. User scans/pastes a `nostrconnect://` URI
/// 2. NIP46Service creates a session and subscribes to kind 24133 events on the relays
/// 3. When a request arrives, it decrypts, dispatches to the signer, encrypts the response,
///    and publishes the response event back to the relay
@MainActor
final class NIP46Service: ObservableObject {

    /// All active sessions, keyed by client pubkey.
    @Published private(set) var sessions: [String: NIP46Session] = [:]

    /// The current pending signing request awaiting user approval (nil = no pending request).
    @Published var pendingRequest: PendingSigningRequest?

    /// The signer used to handle signing requests.
    private let signer: NostrSigner

    /// Active WebSocket connections per relay URL.
    private var relayConnections: [String: URLSessionWebSocketTask] = [:]

    /// Tracks sent EVENT IDs awaiting OK confirmation, keyed by event ID.
    /// Value is (relayURL, sentTime). Entries are cleared on OK receipt or after timeout.
    private var pendingOKs: [String: (relayURL: String, sentAt: Date)] = [:]

    /// Tracks reconnection attempts per relay URL for exponential backoff.
    /// Value is the number of consecutive failed attempts.
    private var relayReconnectAttempts: [String: Int] = [:]

    /// Active reconnection timers per relay URL, so we can cancel if the relay is
    /// manually disconnected or reconnects successfully.
    private var relayReconnectTasks: [String: Task<Void, Never>] = [:]

    /// Queued requests awaiting sequential processing (prevents concurrent approval sheets
    /// which cause Swift Task continuation misuse).
    private var requestQueue: [(encryptedContent: String, session: NIP46Session, relayURL: String, queuedAt: CFAbsoluteTime)] = []

    /// Tracks already-processed incoming event IDs to deduplicate events that arrive
    /// from multiple relays. Keyed by event ID, value is the time it was processed.
    /// Cleared every 5 minutes to prevent unbounded memory growth.
    private var processedEventIDs: [String: Date] = [:]

    /// Timestamp of the last dedup cleanup sweep.
    private var lastDedupCleanup: Date = Date()

    /// Whether a request is currently being processed (waiting for user approval).
    private var isProcessingRequest = false

    /// The signer's hex-encoded public key (for filtering incoming events).
    /// In multi-identity mode, this is the ACTIVE identity's pubkey (used for AUTH, etc.).
    private var signerPubkeyHex: String?

    /// The signer's raw private key data (needed for NIP-44 conversation keys).
    /// In production, this is decrypted via biometrics only when needed.
    private var signerPrivateKey: Data?

    /// Per-identity key material, keyed by signer pubkey hex.
    /// Each entry stores the private key for that identity so we can handle
    /// NIP-46 events for ALL identities simultaneously.
    private var identityKeys: [String: Data] = [:]

    /// All signer pubkey hexes we're listening for (one per identity).
    private var allSignerPubkeys: Set<String> = []

    /// Event kinds considered safe for auto-approval (no user prompt needed):
    /// - 0: profile metadata
    /// - 3: contact list
    /// - 10000: mute list
    /// - 10001: pin list
    /// - 10002: relay list metadata
    /// - 22242: NIP-42 relay authentication
    static let safeAutoApproveKinds: Set<Int> = [0, 3, 10000, 10001, 10002, 22242]

    /// UserDefaults key for the "require approval for all events" override toggle.
    static let requireApprovalForAllKey = "signstr.require_approval_for_all"

    private let urlSession: URLSession

    init(signer: NostrSigner, urlSession: URLSession = .shared) {
        self.signer = signer
        self.urlSession = urlSession
    }

    // MARK: - Session management

    /// Adds a new connection from a parsed URI.
    func addConnection(
        from connectionInfo: NIP46ConnectionInfo,
        signerPrivateKey: Data,
        identityId: String? = nil
    ) throws -> NIP46Session {
        print("[NIP46] ── Adding connection ──")
        print("[NIP46]   Client pubkey: \(connectionInfo.pubkey)")
        print("[NIP46]   Name: \(connectionInfo.name ?? "nil")")
        print("[NIP46]   Relays: \(connectionInfo.relays)")
        print("[NIP46]   Flow: \(connectionInfo.flow)")
        print("[NIP46]   Secret present: \(connectionInfo.secret != nil)")
        print("[NIP46]   Identity ID: \(identityId ?? "nil")")

        let session = try NIP46Session(
            connectionInfo: connectionInfo,
            signerPrivateKey: signerPrivateKey
        )
        self.signerPrivateKey = signerPrivateKey

        // Derive signer pubkey
        let pubkeyData = try SchnorrSigner.derivePublicKey(from: signerPrivateKey)
        let thisPubkeyHex = NostrKeyUtils.hexEncode(pubkeyData)
        if signerPubkeyHex == nil {
            signerPubkeyHex = thisPubkeyHex
        }

        // Register this identity's key material
        identityKeys[thisPubkeyHex] = signerPrivateKey
        allSignerPubkeys.insert(thisPubkeyHex)

        print("[NIP46]   Signer pubkey: \(thisPubkeyHex)")
        print("[NIP46]   Safe auto-approve kinds: \(Self.safeAutoApproveKinds.sorted())")
        print("[NIP46]   Signer privkey (first 4 bytes): \(signerPrivateKey.prefix(4).map { String(format: "%02x", $0) }.joined())")
        // Log conversation key fingerprint for later comparison with decrypt side
        let convKeyHex = session.conversationKey.withUnsafeBytes { Data($0).prefix(8).map { String(format: "%02x", $0) }.joined() }
        print("[NIP46]   Conversation key (first 8 bytes): \(convKeyHex)")
        print("[NIP46]   ECDH inputs: privkey=\(NostrKeyUtils.hexEncode(signerPrivateKey).prefix(8))... pubkey=\(session.clientPubkey.prefix(16))...")

        // If a session already exists for this client, clean up its unique relay connections
        if let existing = sessions[session.clientPubkey] {
            print("[NIP46]   Replacing existing session for \(existing.displayName)")
            let otherSessionRelays = Set(sessions.values
                .filter { $0.clientPubkey != session.clientPubkey }
                .flatMap { $0.relays })
            for oldRelay in existing.relays where !otherSessionRelays.contains(oldRelay) && !session.relays.contains(oldRelay) {
                disconnectRelay(oldRelay)
                print("[NIP46]   Disconnected stale relay from old session: \(oldRelay)")
            }
        }
        sessions[session.clientPubkey] = session

        // Persist connection for restore on next launch
        let saved = SavedNIP46Connection(
            clientPubkey: session.clientPubkey,
            clientName: session.appName,
            relayURLs: session.relays,
            signerPubkey: thisPubkeyHex,
            encryption: session.encryptionPreference.rawValue,
            flow: connectionInfo.flow == .clientInitiated ? "clientInitiated" : "signerInitiated",
            permissions: connectionInfo.permissions,
            identityId: identityId
        )
        NIP46ConnectionStore.save(saved, signerPrivateKey: signerPrivateKey)

        // Connect to session relays and start listening
        for relayURL in session.relays {
            print("[NIP46]   Subscribing to relay: \(relayURL)")
            subscribeToRelay(relayURL)
        }

        // For client-initiated flow (nostrconnect://), send connect response
        // immediately so the client knows the signer is ready.
        // Uses NIP-44 per current NIP-46 spec (all modern clients use nostr-tools
        // which decrypts with NIP-44 only).
        if connectionInfo.flow == .clientInitiated {
            let secret = connectionInfo.secret ?? ""
            let clientPubkey = session.clientPubkey
            let relays = session.relays
            let convKey = session.conversationKey

            // Capture this identity's key material for the connect response
            let connectPubkey = thisPubkeyHex
            let connectPrivKey = signerPrivateKey

            // Log which identity is sending the connect response
            let identityName = identityId.flatMap { IdentityManager.shared.identity(for: $0)?.displayName } ?? "unknown"
            print("[NIP46] Sending connect response for identity: \(identityName) pubkey: \(connectPubkey.prefix(8))")

            print("[NIP46] Client-initiated flow — sending connect response (NIP-44)")
            print("[NIP46]   Secret: \(secret.isEmpty ? "empty" : String(secret.prefix(8)) + "...")")

            Task {
                // Build relay list with fallback
                let fallbackRelay = "wss://relay.damus.io"
                var sendRelays = relays
                if !sendRelays.contains(fallbackRelay) {
                    sendRelays.append(fallbackRelay)
                    print("[NIP46]   Adding fallback relay: \(fallbackRelay)")
                    self.subscribeToRelay(fallbackRelay)
                }

                do {
                    let response = NIP46Response.success(
                        id: UUID().uuidString,
                        result: secret
                    )
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .sortedKeys
                    let jsonData = try encoder.encode(response)
                    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                        print("[NIP46] ✗ Failed to encode connect response JSON")
                        return
                    }
                    print("[NIP46]   Connect response JSON: \(jsonString)")

                    let encrypted = try NIP44.encrypt(
                        plaintext: jsonString,
                        conversationKey: convKey
                    )
                    print("[NIP46]   Encrypted with NIP-44: \(encrypted.prefix(60))...")

                    for relayURL in sendRelays {
                        let isFallback = !relays.contains(relayURL)
                        print("[NIP46] → Connect response (NIP-44) to \(relayURL)\(isFallback ? " (fallback)" : "")...")
                        try await sendResponse(
                            encryptedContent: encrypted,
                            toClientPubkey: clientPubkey,
                            relayURL: relayURL,
                            explicitPubkey: connectPubkey,
                            explicitPrivateKey: connectPrivKey
                        )
                        print("[NIP46] ✓ Connect response sent to \(relayURL)\(isFallback ? " (fallback)" : "")")
                    }
                } catch {
                    print("[NIP46] ✗ Failed to send connect response: \(error)")
                }
            }
        }

        print("[NIP46] ── Connection added, listening for client requests ──")
        return session
    }

    /// Restores previously saved connections from UserDefaults + Keychain.
    /// Called on app launch to re-establish NIP-46 sessions without user interaction.
    /// Restores connections for ALL identities, not just the active one.
    func restoreConnections() {
        // First, load all identity keys from IdentityManager
        let identityManager = IdentityManager.shared
        for identity in identityManager.identities {
            if let nsec = identityManager.loadNsec(for: identity.id) {
                identityKeys[identity.pubkeyHex] = nsec
                allSignerPubkeys.insert(identity.pubkeyHex)
                print("[NIP46] Loaded key for identity '\(identity.displayName)' (\(identity.pubkeyHex.prefix(8))...)")
            }
        }

        // Set the active identity's key as the primary (for backward compat)
        if let active = identityManager.activeIdentity {
            signerPubkeyHex = active.pubkeyHex
            signerPrivateKey = identityKeys[active.pubkeyHex]
        }

        let saved = NIP46ConnectionStore.loadAll()
        guard !saved.isEmpty else {
            print("[NIP46] No saved connections to restore")
            // Still subscribe to relays for identity pubkeys if we have keys loaded
            return
        }

        print("[NIP46] Restoring \(saved.count) saved connections...")

        for connection in saved {
            // Load signer private key from Keychain
            guard let signerPrivKey = NIP46ConnectionStore.loadSignerPrivateKey(for: connection.clientPubkey) else {
                print("[NIP46] ⚠ Skipping \(connection.clientName ?? connection.clientPubkey.prefix(8).description): no private key in Keychain")
                NIP46ConnectionStore.delete(clientPubkey: connection.clientPubkey)
                continue
            }

            do {
                // Derive signer pubkey for this connection
                let pubkeyData = try SchnorrSigner.derivePublicKey(from: signerPrivKey)
                let connectionPubkeyHex = NostrKeyUtils.hexEncode(pubkeyData)

                // Register this identity's keys
                identityKeys[connectionPubkeyHex] = signerPrivKey
                allSignerPubkeys.insert(connectionPubkeyHex)

                if signerPubkeyHex == nil {
                    signerPubkeyHex = connectionPubkeyHex
                }
                if signerPrivateKey == nil {
                    self.signerPrivateKey = signerPrivKey
                }

                // Rederive NIP-44 conversation key from signer privkey + client pubkey
                let clientPubkeyData = try NostrKeyUtils.hexDecode(connection.clientPubkey)
                let conversationKey = try NIP44.conversationKey(
                    privateKey: signerPrivKey,
                    publicKey: clientPubkeyData
                )

                // Restore encryption preference
                let encryption: NIP46Encryption = connection.encryption == "nip04" ? .nip04 : .nip44

                // Recreate session
                let session = NIP46Session(
                    appName: connection.clientName,
                    clientPubkey: connection.clientPubkey,
                    relays: connection.relayURLs,
                    conversationKey: conversationKey,
                    permissions: connection.permissions
                )
                session.encryptionPreference = encryption

                sessions[session.clientPubkey] = session

                // Subscribe to all relays for this session
                for relayURL in session.relays {
                    subscribeToRelay(relayURL)
                }

                print("[NIP46] Restored connection: \(session.displayName) on \(connection.relayURLs)")
            } catch {
                print("[NIP46] ⚠ Failed to restore connection \(connection.clientName ?? connection.clientPubkey.prefix(8).description): \(error)")
            }
        }

        print("[NIP46] Restore complete: \(sessions.count) active sessions, \(allSignerPubkeys.count) identity pubkeys")
    }

    /// Removes a session and disconnects its relays if no other session uses them.
    func removeSession(clientPubkey: String) {
        guard let session = sessions.removeValue(forKey: clientPubkey) else { return }

        // Remove persisted connection data
        NIP46ConnectionStore.delete(clientPubkey: clientPubkey)

        // Check if any remaining session uses these relays
        let allActiveRelays = Set(sessions.values.flatMap { $0.relays })
        for relayURL in session.relays {
            if !allActiveRelays.contains(relayURL) {
                disconnectRelay(relayURL)
            }
        }
    }

    /// Returns all sessions as an array (for UI display).
    var activeSessions: [NIP46Session] {
        Array(sessions.values).sorted { $0.connectedAt < $1.connectedAt }
    }

    /// Returns sessions for a specific identity (by signer pubkey hex).
    func sessions(forSignerPubkey pubkeyHex: String) -> [NIP46Session] {
        let savedConnections = NIP46ConnectionStore.loadAll()
        let clientPubkeys = Set(savedConnections.filter { $0.signerPubkey == pubkeyHex }.map { $0.clientPubkey })
        return activeSessions.filter { clientPubkeys.contains($0.clientPubkey) }
    }

    /// Returns sessions for a specific identity UUID.
    func sessions(forIdentity identityId: String) -> [NIP46Session] {
        let savedConnections = NIP46ConnectionStore.loadAll(forIdentity: identityId)
        let clientPubkeys = Set(savedConnections.map { $0.clientPubkey })
        return activeSessions.filter { clientPubkeys.contains($0.clientPubkey) }
    }

    /// Registers an identity's key material so the service can handle its events.
    func registerIdentityKey(pubkeyHex: String, privateKey: Data) {
        identityKeys[pubkeyHex] = privateKey
        allSignerPubkeys.insert(pubkeyHex)
        print("[NIP46] Registered identity key for \(pubkeyHex.prefix(8))...")

        // Re-subscribe on all existing relays with the updated pubkey list
        for (relayURL, task) in relayConnections {
            sendSubscription(to: task, relayURL: relayURL)
        }
    }

    // MARK: - Relay subscription

    /// Subscribes to kind 24133 events on a relay addressed to our pubkey.
    private func subscribeToRelay(_ relayURLString: String) {
        guard relayConnections[relayURLString] == nil else {
            print("[NIP46] Already connected to \(relayURLString), skipping")
            return
        }
        guard let url = URL(string: relayURLString) else {
            print("[NIP46] ⚠ Invalid relay URL: \(relayURLString)")
            return
        }

        // Cancel any pending reconnection timer for this relay
        relayReconnectTasks[relayURLString]?.cancel()
        relayReconnectTasks.removeValue(forKey: relayURLString)

        print("[NIP46] Opening WebSocket to \(relayURLString)...")
        let task = urlSession.webSocketTask(with: url)
        relayConnections[relayURLString] = task
        task.resume()

        // Send REQ subscription
        sendSubscription(to: task, relayURL: relayURLString)

        // Start listening for events
        listenForMessages(on: task, relayURL: relayURLString)
    }

    private func sendSubscription(to task: URLSessionWebSocketTask, relayURL: String) {
        // Collect all pubkeys we need to subscribe for
        let pubkeys: [String]
        if allSignerPubkeys.isEmpty {
            guard let signerPubkey = signerPubkeyHex else {
                print("[NIP46] ⚠ Cannot subscribe — no signer pubkeys set")
                return
            }
            pubkeys = [signerPubkey]
        } else {
            pubkeys = Array(allSignerPubkeys)
        }

        // REQ: subscribe to kind 24133 events tagged to any of our pubkeys
        print("[NIP46]   Subscribing with \(pubkeys.count) signer pubkey(s): \(pubkeys.map { String($0.prefix(8)) })")
        let subId = "signstr-\(pubkeys.first?.prefix(8) ?? "unknown")"
        let sinceTimestamp = Int(Date().timeIntervalSince1970) - 60
        let filter: [String: Any] = [
            "kinds": [24133],
            "#p": pubkeys,
            "since": sinceTimestamp
        ]
        print("[NIP46]   Filter since: \(sinceTimestamp) (now - 60s)")

        guard let filterData = try? JSONSerialization.data(withJSONObject: filter),
              let filterString = String(data: filterData, encoding: .utf8) else {
            print("[NIP46] ⚠ Failed to serialize REQ filter")
            return
        }

        let message = "[\"REQ\",\"\(subId)\",\(filterString)]"
        print("[NIP46] → REQ to \(relayURL): \(message)")
        task.send(.string(message)) { error in
            if let error {
                print("[NIP46] ⚠ REQ send error: \(error)")
            } else {
                print("[NIP46] ✓ REQ sent to \(relayURL)")
            }
        }
    }

    private func disconnectRelay(_ relayURLString: String) {
        relayConnections[relayURLString]?.cancel(with: .normalClosure, reason: nil)
        relayConnections.removeValue(forKey: relayURLString)
        // Cancel any pending reconnection for this relay
        relayReconnectTasks[relayURLString]?.cancel()
        relayReconnectTasks.removeValue(forKey: relayURLString)
        relayReconnectAttempts.removeValue(forKey: relayURLString)
    }

    // MARK: - Message handling

    private func listenForMessages(on task: URLSessionWebSocketTask, relayURL: String) {
        task.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    // Successful message means relay is healthy — reset backoff
                    self?.relayReconnectAttempts[relayURL] = 0
                    switch message {
                    case .string(let text):
                        self?.handleRelayMessage(text, relayURL: relayURL)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self?.handleRelayMessage(text, relayURL: relayURL)
                        }
                    @unknown default:
                        break
                    }
                    // Continue listening
                    if let task = self?.relayConnections[relayURL] {
                        self?.listenForMessages(on: task, relayURL: relayURL)
                    }
                case .failure(let error):
                    print("[NIP46] ⚠ Relay \(relayURL) disconnected: \(error)")
                    self?.relayConnections.removeValue(forKey: relayURL)
                    self?.scheduleReconnect(relayURL: relayURL)
                }
            }
        }
    }

    /// Schedules a reconnection attempt with exponential backoff (1s, 2s, 4s, 8s, ... max 30s).
    /// If the relay still has active sessions that depend on it, reconnection is attempted.
    private func scheduleReconnect(relayURL: String) {
        // Only reconnect if at least one session still uses this relay
        let relayNeeded = sessions.values.contains { $0.relays.contains(relayURL) }
        guard relayNeeded else {
            print("[NIP46] Relay \(relayURL) not needed by any session, skipping reconnect")
            relayReconnectAttempts.removeValue(forKey: relayURL)
            return
        }

        // Cancel any existing reconnect timer for this relay
        relayReconnectTasks[relayURL]?.cancel()

        let attempt = (relayReconnectAttempts[relayURL] ?? 0) + 1
        relayReconnectAttempts[relayURL] = attempt

        // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s (capped)
        let delay = min(Double(1 << (attempt - 1)), 30.0)
        print("[NIP46] Scheduling reconnect to \(relayURL) in \(delay)s (attempt \(attempt))")

        relayReconnectTasks[relayURL] = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                // Task cancelled
                return
            }
            guard let self, !Task.isCancelled else { return }

            // Double-check relay is still needed and not already reconnected
            let stillNeeded = self.sessions.values.contains { $0.relays.contains(relayURL) }
            guard stillNeeded, self.relayConnections[relayURL] == nil else {
                print("[NIP46] Reconnect to \(relayURL) no longer needed (sessions changed or already connected)")
                self.relayReconnectAttempts.removeValue(forKey: relayURL)
                return
            }

            print("[NIP46] Reconnecting to \(relayURL) (attempt \(attempt))...")
            self.subscribeToRelay(relayURL)
        }
    }

    /// Parses a relay message and routes kind 24133 events to the correct session.
    private func handleRelayMessage(_ text: String, relayURL: String) {
        guard let data = text.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
              array.count >= 2,
              let messageType = array[0] as? String else {
            print("[NIP46] ← Unparseable message from \(relayURL): \(text.prefix(200))")
            return
        }

        // Log all relay messages (OK, EOSE, NOTICE, AUTH, EVENT, etc.)
        switch messageType {
        case "OK":
            let eventId = (array.count > 1 ? array[1] as? String : nil) ?? "?"
            let accepted = (array.count > 2 ? array[2] as? Bool : nil) ?? false
            let reason = (array.count > 3 ? array[3] as? String : nil) ?? ""
            print("[NIP46] ← OK from \(relayURL): event=\(eventId.prefix(16))... accepted=\(accepted) \(reason)")
            // Clear pending OK tracker
            pendingOKs.removeValue(forKey: eventId)
            return
        case "AUTH":
            let challenge = (array.count > 1 ? array[1] as? String : nil) ?? ""
            print("[NIP46] ← AUTH from \(relayURL): challenge=\(challenge)")
            if !challenge.isEmpty {
                handleAuthChallenge(challenge, relayURL: relayURL)
            }
            return
        case "EOSE":
            let subId = (array.count > 1 ? array[1] as? String : nil) ?? "?"
            print("[NIP46] ← EOSE from \(relayURL): sub=\(subId)")
            return
        case "NOTICE":
            let notice = (array.count > 1 ? array[1] as? String : nil) ?? "?"
            print("[NIP46] ← NOTICE from \(relayURL): \(notice)")
            return
        case "EVENT":
            break // Process below
        default:
            print("[NIP46] ← \(messageType) from \(relayURL): \(text.prefix(200))")
            return
        }

        guard array.count >= 3,
              let eventDict = array[2] as? [String: Any] else {
            print("[NIP46] ← EVENT from \(relayURL) but no event dict")
            return
        }

        // Parse the event
        guard let kind = eventDict["kind"] as? Int else {
            print("[NIP46] ← EVENT from \(relayURL) missing kind")
            return
        }

        guard kind == 24133 else {
            print("[NIP46] ← EVENT from \(relayURL) kind=\(kind) (ignoring, not 24133)")
            return
        }

        guard let senderPubkey = eventDict["pubkey"] as? String,
              let encryptedContent = eventDict["content"] as? String else {
            print("[NIP46] ← EVENT kind 24133 from \(relayURL) but missing pubkey or content")
            return
        }

        // Extract p-tag recipients and event ID for debugging
        let eventId = eventDict["id"] as? String ?? "?"
        let tags = eventDict["tags"] as? [[String]] ?? []
        let pTags = tags.filter { $0.first == "p" && $0.count > 1 }.map { $0[1] }

        print("[NIP46] ← EVENT kind 24133 from \(relayURL)")
        print("[NIP46]   Event ID: \(eventId.prefix(16))...")
        print("[NIP46]   Sender pubkey: \(senderPubkey)")
        print("[NIP46]   p-tags: \(pTags.map { String($0.prefix(8)) })")
        print("[NIP46]   Our signer pubkeys: \(allSignerPubkeys.map { String($0.prefix(8)) })")
        print("[NIP46]   Content length: \(encryptedContent.count) chars")

        // Determine which identity this event targets by checking p-tags
        let targetPubkey = pTags.first { allSignerPubkeys.contains($0) } ?? signerPubkeyHex
        if let tp = targetPubkey {
            // Set the correct private key context for processing this event
            if let identityPrivKey = identityKeys[tp] {
                signerPrivateKey = identityPrivKey
                signerPubkeyHex = tp
            }
        }

        // Dedup: skip events we've already processed (same event arrives on multiple relays)
        cleanupProcessedEventIDs()
        if eventId != "?", processedEventIDs[eventId] != nil {
            print("[NIP46]   Skipping duplicate event \(eventId.prefix(16))...")
            return
        }
        if eventId != "?" {
            processedEventIDs[eventId] = Date()
        }

        // Find the session for this client
        guard let session = sessions[senderPubkey] else {
            print("[NIP46] ⚠ No session found for sender \(senderPubkey.prefix(16))...")
            print("[NIP46]   Known sessions: \(sessions.keys.map { String($0.prefix(16)) })")
            return
        }

        print("[NIP46]   Matched session: \(session.displayName)")

        // Enqueue and process sequentially to avoid concurrent approval sheets
        enqueueRequest(encryptedContent: encryptedContent, session: session, relayURL: relayURL)
    }

    // MARK: - Request queue

    /// Adds a request to the sequential processing queue.
    private func enqueueRequest(encryptedContent: String, session: NIP46Session, relayURL: String) {
        let queuedAt = CFAbsoluteTimeGetCurrent()
        requestQueue.append((encryptedContent, session, relayURL, queuedAt))
        print("[NIP46] Queued request (queue depth: \(requestQueue.count), processing: \(isProcessingRequest))")
        processNextInQueue()
    }

    /// Processes the next queued request if nothing is currently being processed.
    private func processNextInQueue() {
        guard !isProcessingRequest, !requestQueue.isEmpty else { return }
        isProcessingRequest = true
        let next = requestQueue.removeFirst()
        print("[NIP46] Processing next request from queue (remaining: \(requestQueue.count))")

        Task {
            await processRequest(
                encryptedContent: next.encryptedContent,
                session: next.session,
                relayURL: next.relayURL,
                queuedAt: next.queuedAt
            )
            isProcessingRequest = false
            processNextInQueue()
        }
    }

    // MARK: - Approval

    /// Called by the UI when the user approves a pending signing request.
    func approvePendingRequest() {
        pendingRequest?.completion(true)
        pendingRequest = nil
    }

    /// Called by the UI when the user rejects a pending signing request.
    func rejectPendingRequest() {
        pendingRequest?.completion(false)
        pendingRequest = nil
    }

    // MARK: - Request processing

    /// Decrypts, handles, and responds to a NIP-46 request.
    /// For sign_event, pauses to show the approval UI before signing.
    /// Auto-approved events fire-and-forget the relay send to unblock the queue immediately.
    private func processRequest(
        encryptedContent: String,
        session: NIP46Session,
        relayURL: String,
        queuedAt: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    ) async {
        do {
            // 1. Decrypt and parse request — auto-detect NIP-44 vs NIP-04
            print("[NIP46] Decrypting request from \(session.displayName)...")

            // ── Debug: raw content inspection ──
            print("[NIP46]   Raw content (first 80 chars): \(encryptedContent.prefix(80))")
            print("[NIP46]   Raw content length: \(encryptedContent.count)")

            // Check for NIP-44 version byte by decoding base64
            if let decoded = Data(base64Encoded: encryptedContent) {
                let versionByte = decoded.first.map { String(format: "0x%02x", $0) } ?? "nil"
                print("[NIP46]   Base64 decoded OK, length: \(decoded.count), version byte: \(versionByte)")
                if decoded.count >= 4 {
                    let firstBytes = decoded.prefix(4).map { String(format: "%02x", $0) }.joined()
                    print("[NIP46]   First 4 bytes: \(firstBytes)")
                }
            } else {
                print("[NIP46]   NOT valid base64 (probably NIP-04 format)")
            }

            // ── Debug: key identity for decryption ──
            let convKeyHex = session.conversationKey.withUnsafeBytes { Data($0).prefix(8).map { String(format: "%02x", $0) }.joined() }
            print("[NIP46]   Session conversation key (first 8 bytes): \(convKeyHex)")
            if let privKey = signerPrivateKey {
                print("[NIP46]   Signer privkey for ECDH (first 4 bytes): \(privKey.prefix(4).map { String(format: "%02x", $0) }.joined())")
                print("[NIP46]   Client pubkey for ECDH: \(session.clientPubkey.prefix(16))...")
                // Re-derive conversation key to compare
                if let clientPubkeyData = try? NostrKeyUtils.hexDecode(session.clientPubkey) {
                    if let freshConvKey = try? NIP44.conversationKey(privateKey: privKey, publicKey: clientPubkeyData) {
                        let freshHex = freshConvKey.withUnsafeBytes { Data($0).prefix(8).map { String(format: "%02x", $0) }.joined() }
                        print("[NIP46]   Fresh conversation key (first 8 bytes): \(freshHex)")
                        print("[NIP46]   Conv key match: \(convKeyHex == freshHex ? "YES" : "MISMATCH!")")
                    }
                }
            } else {
                print("[NIP46]   ⚠ No signer private key available for ECDH!")
            }

            let decryptResult: (NIP46Request, NIP46Encryption)

            // Heuristic: NIP-04 payloads contain "?iv=" with base64;
            // NIP-44 payloads are pure base64 with a version byte prefix.
            let looksLikeNIP04 = encryptedContent.contains("?iv=")

            if looksLikeNIP04 {
                // Try NIP-04 first, fall back to NIP-44
                print("[NIP46]   Content contains '?iv=' — trying NIP-04 first...")
                do {
                    guard let privKey = signerPrivateKey else {
                        throw NIP04.NIP04Error.ecdhFailed
                    }
                    let clientPubkeyData = try NostrKeyUtils.hexDecode(session.clientPubkey)
                    let json = try NIP04.decrypt(
                        payload: encryptedContent,
                        privateKey: privKey,
                        publicKey: clientPubkeyData
                    )
                    let req = try NIP46MessageHandler.parseRequest(json)
                    print("[NIP46]   Decrypted with NIP-04")
                    decryptResult = (req, .nip04)
                } catch {
                    print("[NIP46]   NIP-04 failed (\(error)), trying NIP-44...")
                    let req = try NIP46MessageHandler.decryptRequest(
                        payload: encryptedContent,
                        conversationKey: session.conversationKey
                    )
                    print("[NIP46]   Decrypted with NIP-44 (fallback)")
                    decryptResult = (req, .nip44)
                }
            } else {
                // Try NIP-44 (HKDF conv key) → NIP-44 (raw ECDH) → NIP-04
                print("[NIP46]   No '?iv=' marker — trying NIP-44 first...")
                decryptResult = try decryptNIP44WithFallbacks(
                    encryptedContent: encryptedContent,
                    session: session
                )
            }

            let request = decryptResult.0
            let detectedEncryption = decryptResult.1

            // Update session encryption preference to match what the client sent
            if session.encryptionPreference != detectedEncryption {
                print("[NIP46]   Updating session encryption: \(session.encryptionPreference.rawValue) → \(detectedEncryption.rawValue)")
                session.encryptionPreference = detectedEncryption
            }
            print("[NIP46]   Session encryption: \(session.encryptionPreference.rawValue)")
            print("[NIP46]   Method: \(request.method)")
            print("[NIP46]   Request ID: \(request.id)")
            print("[NIP46]   Params count: \(request.params.count)")

            // 2. For sign_event, check approval policy before prompting
            var autoApprove = false
            var eventKind = 0
            var eventContent = ""
            if request.method == "sign_event" {
                // Parse event details for logging
                if let eventJSON = request.params.first,
                   let data = eventJSON.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // NSJSONSerialization may return NSNumber; handle both Int and Double
                    if let k = dict["kind"] as? Int {
                        eventKind = k
                    } else if let k = dict["kind"] as? Double {
                        eventKind = Int(k)
                    }
                    eventContent = dict["content"] as? String ?? ""
                    print("[NIP46]   sign_event kind: \(eventKind) (raw: \(String(describing: dict["kind"])))")
                } else {
                    print("[NIP46]   sign_event: FAILED to parse event JSON from params[0]")
                    print("[NIP46]   params[0] (first 200): \(request.params.first?.prefix(200) ?? "nil")")
                }

                // Check auto-approve: per-app policy OR safe-kind auto-approve
                let policyAutoApprove = ApprovalPolicyStore.shouldAutoApprove(for: session.clientPubkey)
                let requireApprovalForAll = UserDefaults.standard.bool(forKey: Self.requireApprovalForAllKey)
                let isSafeKind = Self.safeAutoApproveKinds.contains(eventKind)
                let safeKindAutoApprove = isSafeKind && !requireApprovalForAll
                autoApprove = policyAutoApprove || safeKindAutoApprove

                print("[NIP46]   Auto-approve decision: policyAutoApprove=\(policyAutoApprove) isSafeKind=\(isSafeKind) requireApprovalForAll=\(requireApprovalForAll) safeKindAutoApprove=\(safeKindAutoApprove) → autoApprove=\(autoApprove)")

                if safeKindAutoApprove {
                    print("[NIP46]   Safe kind \(eventKind) — auto-approving without prompt")
                }

                // ── Fast path: auto-approved sign_event ──
                // Sign immediately, fire-and-forget the relay send, return instantly
                // to unblock the queue for the next request.
                if autoApprove, let privKey = signerPrivateKey {
                    let signStart = CFAbsoluteTimeGetCurrent()
                    let response = NIP46MessageHandler.handleSignEventDirect(
                        request,
                        signerPubkeyHex: signerPubkeyHex!,
                        signerPrivateKey: privKey
                    )
                    let signEnd = CFAbsoluteTimeGetCurrent()

                    // Log the signing request
                    SigningLogStore.shared.log(
                        appName: session.displayName,
                        clientPubkey: session.clientPubkey,
                        eventKind: eventKind,
                        content: eventContent,
                        approved: true,
                        autoApproved: true,
                        safeKindAutoApproved: safeKindAutoApprove,
                        eventJSON: request.params.first ?? ""
                    )
                    ApprovalPolicyStore.recordFirstApproval(for: session.clientPubkey)

                    // Encrypt response
                    let encryptedResponse = try encryptForSession(response, session: session)

                    // Fire-and-forget: send to relay without awaiting confirmation
                    // Capture identity keys now — instance props may change before Task runs
                    let clientPubkey = session.clientPubkey
                    let capturedPubkey = signerPubkeyHex
                    let capturedPrivKey = signerPrivateKey
                    let sendStart = CFAbsoluteTimeGetCurrent()
                    Task { [weak self] in
                        do {
                            try await self?.sendResponse(
                                encryptedContent: encryptedResponse,
                                toClientPubkey: clientPubkey,
                                relayURL: relayURL,
                                explicitPubkey: capturedPubkey,
                                explicitPrivateKey: capturedPrivKey
                            )
                            let sendEnd = CFAbsoluteTimeGetCurrent()
                            let queueToSign = Int((signStart - queuedAt) * 1000)
                            let signToSend = Int((sendEnd - signEnd) * 1000)
                            let total = Int((sendEnd - queuedAt) * 1000)
                            print("[NIP46] ⏱ sign_event kind:\(eventKind) queued→signed: \(queueToSign)ms signed→sent: \(signToSend)ms total: \(total)ms")
                        } catch {
                            print("[NIP46] ✗ Fire-and-forget send failed for kind \(eventKind): \(error)")
                        }
                    }

                    // Log timing for the synchronous portion (queue unblocked here)
                    let queueToSign = Int((signStart - queuedAt) * 1000)
                    let signDuration = Int((signEnd - signStart) * 1000)
                    print("[NIP46] ⏱ sign_event kind:\(eventKind) queued→signed: \(queueToSign)ms sign: \(signDuration)ms (relay send is fire-and-forget)")
                    return
                }

                let approved: Bool
                if autoApprove {
                    approved = true
                } else {
                    approved = await requestUserApproval(
                        for: request,
                        session: session
                    )
                }

                // Log the signing request
                SigningLogStore.shared.log(
                    appName: session.displayName,
                    clientPubkey: session.clientPubkey,
                    eventKind: eventKind,
                    content: eventContent,
                    approved: approved,
                    autoApproved: autoApprove && approved,
                    safeKindAutoApproved: safeKindAutoApprove && approved,
                    eventJSON: request.params.first ?? ""
                )

                if approved {
                    // Record first approval for timed trust policies
                    ApprovalPolicyStore.recordFirstApproval(for: session.clientPubkey)
                }

                guard approved else {
                    // Send rejection response using the same encryption the client used
                    let response = NIP46Response.error(
                        id: request.id,
                        message: "User rejected the signing request"
                    )
                    let encrypted = try encryptForSession(response, session: session)
                    try await sendResponse(
                        encryptedContent: encrypted,
                        toClientPubkey: session.clientPubkey,
                        relayURL: relayURL
                    )
                    return
                }
            }

            // 3. Dispatch to handler
            let response: NIP46Response

            if request.method == "get_public_key", let pubkey = signerPubkeyHex {
                // Return pubkey directly — no biometric auth needed for public data
                print("[NIP46] Handling get_public_key directly (no biometrics)")
                response = .success(id: request.id, result: pubkey)
            } else if request.method == "sign_event", let pubkey = signerPubkeyHex, let privKey = signerPrivateKey {
                // User-approved sign_event — require Face ID, then sign with identity key
                print("[NIP46] Face ID required for kind \(eventKind) — authenticating...")

                let context = LAContext()
                var authError: NSError?
                let canUseBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)

                var faceIdPassed = false
                if canUseBiometrics {
                    do {
                        faceIdPassed = try await context.evaluatePolicy(
                            .deviceOwnerAuthenticationWithBiometrics,
                            localizedReason: "Sign a Nostr event"
                        )
                    } catch {
                        print("[NIP46] Face ID failed: \(error)")
                    }
                } else {
                    // No biometrics available (e.g. simulator) — allow signing
                    print("[NIP46] Biometrics unavailable — skipping Face ID")
                    faceIdPassed = true
                }

                if faceIdPassed {
                    let identityName = IdentityManager.shared.identity(forPubkey: pubkey)?.displayName ?? pubkey.prefix(8).description
                    print("[NIP46] Face ID passed — signing with identity \(identityName)")
                    response = NIP46MessageHandler.handleSignEventDirect(
                        request,
                        signerPubkeyHex: pubkey,
                        signerPrivateKey: privKey
                    )
                } else {
                    print("[NIP46] Face ID rejected — returning error to client")
                    response = .error(id: request.id, message: "Biometric authentication failed")
                }
            } else {
                print("[NIP46] Dispatching \(request.method) to handler...")
                response = await NIP46MessageHandler.handleRequest(
                    request,
                    signer: signer,
                    session: session
                )
            }
            print("[NIP46]   Response: result=\(response.result?.prefix(80) ?? "nil") error=\(response.error ?? "nil")")

            // 4. Encrypt response using the session's detected encryption preference
            let encryptedResponse = try encryptForSession(response, session: session)

            // 5. Build and send response event
            print("[NIP46] Sending response event to \(relayURL)...")
            try await sendResponse(
                encryptedContent: encryptedResponse,
                toClientPubkey: session.clientPubkey,
                relayURL: relayURL
            )
            print("[NIP46] ✓ Response sent for \(request.method) (id: \(request.id))")
        } catch {
            print("[NIP46] ✗ Error processing request: \(error)")

            // Send an error response back to the client so it doesn't hang waiting.
            // If decryption failed, we don't know the request ID — use a placeholder.
            do {
                let errorResponse = NIP46Response.error(
                    id: "error",
                    message: "Request processing failed: \(error.localizedDescription)"
                )
                let encrypted = try encryptForSession(errorResponse, session: session)
                try await sendResponse(
                    encryptedContent: encrypted,
                    toClientPubkey: session.clientPubkey,
                    relayURL: relayURL
                )
                print("[NIP46] ✓ Error response sent to client")
            } catch {
                print("[NIP46] ✗ Failed to send error response: \(error)")
            }
        }
    }

    // MARK: - Decryption helpers

    /// Attempts NIP-44 decryption with multiple key derivation strategies, then NIP-04 as final fallback.
    /// 1. NIP-44 with HKDF conversation key (standard)
    /// 2. NIP-44 with raw ECDH shared secret (non-standard, no HKDF)
    /// 3. NIP-04 (legacy)
    private func decryptNIP44WithFallbacks(
        encryptedContent: String,
        session: NIP46Session
    ) throws -> (NIP46Request, NIP46Encryption) {
        // Attempt 1: Standard NIP-44 with HKDF conversation key
        let ck4 = session.conversationKey.withUnsafeBytes { Data($0).prefix(4).map { String(format: "%02x", $0) }.joined() }
        print("[NIP46]   Attempt 1: NIP-44 with HKDF conversation key (first 4 bytes): \(ck4)")

        do {
            let req = try NIP46MessageHandler.decryptRequest(
                payload: encryptedContent,
                conversationKey: session.conversationKey
            )
            print("[NIP46]   Decrypted with NIP-44 (HKDF conversation key)")
            return (req, .nip44)
        } catch let nip44Error {
            print("[NIP46]   NIP-44 (HKDF) failed: \(nip44Error)")

            // Attempt 2: NIP-44 with raw ECDH shared secret (no HKDF)
            if let privKey = signerPrivateKey {
                do {
                    let clientPubkeyData = try NostrKeyUtils.hexDecode(session.clientPubkey)
                    let rawECDH = try NIP44.ecdhSharedSecret(privateKey: privKey, publicKey: clientPubkeyData)
                    let rawKey = SymmetricKey(data: rawECDH)
                    let rk4 = rawECDH.prefix(4).map { String(format: "%02x", $0) }.joined()
                    print("[NIP46]   Attempt 2: NIP-44 with raw ECDH key (first 4 bytes): \(rk4)")

                    let req = try NIP46MessageHandler.decryptRequest(
                        payload: encryptedContent,
                        conversationKey: rawKey
                    )
                    print("[NIP46]   Decrypted with NIP-44 (raw ECDH, no HKDF)")
                    return (req, .nip44)
                } catch {
                    print("[NIP46]   NIP-44 (raw ECDH) failed: \(error)")
                }
            }

            // Attempt 3: NIP-04 final fallback
            print("[NIP46]   Attempt 3: NIP-04 fallback...")
            guard let privKey = signerPrivateKey else {
                throw nip44Error
            }
            do {
                let clientPubkeyData = try NostrKeyUtils.hexDecode(session.clientPubkey)
                let json = try NIP04.decrypt(
                    payload: encryptedContent,
                    privateKey: privKey,
                    publicKey: clientPubkeyData
                )
                let req = try NIP46MessageHandler.parseRequest(json)
                print("[NIP46]   Decrypted with NIP-04 (final fallback)")
                return (req, .nip04)
            } catch {
                print("[NIP46]   NIP-04 also failed: \(error)")
                // Throw the original NIP-44 error since the content looked like NIP-44
                throw nip44Error
            }
        }
    }

    // MARK: - Encryption helpers

    /// Encrypts a NIP-46 response using the session's detected encryption preference.
    private func encryptForSession(
        _ response: NIP46Response,
        session: NIP46Session
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let jsonData = try encoder.encode(response)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NIP46MessageHandler.HandlerError.invalidJSON
        }

        switch session.encryptionPreference {
        case .nip04:
            guard let privKey = signerPrivateKey else {
                print("[NIP46] ⚠ No private key for NIP-04 encryption, falling back to NIP-44")
                return try NIP44.encrypt(plaintext: jsonString, conversationKey: session.conversationKey)
            }
            let clientPubkeyData = try NostrKeyUtils.hexDecode(session.clientPubkey)
            let encrypted = try NIP04.encrypt(
                plaintext: jsonString,
                privateKey: privKey,
                publicKey: clientPubkeyData
            )
            print("[NIP46]   Encrypted response with NIP-04 (\(encrypted.count) chars)")
            return encrypted

        case .nip44:
            let encrypted = try NIP44.encrypt(
                plaintext: jsonString,
                conversationKey: session.conversationKey
            )
            print("[NIP46]   Encrypted response with NIP-44 (\(encrypted.count) chars)")
            return encrypted
        }
    }

    /// Publishes a PendingSigningRequest and suspends until the user approves or rejects.
    private func requestUserApproval(
        for request: NIP46Request,
        session: NIP46Session
    ) async -> Bool {
        // Parse event JSON from params to extract kind and content
        var eventKind = 0
        var eventContent = ""
        if let eventJSON = request.params.first,
           let data = eventJSON.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            eventKind = dict["kind"] as? Int ?? 0
            eventContent = dict["content"] as? String ?? ""
        }

        // Fire a local notification if the app is backgrounded so the user
        // knows there is a signing request waiting for approval.
        if UIApplication.shared.applicationState != .active {
            let notifContent = UNMutableNotificationContent()
            notifContent.title = "Signing Request"
            notifContent.body = "\(session.displayName) wants to sign a kind \(eventKind) event"
            notifContent.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let notifRequest = UNNotificationRequest(
                identifier: "nip46-sign-\(request.id)",
                content: notifContent,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(notifRequest)
        }

        return await withCheckedContinuation { continuation in
            let pending = PendingSigningRequest(
                id: request.id,
                appName: session.displayName,
                clientPubkey: session.clientPubkey,
                eventKind: eventKind,
                content: eventContent,
                requestJSON: request.params.first ?? "",
                completion: { approved in
                    continuation.resume(returning: approved)
                }
            )
            self.pendingRequest = pending
        }
    }

    /// Builds a kind 24133 response event and sends it to the relay.
    /// When `explicitPubkey` / `explicitPrivateKey` are provided they override
    /// the instance-level `signerPubkeyHex` / `signerPrivateKey`. This ensures
    /// the correct identity's key is used for multi-identity connect responses.
    private func sendResponse(
        encryptedContent: String,
        toClientPubkey: String,
        relayURL: String,
        explicitPubkey: String? = nil,
        explicitPrivateKey: Data? = nil
    ) async throws {
        guard let signerPubkey = explicitPubkey ?? signerPubkeyHex,
              let privKey = explicitPrivateKey ?? signerPrivateKey else {
            print("[NIP46] ⚠ Cannot send response — missing signer pubkey or private key")
            return
        }

        // Build unsigned event
        print("[NIP46]   Outgoing event pubkey (signer): \(signerPubkey)")
        print("[NIP46]   Outgoing event p-tag (client): \(toClientPubkey)")
        let unsigned = NostrEvent.unsigned(
            pubkey: signerPubkey,
            kind: 24133,
            tags: [["p", toClientPubkey]],
            content: encryptedContent
        )

        // Compute serialized event for hashing
        let serialized = NostrEventSerializer.serialise(unsigned)
        print("[NIP46]   Serialized for hash: \(serialized)")

        // Compute ID and sign
        let eventIdData = NostrEventSerializer.computeEventId(for: unsigned)
        let eventIdHex = NostrKeyUtils.hexEncode(eventIdData)
        print("[NIP46]   Event ID (hash): \(eventIdHex)")

        let sigData = try SchnorrSigner.sign(hash: eventIdData, privateKey: privKey)
        let sigHex = NostrKeyUtils.hexEncode(sigData)
        print("[NIP46]   Signature: \(sigHex)")

        // Verify signature before sending
        let pubkeyData = try NostrKeyUtils.hexDecode(signerPubkey)
        let sigValid = try SchnorrSigner.verify(signature: sigData, hash: eventIdData, publicKey: pubkeyData)
        print("[NIP46]   Signature self-verify: \(sigValid ? "VALID" : "INVALID")")

        let signed = unsigned.signed(id: eventIdHex, sig: sigHex)

        // Encode and send
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let eventJSON = try encoder.encode(signed)
        guard let eventString = String(data: eventJSON, encoding: .utf8) else {
            print("[NIP46] ⚠ Failed to encode signed event to string")
            return
        }

        // Dump full raw EVENT JSON for debugging
        print("[NIP46] ── Full EVENT JSON ──")
        print("[NIP46] \(eventString)")
        print("[NIP46] ── End EVENT JSON ──")

        let message = "[\"EVENT\",\(eventString)]"
        print("[NIP46] → EVENT to \(relayURL)")
        print("[NIP46]   To client: \(toClientPubkey.prefix(16))...")
        print("[NIP46]   Message length: \(message.count) chars")

        if let task = relayConnections[relayURL] {
            try await task.send(.string(message))
            print("[NIP46] ✓ EVENT sent to \(relayURL)")
            // Track for OK timeout
            trackPendingOK(eventId: eventIdHex, relayURL: relayURL)
        } else {
            print("[NIP46] ⚠ No WebSocket connection for \(relayURL)")
            print("[NIP46]   Active connections: \(relayConnections.keys.joined(separator: ", "))")
        }
    }

    // MARK: - NIP-42 AUTH

    /// Handles a NIP-42 AUTH challenge from a relay by signing a kind 22242 event.
    private func handleAuthChallenge(_ challenge: String, relayURL: String) {
        guard let signerPubkey = signerPubkeyHex,
              let privKey = signerPrivateKey else {
            print("[NIP46] ⚠ Cannot respond to AUTH — missing signer key")
            return
        }

        Task {
            do {
                // Build kind 22242 auth event per NIP-42
                let unsigned = NostrEvent.unsigned(
                    pubkey: signerPubkey,
                    kind: 22242,
                    tags: [
                        ["relay", relayURL],
                        ["challenge", challenge]
                    ],
                    content: ""
                )

                // Compute ID and sign
                let eventIdData = NostrEventSerializer.computeEventId(for: unsigned)
                let eventIdHex = NostrKeyUtils.hexEncode(eventIdData)
                let sigData = try SchnorrSigner.sign(hash: eventIdData, privateKey: privKey)
                let sigHex = NostrKeyUtils.hexEncode(sigData)
                let signed = unsigned.signed(id: eventIdHex, sig: sigHex)

                // Encode and send ["AUTH", <signed_event>]
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                let eventJSON = try encoder.encode(signed)
                guard let eventString = String(data: eventJSON, encoding: .utf8) else {
                    print("[NIP46] ⚠ Failed to encode AUTH event")
                    return
                }

                let message = "[\"AUTH\",\(eventString)]"
                print("[NIP46] → AUTH response to \(relayURL)")
                print("[NIP46]   Event ID: \(eventIdHex.prefix(16))...")

                if let task = relayConnections[relayURL] {
                    try await task.send(.string(message))
                    print("[NIP46] ✓ AUTH response sent to \(relayURL)")

                    // Re-send subscription after authenticating
                    print("[NIP46]   Re-sending subscription after AUTH...")
                    sendSubscription(to: task, relayURL: relayURL)
                } else {
                    print("[NIP46] ⚠ No WebSocket connection for AUTH to \(relayURL)")
                }
            } catch {
                print("[NIP46] ✗ AUTH response failed: \(error)")
            }
        }
    }

    // MARK: - OK timeout tracking

    /// Registers a sent event ID for OK timeout tracking.
    /// Starts a 5-second delayed check; if no OK arrives, logs a warning.
    private func trackPendingOK(eventId: String, relayURL: String) {
        pendingOKs[eventId] = (relayURL: relayURL, sentAt: Date())

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            guard let self else { return }
            if let pending = self.pendingOKs[eventId] {
                print("[NIP46] ⚠ WARNING: No OK received from \(pending.relayURL) within 5s for event \(eventId.prefix(16))... — event may have been dropped")
                self.pendingOKs.removeValue(forKey: eventId)
            }
        }
    }

    // MARK: - Dedup cleanup

    /// Removes processed event IDs older than 5 minutes. Called before each dedup check.
    private func cleanupProcessedEventIDs() {
        let now = Date()
        guard now.timeIntervalSince(lastDedupCleanup) >= 300 else { return }
        lastDedupCleanup = now
        let cutoff = now.addingTimeInterval(-300)
        let before = processedEventIDs.count
        processedEventIDs = processedEventIDs.filter { $0.value > cutoff }
        let removed = before - processedEventIDs.count
        if removed > 0 {
            print("[NIP46] Dedup cleanup: removed \(removed) stale event IDs (\(processedEventIDs.count) remaining)")
        }
    }

    // MARK: - Cleanup

    /// Disconnects all relays and clears sessions.
    func disconnectAll() {
        for (_, task) in relayConnections {
            task.cancel(with: .normalClosure, reason: nil)
        }
        relayConnections.removeAll()
        // Cancel all pending reconnection timers
        for (_, task) in relayReconnectTasks {
            task.cancel()
        }
        relayReconnectTasks.removeAll()
        relayReconnectAttempts.removeAll()
        sessions.removeAll()
        signerPrivateKey = nil
        identityKeys.removeAll()
        allSignerPubkeys.removeAll()
    }
}
