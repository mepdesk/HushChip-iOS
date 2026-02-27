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

    /// The signer used to handle signing requests.
    private let signer: NostrSigner

    /// Active WebSocket connections per relay URL.
    private var relayConnections: [String: URLSessionWebSocketTask] = [:]

    /// The signer's hex-encoded public key (for filtering incoming events).
    private var signerPubkeyHex: String?

    /// The signer's raw private key data (needed for NIP-44 conversation keys).
    /// In production, this is decrypted via biometrics only when needed.
    private var signerPrivateKey: Data?

    private let urlSession: URLSession

    init(signer: NostrSigner, urlSession: URLSession = .shared) {
        self.signer = signer
        self.urlSession = urlSession
    }

    // MARK: - Session management

    /// Adds a new connection from a parsed URI.
    func addConnection(
        from connectionInfo: NIP46ConnectionInfo,
        signerPrivateKey: Data
    ) throws -> NIP46Session {
        let session = try NIP46Session(
            connectionInfo: connectionInfo,
            signerPrivateKey: signerPrivateKey
        )
        self.signerPrivateKey = signerPrivateKey

        // Derive signer pubkey if not yet known
        if signerPubkeyHex == nil {
            let pubkeyData = try SchnorrSigner.derivePublicKey(from: signerPrivateKey)
            signerPubkeyHex = NostrKeyUtils.hexEncode(pubkeyData)
        }

        sessions[session.clientPubkey] = session

        // Connect to session relays and start listening
        for relayURL in session.relays {
            subscribeToRelay(relayURL)
        }

        return session
    }

    /// Removes a session and disconnects its relays if no other session uses them.
    func removeSession(clientPubkey: String) {
        guard let session = sessions.removeValue(forKey: clientPubkey) else { return }

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

    // MARK: - Relay subscription

    /// Subscribes to kind 24133 events on a relay addressed to our pubkey.
    private func subscribeToRelay(_ relayURLString: String) {
        guard relayConnections[relayURLString] == nil,
              let url = URL(string: relayURLString) else { return }

        let task = urlSession.webSocketTask(with: url)
        relayConnections[relayURLString] = task
        task.resume()

        // Send REQ subscription
        sendSubscription(to: task, relayURL: relayURLString)

        // Start listening for events
        listenForMessages(on: task, relayURL: relayURLString)
    }

    private func sendSubscription(to task: URLSessionWebSocketTask, relayURL: String) {
        guard let signerPubkey = signerPubkeyHex else { return }

        // REQ: subscribe to kind 24133 events tagged to our pubkey
        let subId = "signstr-\(signerPubkey.prefix(8))"
        let filter: [String: Any] = [
            "kinds": [24133],
            "#p": [signerPubkey],
            "limit": 0 // Only new events, not historical
        ]

        guard let filterData = try? JSONSerialization.data(withJSONObject: filter),
              let filterString = String(data: filterData, encoding: .utf8) else { return }

        let message = "[\"REQ\",\"\(subId)\",\(filterString)]"
        task.send(.string(message)) { _ in }
    }

    private func disconnectRelay(_ relayURLString: String) {
        relayConnections[relayURLString]?.cancel(with: .normalClosure, reason: nil)
        relayConnections.removeValue(forKey: relayURLString)
    }

    // MARK: - Message handling

    private func listenForMessages(on task: URLSessionWebSocketTask, relayURL: String) {
        task.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
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
                case .failure:
                    // Relay disconnected — remove connection
                    self?.relayConnections.removeValue(forKey: relayURL)
                }
            }
        }
    }

    /// Parses a relay message and routes kind 24133 events to the correct session.
    private func handleRelayMessage(_ text: String, relayURL: String) {
        guard let data = text.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
              array.count >= 3,
              let messageType = array[0] as? String,
              messageType == "EVENT",
              let eventDict = array[2] as? [String: Any] else { return }

        // Parse the event
        guard let kind = eventDict["kind"] as? Int, kind == 24133,
              let senderPubkey = eventDict["pubkey"] as? String,
              let encryptedContent = eventDict["content"] as? String else { return }

        // Find the session for this client
        guard let session = sessions[senderPubkey] else { return }

        // Process the request asynchronously
        Task {
            await processRequest(
                encryptedContent: encryptedContent,
                session: session,
                relayURL: relayURL
            )
        }
    }

    // MARK: - Request processing

    /// Decrypts, handles, and responds to a NIP-46 request.
    private func processRequest(
        encryptedContent: String,
        session: NIP46Session,
        relayURL: String
    ) async {
        do {
            // 1. Decrypt and parse request
            let request = try NIP46MessageHandler.decryptRequest(
                payload: encryptedContent,
                conversationKey: session.conversationKey
            )

            // 2. Dispatch to handler
            let response = await NIP46MessageHandler.handleRequest(
                request,
                signer: signer,
                session: session
            )

            // 3. Encrypt response
            let encryptedResponse = try NIP46MessageHandler.encryptResponse(
                response,
                conversationKey: session.conversationKey
            )

            // 4. Build and send response event
            try await sendResponse(
                encryptedContent: encryptedResponse,
                toClientPubkey: session.clientPubkey,
                relayURL: relayURL
            )
        } catch {
            // Log error but don't crash — the client will timeout
            print("[NIP46Service] Error processing request: \(error)")
        }
    }

    /// Builds a kind 24133 response event and sends it to the relay.
    private func sendResponse(
        encryptedContent: String,
        toClientPubkey: String,
        relayURL: String
    ) async throws {
        guard let signerPubkey = signerPubkeyHex,
              let privKey = signerPrivateKey else { return }

        // Build unsigned event
        let unsigned = NostrEvent.unsigned(
            pubkey: signerPubkey,
            kind: 24133,
            tags: [["p", toClientPubkey]],
            content: encryptedContent
        )

        // Compute ID and sign
        let eventIdData = NostrEventSerializer.computeEventId(for: unsigned)
        let eventIdHex = NostrKeyUtils.hexEncode(eventIdData)
        let sigData = try SchnorrSigner.sign(hash: eventIdData, privateKey: privKey)
        let sigHex = NostrKeyUtils.hexEncode(sigData)

        let signed = unsigned.signed(id: eventIdHex, sig: sigHex)

        // Encode and send
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let eventJSON = try encoder.encode(signed)
        guard let eventString = String(data: eventJSON, encoding: .utf8) else { return }

        let message = "[\"EVENT\",\(eventString)]"

        if let task = relayConnections[relayURL] {
            try await task.send(.string(message))
        }
    }

    // MARK: - Cleanup

    /// Disconnects all relays and clears sessions.
    func disconnectAll() {
        for (_, task) in relayConnections {
            task.cancel(with: .normalClosure, reason: nil)
        }
        relayConnections.removeAll()
        sessions.removeAll()
        signerPrivateKey = nil
    }
}
