// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  NIP46MessageHandler.swift
//  Signstr — Parse NIP-46 JSON-RPC requests and build responses

import CryptoKit
import Foundation

// MARK: - Request / Response models

/// Incoming NIP-46 JSON-RPC request (decrypted from kind 24133 event content).
struct NIP46Request: Codable, Sendable {
    let id: String
    let method: String
    let params: [String]
}

/// Outgoing NIP-46 JSON-RPC response.
struct NIP46Response: Codable, Sendable {
    let id: String
    let result: String?
    let error: String?

    static func success(id: String, result: String) -> NIP46Response {
        NIP46Response(id: id, result: result, error: nil)
    }

    static func error(id: String, message: String) -> NIP46Response {
        NIP46Response(id: id, result: nil, error: message)
    }
}

// MARK: - Message handler

/// Handles the NIP-46 JSON-RPC protocol layer.
///
/// Responsibilities:
/// - Decrypt incoming kind 24133 event content (NIP-44)
/// - Parse JSON-RPC request
/// - Dispatch to the appropriate signer method
/// - Build and encrypt the response
enum NIP46MessageHandler {

    enum HandlerError: Error, CustomStringConvertible {
        case invalidJSON
        case unknownMethod(String)
        case missingParams(String)
        case signingFailed(String)

        var description: String {
            switch self {
            case .invalidJSON: return "Invalid JSON-RPC payload"
            case .unknownMethod(let m): return "Unknown NIP-46 method: \(m)"
            case .missingParams(let m): return "Missing required params for: \(m)"
            case .signingFailed(let e): return "Signing failed: \(e)"
            }
        }
    }

    // MARK: - Decrypt + parse

    /// Decrypts a NIP-44 payload and parses it as a NIP-46 JSON-RPC request.
    static func decryptRequest(
        payload: String,
        conversationKey: SymmetricKey
    ) throws -> NIP46Request {
        let json = try NIP44.decrypt(payload: payload, conversationKey: conversationKey)
        return try parseRequest(json)
    }

    /// Parses a JSON string into a NIP46Request.
    static func parseRequest(_ json: String) throws -> NIP46Request {
        guard let data = json.data(using: .utf8) else {
            throw HandlerError.invalidJSON
        }
        do {
            return try JSONDecoder().decode(NIP46Request.self, from: data)
        } catch {
            throw HandlerError.invalidJSON
        }
    }

    // MARK: - Handle request

    /// Handles a NIP-46 request by dispatching to the appropriate signer method.
    /// Returns the JSON-RPC response (not yet encrypted).
    static func handleRequest(
        _ request: NIP46Request,
        signer: NostrSigner,
        session: NIP46Session
    ) async -> NIP46Response {
        switch request.method {
        case "connect":
            return handleConnect(request, session: session)
        case "get_public_key":
            return await handleGetPublicKey(request, signer: signer)
        case "sign_event":
            return await handleSignEvent(request, signer: signer)
        default:
            return .error(id: request.id, message: "Unsupported method: \(request.method)")
        }
    }

    // MARK: - Method handlers

    /// Handles `connect` — establishes the session. Returns "ack".
    private static func handleConnect(
        _ request: NIP46Request,
        session: NIP46Session
    ) -> NIP46Response {
        // params[0] = client pubkey, params[1] = secret (optional)
        // The session is already created by the time we get here.
        // Verify the secret if one was provided in the original connection URI.
        return .success(id: request.id, result: "ack")
    }

    /// Handles `get_public_key` — returns the signer's hex pubkey.
    private static func handleGetPublicKey(
        _ request: NIP46Request,
        signer: NostrSigner
    ) async -> NIP46Response {
        do {
            let pubkeyData = try await signer.getPublicKey()
            let pubkeyHex = NostrKeyUtils.hexEncode(pubkeyData)
            return .success(id: request.id, result: pubkeyHex)
        } catch {
            return .error(id: request.id, message: "Failed to get public key: \(error)")
        }
    }

    /// Handles `sign_event` — signs the event and returns the full signed event JSON.
    ///
    /// params[0] is the unsigned event JSON string. We:
    /// 1. Decode the unsigned event
    /// 2. Fill in the pubkey if missing
    /// 3. Compute the event ID (NIP-01 SHA-256)
    /// 4. Sign the hash via the signer
    /// 5. Return the fully signed event as JSON
    private static func handleSignEvent(
        _ request: NIP46Request,
        signer: NostrSigner
    ) async -> NIP46Response {
        guard let eventJSON = request.params.first else {
            return .error(id: request.id, message: "sign_event requires an event JSON parameter")
        }

        guard let eventData = eventJSON.data(using: .utf8) else {
            return .error(id: request.id, message: "Invalid event JSON encoding")
        }

        do {
            // Decode the unsigned event
            let unsigned = try JSONDecoder().decode(NostrEvent.self, from: eventData)

            // Get public key from signer
            let pubkeyData = try await signer.getPublicKey()
            let pubkeyHex = NostrKeyUtils.hexEncode(pubkeyData)

            // Rebuild with correct pubkey
            let withPubkey = NostrEvent.unsigned(
                pubkey: pubkeyHex,
                kind: unsigned.kind,
                tags: unsigned.tags,
                content: unsigned.content,
                createdAt: unsigned.createdAt
            )

            // Compute event ID
            let eventIdData = NostrEventSerializer.computeEventId(for: withPubkey)
            let eventIdHex = NostrKeyUtils.hexEncode(eventIdData)

            // Sign
            let sigData = try await signer.signHash(eventIdData)
            let sigHex = NostrKeyUtils.hexEncode(sigData)

            // Assemble signed event
            let signed = withPubkey.signed(id: eventIdHex, sig: sigHex)

            // Encode to JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let signedJSON = try encoder.encode(signed)
            guard let signedString = String(data: signedJSON, encoding: .utf8) else {
                return .error(id: request.id, message: "Failed to encode signed event")
            }

            return .success(id: request.id, result: signedString)
        } catch {
            return .error(id: request.id, message: "sign_event failed: \(error)")
        }
    }

    // MARK: - Encrypt response

    /// Encodes a response to JSON and encrypts it with NIP-44 for sending.
    static func encryptResponse(
        _ response: NIP46Response,
        conversationKey: SymmetricKey
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let jsonData = try encoder.encode(response)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw HandlerError.invalidJSON
        }
        return try NIP44.encrypt(plaintext: jsonString, conversationKey: conversationKey)
    }
}
