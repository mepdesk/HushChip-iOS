// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// Licensed under GPL-3.0
//
//  NIP04.swift
//  Signstr — NIP-04 encryption/decryption (legacy, used by many NIP-46 clients)

import CommonCrypto
import Foundation
import P256K

/// NIP-04 encrypted direct messages (legacy encryption).
///
/// Many NIP-46 clients (including Primal) still use NIP-04 for kind 24133 communication
/// despite the spec recommending NIP-44. NIP-04 uses:
///   1. ECDH shared secret (secp256k1, raw x-coordinate — no HKDF)
///   2. AES-256-CBC encryption with random 16-byte IV
///   3. Wire format: `base64(ciphertext)?iv=base64(iv)`
enum NIP04 {

    enum NIP04Error: Error, CustomStringConvertible {
        case invalidPayload
        case encryptionFailed
        case decryptionFailed
        case ecdhFailed

        var description: String {
            switch self {
            case .invalidPayload: return "Invalid NIP-04 payload"
            case .encryptionFailed: return "NIP-04 AES-256-CBC encryption failed"
            case .decryptionFailed: return "NIP-04 AES-256-CBC decryption failed"
            case .ecdhFailed: return "NIP-04 ECDH key agreement failed"
            }
        }
    }

    // MARK: - Encrypt

    /// Encrypts plaintext using NIP-04 (AES-256-CBC with ECDH shared secret).
    /// - Parameters:
    ///   - plaintext: UTF-8 string to encrypt
    ///   - privateKey: 32-byte sender private key
    ///   - publicKey: 32-byte x-only receiver public key
    /// - Returns: NIP-04 formatted string: `base64(ciphertext)?iv=base64(iv)`
    static func encrypt(
        plaintext: String,
        privateKey: Data,
        publicKey: Data
    ) throws -> String {
        let sharedSecret = try ecdhSharedSecret(privateKey: privateKey, publicKey: publicKey)
        let plaintextData = Data(plaintext.utf8)

        // Generate random 16-byte IV
        var iv = Data(count: 16)
        iv.withUnsafeMutableBytes { ptr in
            _ = SecRandomCopyBytes(kSecRandomDefault, 16, ptr.baseAddress!)
        }

        // AES-256-CBC encrypt with PKCS7 padding
        let ciphertext = try aes256CBCEncrypt(data: plaintextData, key: sharedSecret, iv: iv)

        // Format: base64(ciphertext)?iv=base64(iv)
        let ctBase64 = ciphertext.base64EncodedString()
        let ivBase64 = iv.base64EncodedString()
        return "\(ctBase64)?iv=\(ivBase64)"
    }

    // MARK: - Decrypt

    /// Decrypts a NIP-04 payload.
    /// - Parameters:
    ///   - payload: NIP-04 formatted string: `base64(ciphertext)?iv=base64(iv)`
    ///   - privateKey: 32-byte receiver private key
    ///   - publicKey: 32-byte x-only sender public key
    /// - Returns: Decrypted UTF-8 string
    static func decrypt(
        payload: String,
        privateKey: Data,
        publicKey: Data
    ) throws -> String {
        let sharedSecret = try ecdhSharedSecret(privateKey: privateKey, publicKey: publicKey)

        // Parse: base64(ciphertext)?iv=base64(iv)
        let parts = payload.components(separatedBy: "?iv=")
        guard parts.count == 2,
              let ciphertext = Data(base64Encoded: parts[0]),
              let iv = Data(base64Encoded: parts[1]),
              iv.count == 16 else {
            throw NIP04Error.invalidPayload
        }

        let plaintext = try aes256CBCDecrypt(data: ciphertext, key: sharedSecret, iv: iv)

        guard let result = String(data: plaintext, encoding: .utf8) else {
            throw NIP04Error.decryptionFailed
        }
        return result
    }

    // MARK: - ECDH

    /// Computes the raw 32-byte x-only ECDH shared secret (no HKDF, unlike NIP-44).
    private static func ecdhSharedSecret(privateKey: Data, publicKey: Data) throws -> Data {
        // Reuse NIP-44's ECDH which returns the raw x-coordinate
        do {
            return try NIP44.ecdhSharedSecret(privateKey: privateKey, publicKey: publicKey)
        } catch {
            throw NIP04Error.ecdhFailed
        }
    }

    // MARK: - AES-256-CBC

    /// AES-256-CBC encrypt with PKCS7 padding.
    private static func aes256CBCEncrypt(data: Data, key: Data, iv: Data) throws -> Data {
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesEncrypted: size_t = 0

        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, data.count,
                            bufferPtr.baseAddress, bufferSize,
                            &numBytesEncrypted
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { throw NIP04Error.encryptionFailed }
        return buffer.prefix(numBytesEncrypted)
    }

    /// AES-256-CBC decrypt with PKCS7 padding removal.
    private static func aes256CBCDecrypt(data: Data, key: Data, iv: Data) throws -> Data {
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesDecrypted: size_t = 0

        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, data.count,
                            bufferPtr.baseAddress, bufferSize,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { throw NIP04Error.decryptionFailed }
        return buffer.prefix(numBytesDecrypted)
    }
}
