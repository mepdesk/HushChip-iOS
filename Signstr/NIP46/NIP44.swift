// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  NIP44.swift
//  Signstr — NIP-44 versioned encryption/decryption for NIP-46 communication

import CryptoKit
import Foundation
import P256K

/// NIP-44 v2 encryption/decryption.
///
/// Wire format (version 2):
///   `[version_byte(0x02)] [32-byte nonce] [padded_ciphertext] [32-byte MAC]`
///
/// Steps:
///   1. ECDH shared secret (secp256k1) → 32-byte x-only point
///   2. Conversation key: HKDF-extract(IKM=shared_x, salt="nip44-v2") → 32 bytes
///   3. Message keys: HKDF-expand(PRK=conversation_key, info=nonce, L=76)
///      → chacha_key (bytes 0..<32), chacha_nonce (bytes 32..<44), hmac_key (bytes 44..<76)
///   4. Encrypt plaintext (with NIP-44 padding) using ChaCha20 (raw, NOT AEAD)
///   5. HMAC-SHA256(key: hmac_key, data: nonce + padded_ciphertext)
///
/// NIP-44 uses **plain ChaCha20** (not ChaCha20-Poly1305 AEAD), plus a separate HMAC-SHA256 MAC.
enum NIP44 {

    enum NIP44Error: Error, CustomStringConvertible {
        case invalidVersion
        case invalidPayload
        case decryptionFailed
        case hmacMismatch
        case invalidPublicKey
        case ecdhFailed

        var description: String {
            switch self {
            case .invalidVersion: return "Unsupported NIP-44 version (expected 2)"
            case .invalidPayload: return "Invalid NIP-44 payload"
            case .decryptionFailed: return "NIP-44 decryption failed"
            case .hmacMismatch: return "NIP-44 HMAC verification failed"
            case .invalidPublicKey: return "Invalid public key for NIP-44"
            case .ecdhFailed: return "ECDH key agreement failed"
            }
        }
    }

    // MARK: - Conversation key

    /// Derives the NIP-44 conversation key from our private key and their public key.
    /// This is a stable per-pair key: HKDF-extract(IKM=ecdh_x, salt="nip44-v2") → 32 bytes.
    static func conversationKey(privateKey: Data, publicKey: Data) throws -> SymmetricKey {
        let sharedPoint = try ecdhSharedSecret(privateKey: privateKey, publicKey: publicKey)
        return conversationKeyFromSharedSecret(sharedPoint)
    }

    /// Derives conversation key from a raw 32-byte ECDH shared secret.
    /// Uses HKDF-extract only (NOT expand): HMAC-SHA256(key=salt, data=IKM).
    static func conversationKeyFromSharedSecret(_ sharedSecret: Data) -> SymmetricKey {
        let salt = SymmetricKey(data: Data("nip44-v2".utf8))
        let prk = HMAC<CryptoKit.SHA256>.authenticationCode(
            for: sharedSecret,
            using: salt
        )
        return SymmetricKey(data: Data(prk))
    }

    // MARK: - Encrypt

    /// Encrypts plaintext using NIP-44 v2.
    /// - Parameters:
    ///   - plaintext: UTF-8 string to encrypt
    ///   - conversationKey: 32-byte conversation key (derived via `conversationKey(privateKey:publicKey:)`)
    ///   - nonce: Optional 32-byte nonce (random if nil; injectable for testing)
    /// - Returns: Base64-encoded NIP-44 v2 payload
    static func encrypt(
        plaintext: String,
        conversationKey: SymmetricKey,
        nonce: Data? = nil
    ) throws -> String {
        let plaintextBytes = Data(plaintext.utf8)
        let padded = pad(plaintextBytes)

        let nonceBytes: Data
        if let nonce = nonce {
            guard nonce.count == 32 else { throw NIP44Error.invalidPayload }
            nonceBytes = nonce
        } else {
            var randomNonce = Data(count: 32)
            randomNonce.withUnsafeMutableBytes { ptr in
                _ = SecRandomCopyBytes(kSecRandomDefault, 32, ptr.baseAddress!)
            }
            nonceBytes = randomNonce
        }

        // Derive message keys from conversation key + nonce
        let (chachaKey, chachaNonce, hmacKey) = deriveMessageKeys(
            conversationKey: conversationKey,
            nonce: nonceBytes
        )

        // ChaCha20 encrypt (XOR-stream, counter starts at 0)
        let ciphertext = try chacha20Encrypt(data: padded, key: chachaKey, nonce: chachaNonce)

        // HMAC-SHA256 over nonce + ciphertext
        let macInput = nonceBytes + ciphertext
        let mac = hmacSHA256(key: hmacKey, data: macInput)

        // Assemble: version(1) + nonce(32) + ciphertext(variable) + mac(32)
        var payload = Data()
        payload.append(0x02) // version 2
        payload.append(nonceBytes)
        payload.append(ciphertext)
        payload.append(mac)

        return payload.base64EncodedString()
    }

