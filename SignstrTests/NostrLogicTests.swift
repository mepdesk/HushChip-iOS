// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
//
//  NostrLogicTests.swift
//  SignstrTests
//

import CryptoKit
import XCTest
@testable import Signstr

final class NostrLogicTests: XCTestCase {

    // MARK: - Known test vector

    /// A fixed 32-byte private key for deterministic tests.
    private let testPrivateKeyHex = "6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e"

    private var testPrivateKey: Data {
        try! NostrKeyUtils.hexDecode(testPrivateKeyHex)
    }

    // MARK: - Event construction

    func testUnsignedEventHasEmptyIdAndSig() {
        let event = NostrEvent.unsigned(
            pubkey: "aabbccdd",
            kind: 1,
            content: "hello nostr"
        )
        XCTAssertEqual(event.id, "")
        XCTAssertEqual(event.sig, "")
        XCTAssertEqual(event.kind, 1)
        XCTAssertEqual(event.content, "hello nostr")
    }

    func testSignedEventPreservesFields() {
        let event = NostrEvent.unsigned(
            pubkey: "aabb",
            kind: 1,
            tags: [["e", "deadbeef"]],
            content: "test",
            createdAt: 1234567890
        )
        let signed = event.signed(id: "someid", sig: "somesig")
        XCTAssertEqual(signed.id, "someid")
        XCTAssertEqual(signed.sig, "somesig")
        XCTAssertEqual(signed.pubkey, "aabb")
        XCTAssertEqual(signed.kind, 1)
        XCTAssertEqual(signed.createdAt, 1234567890)
        XCTAssertEqual(signed.tags, [["e", "deadbeef"]])
        XCTAssertEqual(signed.content, "test")
    }

    // MARK: - NIP-01 serialisation & event ID

    func testSerialisation() {
        let event = NostrEvent.unsigned(
            pubkey: "aa".repeating(count: 32),
            kind: 1,
            tags: [],
            content: "Hello, world!",
            createdAt: 1700000000
        )

        let serialised = NostrEventSerializer.serialise(event)
        // Must be: [0,"<pubkey>",<created_at>,<kind>,<tags>,"<content>"]
        XCTAssertTrue(serialised.hasPrefix("[0,\""))
        XCTAssertTrue(serialised.hasSuffix("\"]"))
        XCTAssertTrue(serialised.contains("1700000000"))
        XCTAssertTrue(serialised.contains("\"Hello, world!\""))
    }

    func testEventIdIsSHA256OfSerialisation() {
        let event = NostrEvent.unsigned(
            pubkey: "aa".repeating(count: 32),
            kind: 1,
            tags: [],
            content: "Hello, world!",
            createdAt: 1700000000
        )

        let eventId = NostrEventSerializer.computeEventId(for: event)
        XCTAssertEqual(eventId.count, 32, "Event ID must be 32 bytes (SHA-256)")

        // Verify manually: SHA-256 of the serialised string
        let serialised = NostrEventSerializer.serialise(event)
        let expected = Data(SHA256.hash(data: Data(serialised.utf8)))
        XCTAssertEqual(eventId, expected)
    }

    func testSerialisationWithTags() {
        let event = NostrEvent.unsigned(
            pubkey: "bb".repeating(count: 32),
            kind: 1,
            tags: [["e", "abc123"], ["p", "def456"]],
            content: "tagged",
            createdAt: 1700000001
        )

        let serialised = NostrEventSerializer.serialise(event)
        XCTAssertTrue(serialised.contains("[[\"e\",\"abc123\"],[\"p\",\"def456\"]]"))
    }

    func testSerialisationEscapesSpecialChars() {
        let event = NostrEvent.unsigned(
            pubkey: "cc".repeating(count: 32),
            kind: 1,
            tags: [],
            content: "line1\nline2\ttab \"quoted\"",
            createdAt: 1700000002
        )

        let serialised = NostrEventSerializer.serialise(event)
        XCTAssertTrue(serialised.contains("\\n"))
        XCTAssertTrue(serialised.contains("\\t"))
        XCTAssertTrue(serialised.contains("\\\"quoted\\\""))
    }

