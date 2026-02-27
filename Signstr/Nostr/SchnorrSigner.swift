// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  SchnorrSigner.swift
//  Signstr
//

import Foundation
import P256K

/// Performs BIP-340 Schnorr signing using the swift-secp256k1 library.
/// This is the cryptographic primitive; callers provide the raw private key.
enum SchnorrSigner {
    enum SigningError: Error {
        case invalidPrivateKey
        case invalidHash
        case signingFailed
        case invalidPublicKey
    }

    /// Derives the 32-byte x-only public key from a 32-byte private key.
    static func derivePublicKey(from privateKey: Data) throws -> Data {
        guard privateKey.count == 32 else {
            throw SigningError.invalidPrivateKey
        }
        let key = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKey)
        return Data(key.xonly.bytes)
    }

    /// Signs a 32-byte hash with BIP-340 Schnorr and returns a 64-byte signature.
    static func sign(hash: Data, privateKey: Data) throws -> Data {
        guard hash.count == 32 else {
            throw SigningError.invalidHash
        }
        guard privateKey.count == 32 else {
            throw SigningError.invalidPrivateKey
        }
        let key = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKey)
        var messageBytes = Array(hash)
        let signature = try key.signature(message: &messageBytes, auxiliaryRand: nil, strict: true)
        return signature.dataRepresentation
    }

    /// Verifies a BIP-340 Schnorr signature against a 32-byte hash and x-only public key.
    static func verify(signature: Data, hash: Data, publicKey: Data) throws -> Bool {
        guard signature.count == 64 else { return false }
        guard hash.count == 32 else { throw SigningError.invalidHash }
        guard publicKey.count == 32 else { throw SigningError.invalidPublicKey }

        let xonly = try P256K.Schnorr.XonlyKey(dataRepresentation: publicKey)
        let schnorrSig = try P256K.Schnorr.SchnorrSignature(dataRepresentation: signature)
        var messageBytes = Array(hash)
        return xonly.isValid(schnorrSig, for: &messageBytes)
    }
}
