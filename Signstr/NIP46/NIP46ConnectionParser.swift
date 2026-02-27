// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  NIP46ConnectionParser.swift
//  Signstr — Parse nostrconnect:// and bunker:// URIs (NIP-46)

import Foundation

/// Parsed NIP-46 connection request.
struct NIP46ConnectionInfo: Equatable, Sendable {
    /// Which flow initiated this connection.
    enum Flow: Equatable, Sendable {
        /// Client-initiated: user scanned a nostrconnect:// URI from a client app.
        case clientInitiated
        /// Signer-initiated: Signstr generated a bunker:// URI that the client consumed.
        case signerInitiated
    }

    let flow: Flow
    /// 32-byte hex public key of the remote party (client pubkey for nostrconnect, signer pubkey for bunker).
    let pubkey: String
    /// Relay URLs for NIP-46 communication.
    let relays: [String]
    /// Optional shared secret for initial handshake verification.
    let secret: String?
    /// Human-readable name of the connecting app (e.g. "Damus").
    let name: String?
    /// Requested permissions (e.g. "sign_event:1,get_public_key").
    let permissions: String?
}

/// Parses NIP-46 connection URIs.
enum NIP46ConnectionParser {

    enum ParseError: Error, CustomStringConvertible, Equatable {
        case invalidURI
        case unsupportedScheme(String)
        case missingPubkey
        case invalidPubkey
        case missingRelay

        var description: String {
            switch self {
            case .invalidURI: return "Invalid NIP-46 connection URI"
            case .unsupportedScheme(let s): return "Unsupported URI scheme: \(s)"
            case .missingPubkey: return "Missing public key in URI"
            case .invalidPubkey: return "Invalid public key (must be 64 hex chars)"
            case .missingRelay: return "At least one relay URL is required"
            }
        }
    }

    /// Parses a `nostrconnect://` or `bunker://` URI string.
    ///
    /// nostrconnect://<client-pubkey>?relay=wss://...&secret=<random>&name=Damus&perms=sign_event
    /// bunker://<signer-pubkey>?relay=wss://...&secret=<random>
    static func parse(_ uriString: String) throws -> NIP46ConnectionInfo {
        // URLComponents doesn't understand custom schemes with `//` well.
        // Replace scheme to https for parsing, then interpret components.
        let trimmed = uriString.trimmingCharacters(in: .whitespacesAndNewlines)

        let scheme: String
        let rest: String

        if trimmed.hasPrefix("nostrconnect://") {
            scheme = "nostrconnect"
            rest = String(trimmed.dropFirst("nostrconnect://".count))
        } else if trimmed.hasPrefix("bunker://") {
            scheme = "bunker"
            rest = String(trimmed.dropFirst("bunker://".count))
        } else {
            let components = trimmed.components(separatedBy: "://")
            if components.count >= 2 {
                throw ParseError.unsupportedScheme(components[0])
            }
            throw ParseError.invalidURI
        }

        // rest = "<pubkey>?relay=wss://...&secret=abc&name=Damus"
        guard let questionIdx = rest.firstIndex(of: "?") else {
            // No query params — pubkey only, which is missing relay
            let pubkey = rest
            guard isValidHexPubkey(pubkey) else {
                throw pubkey.isEmpty ? ParseError.missingPubkey : ParseError.invalidPubkey
            }
            throw ParseError.missingRelay
        }

        let pubkey = String(rest[rest.startIndex..<questionIdx])
        let queryString = String(rest[rest.index(after: questionIdx)...])

        guard !pubkey.isEmpty else { throw ParseError.missingPubkey }
        guard isValidHexPubkey(pubkey) else { throw ParseError.invalidPubkey }

        // Parse query parameters manually (URLComponents struggles with wss:// in values)
        let params = parseQueryString(queryString)

        let relays = params.filter { $0.key == "relay" }.map { $0.value }
        guard !relays.isEmpty else { throw ParseError.missingRelay }

        let secret = params.first(where: { $0.key == "secret" })?.value
        let name = params.first(where: { $0.key == "name" })?.value
        let perms = params.first(where: { $0.key == "perms" })?.value

        let flow: NIP46ConnectionInfo.Flow = scheme == "nostrconnect" ? .clientInitiated : .signerInitiated

        return NIP46ConnectionInfo(
            flow: flow,
            pubkey: pubkey,
            relays: relays,
            secret: secret,
            name: name,
            permissions: perms
        )
    }

    // MARK: - Private

    /// Validates that a string is a 64-character lowercase hex string.
    private static func isValidHexPubkey(_ s: String) -> Bool {
        guard s.count == 64 else { return false }
        return s.allSatisfy { $0.isHexDigit }
    }

    /// Parses a query string into key-value pairs, handling multiple values for the same key
    /// and URL-encoded values (needed for wss:// relay URLs).
    private static func parseQueryString(_ query: String) -> [(key: String, value: String)] {
        var results: [(key: String, value: String)] = []

        let pairs = query.components(separatedBy: "&")
        for pair in pairs {
            guard let eqIdx = pair.firstIndex(of: "=") else { continue }
            let key = String(pair[pair.startIndex..<eqIdx])
            let rawValue = String(pair[pair.index(after: eqIdx)...])
            let value = rawValue.removingPercentEncoding ?? rawValue
            results.append((key: key, value: value))
        }

        return results
    }
}