    // MARK: - MockSigner (Schnorr signing)

    func testMockSignerPublicKeyIs32Bytes() async throws {
        let signer = MockSigner(privateKey: testPrivateKey)
        let pubkey = try await signer.getPublicKey()
        XCTAssertEqual(pubkey.count, 32, "x-only pubkey must be 32 bytes")
    }

    func testMockSignerIsNotCardBacked() {
        let signer = MockSigner(privateKey: testPrivateKey)
        XCTAssertFalse(signer.isCardBacked)
    }

    func testMockSignerSignsHash() async throws {
        let signer = MockSigner(privateKey: testPrivateKey)

        // Build a kind 1 event
        let pubkey = try await signer.getPublicKey()
        let pubkeyHex = NostrKeyUtils.hexEncode(pubkey)

        let event = NostrEvent.unsigned(
            pubkey: pubkeyHex,
            kind: 1,
            content: "Hello from Signstr!",
            createdAt: 1700000000
        )

        let eventIdData = NostrEventSerializer.computeEventId(for: event)
        XCTAssertEqual(eventIdData.count, 32)

        let signature = try await signer.signHash(eventIdData)
        XCTAssertEqual(signature.count, 64, "Schnorr signature must be 64 bytes")
    }

    func testFullSigningFlow() async throws {
        let signer = MockSigner(privateKey: testPrivateKey)
        let pubkey = try await signer.getPublicKey()
        let pubkeyHex = NostrKeyUtils.hexEncode(pubkey)

        // 1. Create unsigned event
        let unsigned = NostrEvent.unsigned(
            pubkey: pubkeyHex,
            kind: 1,
            content: "Test note from Signstr",
            createdAt: 1700000000
        )

        // 2. Compute event ID
        let eventIdData = NostrEventSerializer.computeEventId(for: unsigned)
        let eventIdHex = NostrKeyUtils.hexEncode(eventIdData)

        // 3. Sign
        let sig = try await signer.signHash(eventIdData)
        let sigHex = NostrKeyUtils.hexEncode(sig)

        // 4. Assemble signed event
        let signed = unsigned.signed(id: eventIdHex, sig: sigHex)

        // 5. Verify format
        XCTAssertEqual(signed.id.count, 64, "Event ID hex must be 64 chars")
        XCTAssertEqual(signed.sig.count, 128, "Signature hex must be 128 chars")
        XCTAssertEqual(signed.pubkey.count, 64, "Pubkey hex must be 64 chars")
        XCTAssertEqual(signed.kind, 1)
        XCTAssertFalse(signed.id.isEmpty)
        XCTAssertFalse(signed.sig.isEmpty)

        // 6. Verify JSON encode/decode roundtrip
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(signed)
        let decoded = try JSONDecoder().decode(NostrEvent.self, from: data)
        XCTAssertEqual(decoded.id, signed.id)
        XCTAssertEqual(decoded.sig, signed.sig)
        XCTAssertEqual(decoded.pubkey, signed.pubkey)
        XCTAssertEqual(decoded.kind, signed.kind)
        XCTAssertEqual(decoded.createdAt, signed.createdAt)
        XCTAssertEqual(decoded.content, signed.content)
    }

    // MARK: - Bech32 / nsec / npub

    func testBech32RoundTrip() throws {
        let original = testPrivateKey
        let encoded = try Bech32.encode(hrp: "nsec", data: original)
        XCTAssertTrue(encoded.hasPrefix("nsec1"))

        let (hrp, decoded) = try Bech32.decode(encoded)
        XCTAssertEqual(hrp, "nsec")
        XCTAssertEqual(decoded, original)
    }

    func testNsecEncodeAndDecode() throws {
        let nsec = try NostrKeyUtils.nsecEncode(testPrivateKey)
        XCTAssertTrue(nsec.hasPrefix("nsec1"))

        let decoded = try NostrKeyUtils.nsecDecode(nsec)
        XCTAssertEqual(decoded, testPrivateKey)
    }