    // MARK: - Decrypt

    /// Decrypts a NIP-44 v2 payload.
    /// - Parameters:
    ///   - payload: Base64-encoded NIP-44 v2 ciphertext
    ///   - conversationKey: 32-byte conversation key
    /// - Returns: Decrypted UTF-8 string
    static func decrypt(
        payload: String,
        conversationKey: SymmetricKey
    ) throws -> String {
        guard let data = Data(base64Encoded: payload) else {
            throw NIP44Error.invalidPayload
        }

        // Minimum: version(1) + nonce(32) + min_padded(32) + mac(32) = 97
        guard data.count >= 97 else { throw NIP44Error.invalidPayload }
        guard data[0] == 0x02 else { throw NIP44Error.invalidVersion }

        let nonceBytes = data[1..<33]
        let ciphertext = data[33..<(data.count - 32)]
        let receivedMac = data[(data.count - 32)...]

        // Derive message keys
        let (chachaKey, chachaNonce, hmacKey) = deriveMessageKeys(
            conversationKey: conversationKey,
            nonce: Data(nonceBytes)
        )

        // Verify HMAC first (before decryption)
        let macInput = Data(nonceBytes) + Data(ciphertext)
        let expectedMac = hmacSHA256(key: hmacKey, data: macInput)

        guard constantTimeEqual(Data(receivedMac), expectedMac) else {
            throw NIP44Error.hmacMismatch
        }

        // ChaCha20 decrypt (symmetric — same operation as encrypt)
        let padded = try chacha20Encrypt(data: Data(ciphertext), key: chachaKey, nonce: chachaNonce)

        // Unpad
        let plaintext = try unpad(padded)

        guard let result = String(data: plaintext, encoding: .utf8) else {
            throw NIP44Error.decryptionFailed
        }
        return result
    }

    // MARK: - ECDH

