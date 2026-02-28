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

    /// Custom decoding to handle clients that send non-string params (numbers, objects, etc.).
    /// Coerces each param to its JSON string representation.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        method = try container.decode(String.self, forKey: .method)

        // Try decoding as [String] first (fast path)
        if let stringParams = try? container.decode([String].self, forKey: .params) {
            params = stringParams
        } else {
            // Fallback: decode as [AnyCodable] and coerce to strings
            let anyParams = try container.decode([AnyCodableParam].self, forKey: .params)
            params = anyParams.map { $0.stringValue }
        }
    }

    init(id: String, method: String, params: [String]) {
        self.id = id
        self.method = method
        self.params = params
    }
}

/// Wrapper for decoding heterogeneous JSON array elements into string representations.
private struct AnyCodableParam: Decodable {
    let stringValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            stringValue = s
        } else if let i = try? container.decode(Int.self) {
            stringValue = String(i)
        } else if let d = try? container.decode(Double.self) {
            stringValue = String(d)
        } else if let b = try? container.decode(Bool.self) {
            stringValue = String(b)
        } else {
            // For objects/arrays, re-encode as JSON string
            let rawValue = try container.decode(RawJSON.self)
            stringValue = rawValue.jsonString
        }
    }
}

/// Captures any JSON value and re-serializes it as a string.
private struct RawJSON: Decodable {
    let jsonString: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Decode as a generic dictionary or array, then re-serialize
        if let dict = try? container.decode([String: AnyCodableValue].self),
           let data = try? JSONSerialization.data(withJSONObject: dict.mapValues { $0.value }),
           let s = String(data: data, encoding: .utf8) {
            jsonString = s
        } else if let arr = try? container.decode([AnyCodableValue].self),
                  let data = try? JSONSerialization.data(withJSONObject: arr.map { $0.value }),
                  let s = String(data: data, encoding: .utf8) {
            jsonString = s
        } else {
            jsonString = ""
        }
    }
}

/// Wrapper that captures any JSON value as Foundation types for re-serialization.
private struct AnyCodableValue: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { value = s }
        else if let i = try? container.decode(Int.self) { value = i }
        else if let d = try? container.decode(Double.self) { value = d }
        else if let b = try? container.decode(Bool.self) { value = b }
        else if container.decodeNil() { value = NSNull() }
        else { value = "" }
    }
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
    /// params[0] is the unsigned event JSON string. Clients send events WITHOUT id/sig
    /// fields, so we parse with JSONSerialization (not Codable) to handle missing fields.
    /// We:
    /// 1. Parse the unsigned event dict
    /// 2. Fill in the pubkey from the signer
    /// 3. Compute the event ID (NIP-01 SHA-256 of [0, pubkey, created_at, kind, tags, content])
    /// 4. Sign the hash via the signer
    /// 5. Return the fully signed event as JSON
    private static func handleSignEvent(
        _ request: NIP46Request,
        signer: NostrSigner
    ) async -> NIP46Response {
        guard let eventJSON = request.params.first else {
            return .error(id: request.id, message: "sign_event requires an event JSON parameter")
        }

        guard let eventData = eventJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any] else {
            return .error(id: request.id, message: "Invalid event JSON")
        }

        do {
            // Extract fields — id and sig are optional (clients send unsigned events)
            // NSJSONSerialization may return NSNumber; handle both Int and Double
            guard let kind = (dict["kind"] as? Int) ?? (dict["kind"] as? Double).map({ Int($0) }) else {
                return .error(id: request.id, message: "sign_event: missing 'kind'")
            }
            let content = dict["content"] as? String ?? ""
            let tags = dict["tags"] as? [[String]] ?? (dict["tags"] as? [[Any]])?.map { $0.map { "\($0)" } } ?? []
            let createdAt = dict["created_at"] as? Int ?? Int(Date().timeIntervalSince1970)

            // Get public key from signer
            let pubkeyData = try await signer.getPublicKey()
            let pubkeyHex = NostrKeyUtils.hexEncode(pubkeyData)

            // Build the unsigned event with correct pubkey
            let unsigned = NostrEvent.unsigned(
                pubkey: pubkeyHex,
                kind: kind,
                tags: tags,
                content: content,
                createdAt: createdAt
            )

            // Compute event ID (NIP-01: SHA-256 of serialized [0, pubkey, created_at, kind, tags, content])
            let eventIdData = NostrEventSerializer.computeEventId(for: unsigned)
            let eventIdHex = NostrKeyUtils.hexEncode(eventIdData)

            // Sign
            let sigData = try await signer.signHash(eventIdData)
            let sigHex = NostrKeyUtils.hexEncode(sigData)

            // Assemble signed event
            let signed = unsigned.signed(id: eventIdHex, sig: sigHex)

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

    /// Signs an event directly using SchnorrSigner, bypassing the biometric-gated NostrSigner.
    /// Used for auto-approved safe-kind events where the private key is already in memory.
    static func handleSignEventDirect(
        _ request: NIP46Request,
        signerPubkeyHex: String,
        signerPrivateKey: Data
    ) -> NIP46Response {
        guard let eventJSON = request.params.first else {
            return .error(id: request.id, message: "sign_event requires an event JSON parameter")
        }

        guard let eventData = eventJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any] else {
            return .error(id: request.id, message: "Invalid event JSON")
        }

        do {
            guard let kind = (dict["kind"] as? Int) ?? (dict["kind"] as? Double).map({ Int($0) }) else {
                return .error(id: request.id, message: "sign_event: missing 'kind'")
            }
            let content = dict["content"] as? String ?? ""
            let tags = dict["tags"] as? [[String]] ?? (dict["tags"] as? [[Any]])?.map { $0.map { "\($0)" } } ?? []
            let createdAt = dict["created_at"] as? Int ?? Int(Date().timeIntervalSince1970)

            let unsigned = NostrEvent.unsigned(
                pubkey: signerPubkeyHex,
                kind: kind,
                tags: tags,
                content: content,
                createdAt: createdAt
            )

            let eventIdData = NostrEventSerializer.computeEventId(for: unsigned)
            let eventIdHex = NostrKeyUtils.hexEncode(eventIdData)

            let sigData = try SchnorrSigner.sign(hash: eventIdData, privateKey: signerPrivateKey)
            let sigHex = NostrKeyUtils.hexEncode(sigData)

            let signed = unsigned.signed(id: eventIdHex, sig: sigHex)

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