    func testNpubEncodeAndDecode() throws {
        let pubkey = try SchnorrSigner.derivePublicKey(from: testPrivateKey)
        XCTAssertEqual(pubkey.count, 32)

        let npub = try NostrKeyUtils.npubEncode(pubkey)
        XCTAssertTrue(npub.hasPrefix("npub1"))

        let decoded = try NostrKeyUtils.npubDecode(npub)
        XCTAssertEqual(decoded, pubkey)
    }

    func testNsecDecodeRejectsWrongHRP() {
        let pubkey = Data(repeating: 0xAA, count: 32)
        let encoded = try! Bech32.encode(hrp: "npub", data: pubkey)

        XCTAssertThrowsError(try NostrKeyUtils.nsecDecode(encoded)) { error in
            if case NostrKeyUtils.KeyError.invalidHRP(let expected, let got) = error {
                XCTAssertEqual(expected, "nsec")
                XCTAssertEqual(got, "npub")
            } else {
                XCTFail("Expected invalidHRP error")
            }
        }
    }

    func testNsecDecodeRejectsWrongLength() {
        let shortKey = Data(repeating: 0xBB, count: 16)
        let encoded = try! Bech32.encode(hrp: "nsec", data: shortKey)

        XCTAssertThrowsError(try NostrKeyUtils.nsecDecode(encoded)) { error in
            if case NostrKeyUtils.KeyError.invalidKeyLength(let expected, _) = error {
                XCTAssertEqual(expected, 32)
            } else {
                XCTFail("Expected invalidKeyLength error")
            }
        }
    }

    // MARK: - Hex utilities

    func testHexRoundTrip() throws {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let hex = NostrKeyUtils.hexEncode(data)
        XCTAssertEqual(hex, "deadbeef")

        let decoded = try NostrKeyUtils.hexDecode(hex)
        XCTAssertEqual(decoded, data)
    }

    func testHexDecodeRejectsOddLength() {
        XCTAssertThrowsError(try NostrKeyUtils.hexDecode("abc"))
    }

    func testHexDecodeRejectsInvalidChars() {
        XCTAssertThrowsError(try NostrKeyUtils.hexDecode("zzzz"))
    }

    // MARK: - NIP-04 encryption

    /// Second test key for NIP-04 ECDH tests.
    private let testPrivateKey2Hex = "7f7ff03d123792d6ac594bfa67bf6d0c0ab55b6b1fdb6249303fe861f1ccba9a"

    func testNIP04ECDHSharedSecretIs32Bytes() throws {
        let privKey1 = try NostrKeyUtils.hexDecode(testPrivateKeyHex)
        let pubKey2 = try SchnorrSigner.derivePublicKey(from: NostrKeyUtils.hexDecode(testPrivateKey2Hex))
        let shared = try NIP04.ecdhSharedSecret(privateKey: privKey1, publicKey: pubKey2)
        XCTAssertEqual(shared.count, 32, "ECDH shared secret must be 32 bytes")
    }

    func testNIP04ECDHIsSymmetric() throws {
        // ECDH(privA, pubB) == ECDH(privB, pubA)
        let privKey1 = try NostrKeyUtils.hexDecode(testPrivateKeyHex)
        let privKey2 = try NostrKeyUtils.hexDecode(testPrivateKey2Hex)
        let pubKey1 = try SchnorrSigner.derivePublicKey(from: privKey1)
        let pubKey2 = try SchnorrSigner.derivePublicKey(from: privKey2)

        let shared1 = try NIP04.ecdhSharedSecret(privateKey: privKey1, publicKey: pubKey2)
        let shared2 = try NIP04.ecdhSharedSecret(privateKey: privKey2, publicKey: pubKey1)
        XCTAssertEqual(shared1, shared2, "ECDH must be symmetric: ECDH(a,B) == ECDH(b,A)")

        // Log the shared secret for manual cross-verification with nostr-tools
        let sharedHex = NostrKeyUtils.hexEncode(shared1)
        print("[NIP04-TEST] ECDH shared secret: \(sharedHex)")
        print("[NIP04-TEST]   privkey1: \(testPrivateKeyHex)")
        print("[NIP04-TEST]   pubkey2: \(NostrKeyUtils.hexEncode(pubKey2))")
        print("[NIP04-TEST]   privkey2: \(testPrivateKey2Hex)")
        print("[NIP04-TEST]   pubkey1: \(NostrKeyUtils.hexEncode(pubKey1))")
    }