    /// Computes the 32-byte x-only ECDH shared point.
    static func ecdhSharedSecret(privateKey: Data, publicKey: Data) throws -> Data {
        guard privateKey.count == 32 else { throw NIP44Error.ecdhFailed }
        guard publicKey.count == 32 else { throw NIP44Error.invalidPublicKey }

        do {
            let privKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: privateKey)

            // x-only pubkey → compressed: prepend 0x02
            let compressedPub = Data([0x02]) + publicKey
            let pubKey = try P256K.KeyAgreement.PublicKey(
                dataRepresentation: compressedPub,
                format: .compressed
            )

            let shared = try privKey.sharedSecretFromKeyAgreement(with: pubKey, format: .compressed)
            // Skip parity byte, take 32-byte x-coordinate
            let bytes = shared.bytes
            guard bytes.count >= 33 else { throw NIP44Error.ecdhFailed }
            return Data(bytes[1..<33])
        } catch is NIP44Error {
            throw NIP44Error.ecdhFailed
        } catch {
            throw NIP44Error.ecdhFailed
        }
    }

    // MARK: - Key derivation

    /// Derives chacha_key (32), chacha_nonce (12), hmac_key (32) from conversation key + nonce.
    /// Uses HKDF-expand: PRK=conversation_key, info=nonce, L=76.
    private static func deriveMessageKeys(
        conversationKey: SymmetricKey,
        nonce: Data
    ) -> (chachaKey: Data, chachaNonce: Data, hmacKey: Data) {
        let expandedBytes = hkdfExpand(prk: conversationKey, info: nonce, outputByteCount: 76)
        let chachaKey = expandedBytes[0..<32]
        let chachaNonce = expandedBytes[32..<44]
        let hmacKey = expandedBytes[44..<76]

        return (Data(chachaKey), Data(chachaNonce), Data(hmacKey))
    }

    /// HKDF-expand (RFC 5869 §2.3) — expands a PRK into output keying material.
    /// T(1) = HMAC(PRK, info || 0x01)
    /// T(N) = HMAC(PRK, T(N-1) || info || N)
    /// Output = T(1) || T(2) || ... truncated to outputByteCount
    private static func hkdfExpand(prk: SymmetricKey, info: Data, outputByteCount: Int) -> Data {
        let hashLen = 32 // SHA-256 output
        let n = Int(ceil(Double(outputByteCount) / Double(hashLen)))
        var okm = Data()
        var previousT = Data()

        for i in 1...n {
            var input = previousT
            input.append(info)
            input.append(UInt8(i))
            let t = Data(HMAC<CryptoKit.SHA256>.authenticationCode(for: input, using: prk))
            okm.append(t)
            previousT = t
        }

        return Data(okm.prefix(outputByteCount))
    }

    // MARK: - ChaCha20 (raw stream cipher, not AEAD)

    /// ChaCha20 encrypt/decrypt (XOR stream cipher — same operation both ways).
    /// Uses CryptoKit's ChaChaPoly with a zero-length tag workaround:
    /// we use the raw ChaCha20 quarter-round by constructing a nonce-based XOR stream.
    private static func chacha20Encrypt(data: Data, key: Data, nonce: Data) throws -> Data {
        // CryptoKit only exposes ChaChaPoly (AEAD). To get raw ChaCha20:
        // XOR the data with the keystream. We generate the keystream by "encrypting" zeros.
        //
        // Alternative approach: encrypt zeros to get keystream, then XOR.
        // But simpler: use ChaChaPoly.seal with empty AAD, then strip the tag.
        // On decryption, reattach a dummy tag — but ChaChaPoly will reject it.
        //
        // Correct approach: implement ChaCha20 quarter-round directly.
        return chacha20XOR(data: data, key: key, nonce: nonce)
    }

    /// Pure ChaCha20 stream cipher (RFC 8439 without Poly1305).
    /// Generates keystream blocks and XORs with input.
    private static func chacha20XOR(data: Data, key: Data, nonce: Data) -> Data {
        guard key.count == 32, nonce.count == 12 else { return data }

        let keyBytes = Array(key)
        let nonceBytes = Array(nonce)
        var output = Data(count: data.count)
        let inputBytes = Array(data)

        var blockCounter: UInt32 = 0
        var offset = 0

        while offset < data.count {
            let block = chacha20Block(key: keyBytes, counter: blockCounter, nonce: nonceBytes)
            let remaining = min(64, data.count - offset)
            for i in 0..<remaining {
                output[offset + i] = inputBytes[offset + i] ^ block[i]
            }
            offset += 64
            blockCounter += 1
        }

        return output
    }

    /// Single ChaCha20 block (64 bytes of keystream).
    private static func chacha20Block(key: [UInt8], counter: UInt32, nonce: [UInt8]) -> [UInt8] {
        // Initial state: constants + key + counter + nonce
        var state: [UInt32] = Array(repeating: 0, count: 16)

        // "expand 32-byte k"
        state[0] = 0x61707865
        state[1] = 0x3320646e
        state[2] = 0x79622d32
        state[3] = 0x6b206574

        // Key (8 x UInt32, little-endian)
        for i in 0..<8 {
            state[4 + i] = UInt32(key[4 * i]) |
                (UInt32(key[4 * i + 1]) << 8) |
                (UInt32(key[4 * i + 2]) << 16) |
                (UInt32(key[4 * i + 3]) << 24)
        }

        // Counter
        state[12] = counter

        // Nonce (3 x UInt32, little-endian)
        for i in 0..<3 {
            state[13 + i] = UInt32(nonce[4 * i]) |
                (UInt32(nonce[4 * i + 1]) << 8) |
                (UInt32(nonce[4 * i + 2]) << 16) |
                (UInt32(nonce[4 * i + 3]) << 24)
        }

        var working = state

        // 20 rounds (10 double rounds)
        for _ in 0..<10 {
            // Column rounds
            quarterRound(&working, 0, 4, 8, 12)
            quarterRound(&working, 1, 5, 9, 13)
            quarterRound(&working, 2, 6, 10, 14)
            quarterRound(&working, 3, 7, 11, 15)
            // Diagonal rounds
            quarterRound(&working, 0, 5, 10, 15)
            quarterRound(&working, 1, 6, 11, 12)
            quarterRound(&working, 2, 7, 8, 13)
            quarterRound(&working, 3, 4, 9, 14)
        }

        // Add original state
        for i in 0..<16 {
            working[i] = working[i] &+ state[i]
        }

        // Serialize to bytes (little-endian)
        var result = [UInt8](repeating: 0, count: 64)
        for i in 0..<16 {
            result[4 * i] = UInt8(working[i] & 0xFF)
            result[4 * i + 1] = UInt8((working[i] >> 8) & 0xFF)
            result[4 * i + 2] = UInt8((working[i] >> 16) & 0xFF)
            result[4 * i + 3] = UInt8((working[i] >> 24) & 0xFF)
        }

        return result
    }

    private static func quarterRound(_ state: inout [UInt32], _ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        state[a] = state[a] &+ state[b]; state[d] ^= state[a]; state[d] = (state[d] << 16) | (state[d] >> 16)
        state[c] = state[c] &+ state[d]; state[b] ^= state[c]; state[b] = (state[b] << 12) | (state[b] >> 20)
        state[a] = state[a] &+ state[b]; state[d] ^= state[a]; state[d] = (state[d] << 8) | (state[d] >> 24)
        state[c] = state[c] &+ state[d]; state[b] ^= state[c]; state[b] = (state[b] << 7) | (state[b] >> 25)
    }

    // MARK: - HMAC-SHA256

    private static func hmacSHA256(key: Data, data: Data) -> Data {
        let hmac = HMAC<CryptoKit.SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key))
        return Data(hmac)
    }

    // MARK: - NIP-44 padding

    /// NIP-44 padding: 2-byte big-endian length prefix + plaintext + zero-padding to next power of 2 (min 32).
    static func pad(_ plaintext: Data) -> Data {
        let length = plaintext.count
        let paddedLen = calcPaddedLength(length)
        var result = Data(count: 2 + paddedLen)
        // 2-byte big-endian length
        result[0] = UInt8((length >> 8) & 0xFF)
        result[1] = UInt8(length & 0xFF)
        // Copy plaintext
        result.replaceSubrange(2..<(2 + length), with: plaintext)
        // Remaining bytes are already zero
        return result
    }

    /// NIP-44 unpadding: read 2-byte length prefix, extract plaintext.
    static func unpad(_ padded: Data) throws -> Data {
        guard padded.count >= 2 else { throw NIP44Error.decryptionFailed }
        let length = (Int(padded[padded.startIndex]) << 8) | Int(padded[padded.startIndex + 1])
        guard length > 0, 2 + length <= padded.count else { throw NIP44Error.decryptionFailed }
        return padded[(padded.startIndex + 2)..<(padded.startIndex + 2 + length)]
    }

    /// Calculates padded content length per NIP-44 spec.
    /// Result is next power of 2 with minimum 32, using the chunk-based formula.
    static func calcPaddedLength(_ unpaddedLen: Int) -> Int {
        guard unpaddedLen > 0 else { return 32 }
        if unpaddedLen <= 32 { return 32 }

        let nextPower = 1 << (Int(ceil(log2(Double(unpaddedLen)))))
        let chunk = max(32, nextPower / 8)

        // Round up to next chunk boundary
        return ((unpaddedLen + chunk - 1) / chunk) * chunk
    }

    // MARK: - Test helpers

    /// Exposes message key derivation for unit testing against spec vectors.
    static func testDeriveMessageKeys(
        conversationKey: SymmetricKey,
        nonce: Data
    ) -> (chachaKey: Data, chachaNonce: Data, hmacKey: Data) {
        deriveMessageKeys(conversationKey: conversationKey, nonce: nonce)
    }

    // MARK: - Constant-time comparison

    private static func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count {
            diff |= a[a.startIndex + i] ^ b[b.startIndex + i]
        }
        return diff == 0
    }
}
