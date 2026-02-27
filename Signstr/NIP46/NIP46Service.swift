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

    /// The current pending signing request awaiting user approval (nil = no pending request).
    @Published var pendingRequest: PendingSigningRequest?

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
        print("[NIP46] ── Adding connection ──")
        print("[NIP46]   Client pubkey: \(connectionInfo.pubkey)")
        print("[NIP46]   Name: \(connectionInfo.name ?? "nil")")
        print("[NIP46]   Relays: \(connectionInfo.relays)")
        print("[NIP46]   Flow: \(connectionInfo.flow)")
        print("[NIP46]   Secret present: \(connectionInfo.secret != nil)")

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
        print("[NIP46]   Signer pubkey: \(signerPubkeyHex ?? "nil")")
        print("[NIP46]   Conversation key derived: \(session.conversationKey.withUnsafeBytes { Data($0).count }) bytes")

        sessions[session.clientPubkey] = session

        // Connect to session relays and start listening
        for relayURL in session.relays {
            print("[NIP46]   Subscribing to relay: \(relayURL)")
            subscribeToRelay(relayURL)
        }

        // For client-initiated flow (nostrconnect://), send connect response
        // immediately so the client knows the signer is ready.
        if connectionInfo.flow == .clientInitiated {
            let secret = connectionInfo.secret ?? ""
            let clientPubkey = session.clientPubkey
            let convKey = session.conversationKey
            let relays = session.relays

            print("[NIP46] Client-initiated flow — sending connect response (secret=\(secret.isEmpty ? "empty" : secret.prefix(8) + "..."))")

            Task {
                do {
                    let response = NIP46Response.success(
                        id: UUID().uuidString,
                        result: secret
                    )
                    let encrypted = try NIP46MessageHandler.encryptResponse(
                        response,
                        conversationKey: convKey
                    )

                    for relayURL in relays {
                        print("[NIP46] → Connect response to \(relayURL)...")
                        try await sendResponse(
                            encryptedContent: encrypted,
                            toClientPubkey: clientPubkey,
                            relayURL: relayURL
                        )
                        print("[NIP46] ✓ Connect response sent to \(relayURL)")
                    }
                } catch {
                    print("[NIP46] ✗ Failed to send connect response: \(error)")
                }
            }
        }

        print("[NIP46] ── Connection added, listening for client requests ──")
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
        guard relayConnections[relayURLString] == nil else {
            print("[NIP46] Already connected to \(relayURLString), skipping")
            return
        }
        guard let url = URL(string: relayURLString) else {
            print("[NIP46] ⚠ Invalid relay URL: \(relayURLString)")
            return
        }

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
        guard let signerPubkey = signerPubkeyHex else {
            print("[NIP46] ⚠ Cannot subscribe — signer pubkey not set")
            return
        }

        // REQ: subscribe to kind 24133 events tagged to our pubkey
        let subId = "signstr-\(signerPubkey.prefix(8))"
        let filter: [String: Any] = [
            "kinds": [24133],
            "#p": [signerPubkey],
            "limit": 0 // Only new events, not historical
        ]

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
                case .failure(let error):
                    print("[NIP46] ⚠ Relay \(relayURL) disconnected: \(error)")
                    self?.relayConnections.removeValue(forKey: relayURL)
                }
            }
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

        // Log all relay messages (OK, EOSE, NOTICE, EVENT, etc.)
        switch messageType {
        case "OK":
            let eventId = (array.count > 1 ? array[1] as? String : nil) ?? "?"
            let accepted = (array.count > 2 ? array[2] as? Bool : nil) ?? false
            let reason = (array.count > 3 ? array[3] as? String : nil) ?? ""
            print("[NIP46] ← OK from \(relayURL): event=\(eventId.prefix(16))... accepted=\(accepted) \(reason)")
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

        print("[NIP46] ← EVENT kind 24133 from \(relayURL)")
        print("[NIP46]   Sender: \(senderPubkey.prefix(16))...")
        print("[NIP46]   Content length: \(encryptedContent.count) chars")

        // Find the session for this client
        guard let session = sessions[senderPubkey] else {
            print("[NIP46] ⚠ No session found for sender \(senderPubkey.prefix(16))...")
            print("[NIP46]   Known sessions: \(sessions.keys.map { String($0.prefix(16)) })")
            return
        }

        print("[NIP46]   Matched session: \(session.displayName)")

        // Process the request asynchronously
        Task {
            await processRequest(
                encryptedContent: encryptedContent,
                session: session,
                relayURL: relayURL
            )
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
    private func processRequest(
        encryptedContent: String,
        session: NIP46Session,
        relayURL: String
    ) async {
        do {
            // 1. Decrypt and parse request
            print("[NIP46] Decrypting request from \(session.displayName)...")
            let request = try NIP46MessageHandler.decryptRequest(
                payload: encryptedContent,
                conversationKey: session.conversationKey
            )
            print("[NIP46]   Method: \(request.method)")
            print("[NIP46]   Request ID: \(request.id)")
            print("[NIP46]   Params count: \(request.params.count)")

            // 2. For sign_event, check approval policy before prompting
            if request.method == "sign_event" {
                // Parse event details for logging
                var eventKind = 0
                var eventContent = ""
                if let eventJSON = request.params.first,
                   let data = eventJSON.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    eventKind = dict["kind"] as? Int ?? 0
                    eventContent = dict["content"] as? String ?? ""
                }

                let autoApprove = ApprovalPolicyStore.shouldAutoApprove(for: session.clientPubkey)

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
                    eventJSON: request.params.first ?? ""
                )

                if approved {
                    // Record first approval for timed trust policies
                    ApprovalPolicyStore.recordFirstApproval(for: session.clientPubkey)
                }

                guard approved else {
                    // Send rejection response
                    let response = NIP46Response.error(
                        id: request.id,
                        message: "User rejected the signing request"
                    )
                    let encrypted = try NIP46MessageHandler.encryptResponse(
                        response,
                        conversationKey: session.conversationKey
                    )
                    try await sendResponse(
                        encryptedContent: encrypted,
                        toClientPubkey: session.clientPubkey,
                        relayURL: relayURL
                    )
                    return
                }
            }

            // 3. Dispatch to handler (signer will trigger Face ID for sign_event)
            print("[NIP46] Dispatching \(request.method) to handler...")
            let response = await NIP46MessageHandler.handleRequest(
                request,
                signer: signer,
                session: session
            )
            print("[NIP46]   Response: result=\(response.result?.prefix(80) ?? "nil") error=\(response.error ?? "nil")")

            // 4. Encrypt response
            print("[NIP46] Encrypting response...")
            let encryptedResponse = try NIP46MessageHandler.encryptResponse(
                response,
                conversationKey: session.conversationKey
            )
            print("[NIP46]   Encrypted response length: \(encryptedResponse.count) chars")

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
    private func sendResponse(
        encryptedContent: String,
        toClientPubkey: String,
        relayURL: String
    ) async throws {
        guard let signerPubkey = signerPubkeyHex,
              let privKey = signerPrivateKey else {
            print("[NIP46] ⚠ Cannot send response — missing signer pubkey or private key")
            return
        }

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
        guard let eventString = String(data: eventJSON, encoding: .utf8) else {
            print("[NIP46] ⚠ Failed to encode signed event to string")
            return
        }

        let message = "[\"EVENT\",\(eventString)]"
        print("[NIP46] → EVENT to \(relayURL)")
        print("[NIP46]   Event ID: \(eventIdHex.prefix(16))...")
        print("[NIP46]   To client: \(toClientPubkey.prefix(16))...")
        print("[NIP46]   Message length: \(message.count) chars")

        if let task = relayConnections[relayURL] {
            try await task.send(.string(message))
            print("[NIP46] ✓ EVENT sent to \(relayURL)")
        } else {
            print("[NIP46] ⚠ No WebSocket connection for \(relayURL)")
            print("[NIP46]   Active connections: \(relayConnections.keys.joined(separator: ", "))")
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