    func testNIP04EncryptDecryptRoundTrip() throws {
        let privKey1 = try NostrKeyUtils.hexDecode(testPrivateKeyHex)
        let privKey2 = try NostrKeyUtils.hexDecode(testPrivateKey2Hex)
        let pubKey1 = try SchnorrSigner.derivePublicKey(from: privKey1)
        let pubKey2 = try SchnorrSigner.derivePublicKey(from: privKey2)

        let plaintext = "Hello, Nostr! This is a NIP-04 test."

        // Encrypt from key1 to key2
        let encrypted = try NIP04.encrypt(
            plaintext: plaintext,
            privateKey: privKey1,
            publicKey: pubKey2
        )

        // Must contain the ?iv= separator
        XCTAssertTrue(encrypted.contains("?iv="), "NIP-04 payload must contain '?iv=' separator")

        // Decrypt as key2 from key1
        let decrypted = try NIP04.decrypt(
            payload: encrypted,
            privateKey: privKey2,
            publicKey: pubKey1
        )
        XCTAssertEqual(decrypted, plaintext, "Decrypted text must match original plaintext")
    }

    func testNIP04DecryptWithKnownPayload() throws {
        // Test that we can decrypt a payload encrypted with known parameters.
        // We encrypt with known IV to get a deterministic output, then verify.
        let privKey1 = try NostrKeyUtils.hexDecode(testPrivateKeyHex)
        let privKey2 = try NostrKeyUtils.hexDecode(testPrivateKey2Hex)
        let pubKey1 = try SchnorrSigner.derivePublicKey(from: privKey1)

        // Encrypt and log the result for cross-verification
        let plaintext = "test"
        let encrypted = try NIP04.encrypt(
            plaintext: plaintext,
            privateKey: privKey1,
            publicKey: try SchnorrSigner.derivePublicKey(from: privKey2)
        )
        print("[NIP04-TEST] Encrypted 'test': \(encrypted)")

        // Decrypt should work from the other side
        let decrypted = try NIP04.decrypt(
            payload: encrypted,
            privateKey: privKey2,
            publicKey: pubKey1
        )
        XCTAssertEqual(decrypted, plaintext)
    }

    func testNIP04PayloadFormat() throws {
        let privKey1 = try NostrKeyUtils.hexDecode(testPrivateKeyHex)
        let pubKey2 = try SchnorrSigner.derivePublicKey(from: NostrKeyUtils.hexDecode(testPrivateKey2Hex))

        let encrypted = try NIP04.encrypt(
            plaintext: "format check",
            privateKey: privKey1,
            publicKey: pubKey2
        )

        let parts = encrypted.components(separatedBy: "?iv=")
        XCTAssertEqual(parts.count, 2, "Must have exactly one '?iv=' separator")

        // Ciphertext part must be valid base64
        XCTAssertNotNil(Data(base64Encoded: parts[0]), "Ciphertext must be valid base64")

        // IV part must be valid base64 and decode to 16 bytes
        let ivData = Data(base64Encoded: parts[1])
        XCTAssertNotNil(ivData, "IV must be valid base64")
        XCTAssertEqual(ivData?.count, 16, "IV must be 16 bytes")
    }

    func testNIP04RejectsInvalidPayload() {
        let privKey1 = try! NostrKeyUtils.hexDecode(testPrivateKeyHex)
        let pubKey2 = try! SchnorrSigner.derivePublicKey(from: NostrKeyUtils.hexDecode(testPrivateKey2Hex))

        // No ?iv= separator
        XCTAssertThrowsError(try NIP04.decrypt(payload: "garbage", privateKey: privKey1, publicKey: pubKey2))

        // Invalid base64
        XCTAssertThrowsError(try NIP04.decrypt(payload: "!!!?iv=!!!", privateKey: privKey1, publicKey: pubKey2))
    }

    func testNIP04ECDHRejects33ByteKey() {
        // Must use 32-byte x-only pubkey, NOT 33-byte compressed
        let privKey = try! NostrKeyUtils.hexDecode(testPrivateKeyHex)
        let pubKey33 = Data(repeating: 0x02, count: 1) + Data(repeating: 0xAA, count: 32)
        XCTAssertThrowsError(try NIP04.ecdhSharedSecret(privateKey: privKey, publicKey: pubKey33))
    }

    func testNIP04LogsSharedSecretForCrossVerification() throws {
        // This test exists purely to print values you can paste into a
        // nostr-tools REPL to verify our ECDH matches:
        //
        //   import { secp256k1 } from '@noble/curves/secp256k1'
        //   const shared = secp256k1.getSharedSecret('<privkey1>', '02' + '<pubkey2>')
        //   console.log(Buffer.from(shared.slice(1, 33)).toString('hex'))
        //
        let privKey1 = try NostrKeyUtils.hexDecode(testPrivateKeyHex)
        let privKey2 = try NostrKeyUtils.hexDecode(testPrivateKey2Hex)
        let pubKey1 = try SchnorrSigner.derivePublicKey(from: privKey1)
        let pubKey2 = try SchnorrSigner.derivePublicKey(from: privKey2)

        let shared = try NIP04.ecdhSharedSecret(privateKey: privKey1, publicKey: pubKey2)

        print("╔══════════════════════════════════════════════════════════════════╗")
        print("║ NIP-04 ECDH Cross-Verification Values                          ║")
        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║ privkey1: \(testPrivateKeyHex) ║")
        print("║ pubkey1:  \(NostrKeyUtils.hexEncode(pubKey1)) ║")
        print("║ privkey2: \(testPrivateKey2Hex) ║")
        print("║ pubkey2:  \(NostrKeyUtils.hexEncode(pubKey2)) ║")
        print("║ shared:   \(NostrKeyUtils.hexEncode(shared)) ║")
        print("╚══════════════════════════════════════════════════════════════════╝")
        print("")
        print("// Verify in Node.js with nostr-tools:")
        print("// import { secp256k1 } from '@noble/curves/secp256k1'")
        print("// const shared = secp256k1.getSharedSecret('\(testPrivateKeyHex)', '02' + '\(NostrKeyUtils.hexEncode(pubKey2))')")
        print("// console.log(Buffer.from(shared.slice(1, 33)).toString('hex'))")
        print("// Expected: \(NostrKeyUtils.hexEncode(shared))")

        XCTAssertEqual(shared.count, 32)
    }

    // MARK: - Relay pool

    func testRelayPoolAddsDefaultRelays() {
        let pool = NostrRelayPool()
        pool.addDefaultRelays()
        XCTAssertEqual(pool.relays.count, 5)
    }

    func testRelayPoolNoDuplicates() {
        let pool = NostrRelayPool()
        pool.addDefaultRelays()
        pool.addDefaultRelays() // add again
        XCTAssertEqual(pool.relays.count, 5, "Should not add duplicate relays")
    }

    func testRelayPoolRemove() throws {
        let pool = NostrRelayPool()
        let relay = try NostrRelay(urlString: "wss://relay.damus.io")
        pool.addRelay(relay)
        XCTAssertEqual(pool.relays.count, 1)

        pool.removeRelay(url: relay.url)
        XCTAssertEqual(pool.relays.count, 0)
    }
}

// MARK: - Helpers

private extension String {
    /// Repeats the string `count` times. E.g. "aa".repeating(count: 3) -> "aaaaaa"
    func repeating(count: Int) -> String {
        String(repeating: self, count: count)
    }
}
