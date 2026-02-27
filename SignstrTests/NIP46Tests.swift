// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
//
//  NIP46Tests.swift
//  SignstrTests — Tests for NIP-44 encryption, NIP-46 URI parsing,
//  message handling, and simulated sign_event round-trip.

import CryptoKit
import XCTest
@testable import Signstr

final class NIP46Tests: XCTestCase {

    // MARK: - Test keys

    /// Alice (signer / Signstr user)
    private let alicePrivKeyHex = "6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e"

    /// Bob (client app, e.g. Damus)
    private let bobPrivKeyHex = "7a8e4b9f2c1d3e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f"

    private var alicePrivKey: Data { try! NostrKeyUtils.hexDecode(alicePrivKeyHex) }
    private var bobPrivKey: Data { try! NostrKeyUtils.hexDecode(bobPrivKeyHex) }
    private var alicePubKey: Data { try! SchnorrSigner.derivePublicKey(from: alicePrivKey) }
    private var bobPubKey: Data { try! SchnorrSigner.derivePublicKey(from: bobPrivKey) }

    // MARK: - NIP-44 Encryption

    func testNIP44EncryptDecryptRoundTrip() throws {
        let convKey = try NIP44.conversationKey(
            privateKey: alicePrivKey,
            publicKey: bobPubKey
        )
        let plaintext = "Hello from Signstr!"
        let encrypted = try NIP44.encrypt(plaintext: plaintext, conversationKey: convKey)

        // Encrypted output should be base64
        XCTAssertNotNil(Data(base64Encoded: encrypted))
        XCTAssertNotEqual(encrypted, plaintext)

        let decrypted = try NIP44.decrypt(payload: encrypted, conversationKey: convKey)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testNIP44ConversationKeyIsSymmetric() throws {
        // Alice → Bob conversation key should equal Bob → Alice conversation key
        let aliceToBob = try NIP44.conversationKey(
            privateKey: alicePrivKey,
            publicKey: bobPubKey
        )
        let bobToAlice = try NIP44.conversationKey(
            privateKey: bobPrivKey,
            publicKey: alicePubKey
        )

        // Extract raw bytes to compare
        let aliceToBobBytes = aliceToBob.withUnsafeBytes { Data($0) }
        let bobToAliceBytes = bobToAlice.withUnsafeBytes { Data($0) }
        XCTAssertEqual(aliceToBobBytes, bobToAliceBytes)
    }

    func testNIP44CrossEncryptDecrypt() throws {
        // Alice encrypts, Bob decrypts (using their shared conversation key)
        let convKey = try NIP44.conversationKey(
            privateKey: alicePrivKey,
            publicKey: bobPubKey
        )

        let message = "sign_event request from Damus"
        let encrypted = try NIP44.encrypt(plaintext: message, conversationKey: convKey)

        // Bob derives the same conversation key and decrypts
        let bobConvKey = try NIP44.conversationKey(
            privateKey: bobPrivKey,
            publicKey: alicePubKey
        )
        let decrypted = try NIP44.decrypt(payload: encrypted, conversationKey: bobConvKey)
        XCTAssertEqual(decrypted, message)
    }

    func testNIP44RejectsInvalidVersion() throws {
        let convKey = try NIP44.conversationKey(
            privateKey: alicePrivKey,
            publicKey: bobPubKey
        )

        // Version 1 payload (change first byte)
        let encrypted = try NIP44.encrypt(plaintext: "test", conversationKey: convKey)
        guard var payload = Data(base64Encoded: encrypted) else {
            XCTFail("Invalid base64")
            return
        }
        payload[0] = 0x01 // Wrong version
        let tampered = payload.base64EncodedString()

        XCTAssertThrowsError(try NIP44.decrypt(payload: tampered, conversationKey: convKey)) { error in
            XCTAssertTrue(error is NIP44.NIP44Error)
        }
    }

    func testNIP44RejectsTamperedMAC() throws {
        let convKey = try NIP44.conversationKey(
            privateKey: alicePrivKey,
            publicKey: bobPubKey
        )

        let encrypted = try NIP44.encrypt(plaintext: "test message", conversationKey: convKey)
        guard var payload = Data(base64Encoded: encrypted) else {
            XCTFail("Invalid base64")
            return
        }

        // Flip a bit in the MAC (last 32 bytes)
        payload[payload.count - 1] ^= 0xFF
        let tampered = payload.base64EncodedString()

        XCTAssertThrowsError(try NIP44.decrypt(payload: tampered, conversationKey: convKey)) { error in
            if let nip44Error = error as? NIP44.NIP44Error {
                XCTAssertEqual(nip44Error, .hmacMismatch)
            } else {
                XCTFail("Expected NIP44Error.hmacMismatch")
            }
        }
    }

    func testNIP44DeterministicWithFixedNonce() throws {
        let convKey = try NIP44.conversationKey(
            privateKey: alicePrivKey,
            publicKey: bobPubKey
        )
        let nonce = Data(repeating: 0xAA, count: 32)

        let encrypted1 = try NIP44.encrypt(plaintext: "hello", conversationKey: convKey, nonce: nonce)
        let encrypted2 = try NIP44.encrypt(plaintext: "hello", conversationKey: convKey, nonce: nonce)

        // Same nonce + same plaintext = same ciphertext
        XCTAssertEqual(encrypted1, encrypted2)
    }

    func testNIP44Padding() {
        // Empty-ish cases
        XCTAssertEqual(NIP44.calcPaddedLength(1), 32)
        XCTAssertEqual(NIP44.calcPaddedLength(32), 32)
        XCTAssertEqual(NIP44.calcPaddedLength(33), 64)
        XCTAssertEqual(NIP44.calcPaddedLength(64), 64)

        // Pad and unpad round-trip
        let data = Data("Hello, Nostr!".utf8)
        let padded = NIP44.pad(data)
        XCTAssertTrue(padded.count >= 34) // 2 byte length + at least 32 padded content
        let unpadded = try! NIP44.unpad(padded)
        XCTAssertEqual(unpadded, data)
    }

    // MARK: - NIP-44 Spec Test Vectors

    /// Verify conversation key derivation against the official NIP-44 test vectors.
    /// These use HKDF-extract only: HMAC-SHA256(key="nip44-v2", data=ecdh_shared_x).
    func testNIP44ConversationKeySpecVectors() throws {
        // Vector 1 from nip44.vectors.json v2.valid.get_conversation_key
        let sec1_1 = try NostrKeyUtils.hexDecode("315e59ff51cb9209768cf7da80791ddcaae56ac9775eb25b6dee1234bc5d2268")
        let pub2_1 = try NostrKeyUtils.hexDecode("c2f9d9948dc8c7c38321e4b85c8558872eafa0641cd269db76848a6073e69133")
        let expected1 = "3dfef0ce2a4d80a25e7a328accf73448ef67096f65f79588e358d9a0eb9013f1"

        let ck1 = try NIP44.conversationKey(privateKey: sec1_1, publicKey: pub2_1)
        let ck1Hex = ck1.withUnsafeBytes { Data($0).map { String(format: "%02x", $0) }.joined() }
        XCTAssertEqual(ck1Hex, expected1, "Conversation key vector 1 mismatch")

        // Vector 2
        let sec1_2 = try NostrKeyUtils.hexDecode("a1e37752c9fdc1273be53f68c5f74be7c8905728e8de75800b94262f9497c86e")
        let pub2_2 = try NostrKeyUtils.hexDecode("03bb7947065dde12ba991ea045132581d0954f042c84e06d8c00066e23c1a800")
        let expected2 = "4d14f36e81b8452128da64fe6f1eae873baae2f444b02c950b90e43553f2178b"

        let ck2 = try NIP44.conversationKey(privateKey: sec1_2, publicKey: pub2_2)
        let ck2Hex = ck2.withUnsafeBytes { Data($0).map { String(format: "%02x", $0) }.joined() }
        XCTAssertEqual(ck2Hex, expected2, "Conversation key vector 2 mismatch")

        // Vector 3
        let sec1_3 = try NostrKeyUtils.hexDecode("98a5902fd67518a0c900f0fb62158f278f94a21d6f9d33d30cd3091195500311")
        let pub2_3 = try NostrKeyUtils.hexDecode("aae65c15f98e5e677b5050de82e3aba47a6fe49b3dab7863cf35d9478ba9f7d1")
        let expected3 = "9c00b769d5f54d02bf175b7284a1cbd28b6911b06cda6666b2243561ac96bad7"

        let ck3 = try NIP44.conversationKey(privateKey: sec1_3, publicKey: pub2_3)
        let ck3Hex = ck3.withUnsafeBytes { Data($0).map { String(format: "%02x", $0) }.joined() }
        XCTAssertEqual(ck3Hex, expected3, "Conversation key vector 3 mismatch")
    }

    /// Verify message key derivation against the official NIP-44 test vectors.
    /// Uses HKDF-expand: PRK=conversation_key, info=nonce, L=76.
    func testNIP44MessageKeySpecVectors() throws {
        let convKeyHex = "a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54"
        let convKeyData = try NostrKeyUtils.hexDecode(convKeyHex)
        let convKey = SymmetricKey(data: convKeyData)

        // Vector 1
        let nonce1 = try NostrKeyUtils.hexDecode("e1e6f880560d6d149ed83dcc7e5861ee62a5ee051f7fde9975fe5d25d2a02d72")
        let expectedChachaKey1 = "f145f3bed47cb70dbeaac07f3a3fe683e822b3715edb7c4fe310829014ce7d76"
        let expectedChachaNonce1 = "c4ad129bb01180c0933a160c"
        let expectedHmacKey1 = "027c1db445f05e2eee864a0975b0ddef5b7110583c8c192de3732571ca5838c4"

        let (ck1, cn1, hk1) = NIP44.testDeriveMessageKeys(conversationKey: convKey, nonce: nonce1)
        XCTAssertEqual(ck1.map { String(format: "%02x", $0) }.joined(), expectedChachaKey1, "ChaCha key vector 1")
        XCTAssertEqual(cn1.map { String(format: "%02x", $0) }.joined(), expectedChachaNonce1, "ChaCha nonce vector 1")
        XCTAssertEqual(hk1.map { String(format: "%02x", $0) }.joined(), expectedHmacKey1, "HMAC key vector 1")

        // Vector 2
        let nonce2 = try NostrKeyUtils.hexDecode("e1d6d28c46de60168b43d79dacc519698512ec35e8ccb12640fc8e9f26121101")
        let expectedChachaKey2 = "e35b88f8d4a8f1606c5082f7a64b100e5d85fcdb2e62aeafbec03fb9e860ad92"
        let expectedChachaNonce2 = "22925e920cee4a50a478be90"
        let expectedHmacKey2 = "46a7c55d4283cb0df1d5e29540be67abfe709e3b2e14b7bf9976e6df994ded30"

        let (ck2, cn2, hk2) = NIP44.testDeriveMessageKeys(conversationKey: convKey, nonce: nonce2)
        XCTAssertEqual(ck2.map { String(format: "%02x", $0) }.joined(), expectedChachaKey2, "ChaCha key vector 2")
        XCTAssertEqual(cn2.map { String(format: "%02x", $0) }.joined(), expectedChachaNonce2, "ChaCha nonce vector 2")
        XCTAssertEqual(hk2.map { String(format: "%02x", $0) }.joined(), expectedHmacKey2, "HMAC key vector 2")
    }

    /// Verify full encrypt/decrypt against the official NIP-44 test vectors.
    /// Uses sec1=0x01, sec2=0x02 with known nonce, verifies exact payload.
    func testNIP44EncryptDecryptSpecVectors() throws {
        // sec1 = 1, sec2 = 2 → known conversation key
        let sec1 = try NostrKeyUtils.hexDecode("0000000000000000000000000000000000000000000000000000000000000001")
        let sec2 = try NostrKeyUtils.hexDecode("0000000000000000000000000000000000000000000000000000000000000002")
        let pub2 = try SchnorrSigner.derivePublicKey(from: sec2)

        let convKey = try NIP44.conversationKey(privateKey: sec1, publicKey: pub2)
        let convKeyHex = convKey.withUnsafeBytes { Data($0).map { String(format: "%02x", $0) }.joined() }
        XCTAssertEqual(convKeyHex, "c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d",
                       "Conversation key for sec1=1, sec2=2")

        // Encrypt with known nonce and verify exact payload
        let nonce = try NostrKeyUtils.hexDecode("0000000000000000000000000000000000000000000000000000000000000001")
        let plaintext = "a"
        let expectedPayload = "AgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABee0G5VSK0/9YypIObAtDKfYEAjD35uVkHyB0F4DwrcNaCXlCWZKaArsGrY6M9wnuTMxWfp1RTN9Xga8no+kF5Vsb"

        let encrypted = try NIP44.encrypt(plaintext: plaintext, conversationKey: convKey, nonce: nonce)
        XCTAssertEqual(encrypted, expectedPayload, "Encrypted payload must match spec vector exactly")

        // Decrypt the spec payload
        let decrypted = try NIP44.decrypt(payload: expectedPayload, conversationKey: convKey)
        XCTAssertEqual(decrypted, plaintext, "Decrypted text must match original")

        // Vector 2: sec1=2, sec2=1 (same conversation key), emoji plaintext
        let nonce2 = try NostrKeyUtils.hexDecode("f00000000000000000000000000000f00000000000000000000000000000000f")
        let plaintext2 = "🍕🫃"
        let expectedPayload2 = "AvAAAAAAAAAAAAAAAAAAAPAAAAAAAAAAAAAAAAAAAAAPSKSK6is9ngkX2+cSq85Th16oRTISAOfhStnixqZziKMDvB0QQzgFZdjLTPicCJaV8nDITO+QfaQ61+KbWQIOO2Yj"

        let encrypted2 = try NIP44.encrypt(plaintext: plaintext2, conversationKey: convKey, nonce: nonce2)
        XCTAssertEqual(encrypted2, expectedPayload2, "Encrypted emoji payload must match spec vector")

        let decrypted2 = try NIP44.decrypt(payload: expectedPayload2, conversationKey: convKey)
        XCTAssertEqual(decrypted2, plaintext2, "Decrypted emoji text must match original")
    }

    // MARK: - NIP-46 URI Parsing

    func testParseNostrConnectURI() throws {
        let clientPubkey = "aa".repeating(count: 32)
        let uri = "nostrconnect://\(clientPubkey)?relay=wss%3A%2F%2Frelay.damus.io&secret=mysecret&name=Damus&perms=sign_event"

        let info = try NIP46ConnectionParser.parse(uri)

        XCTAssertEqual(info.flow, .clientInitiated)
        XCTAssertEqual(info.pubkey, clientPubkey)
        XCTAssertEqual(info.relays, ["wss://relay.damus.io"])
        XCTAssertEqual(info.secret, "mysecret")
        XCTAssertEqual(info.name, "Damus")
        XCTAssertEqual(info.permissions, "sign_event")
    }

    func testParseBunkerURI() throws {
        let signerPubkey = "bb".repeating(count: 32)
        let uri = "bunker://\(signerPubkey)?relay=wss%3A%2F%2Frelay.nostr.band&secret=abc123"

        let info = try NIP46ConnectionParser.parse(uri)

        XCTAssertEqual(info.flow, .signerInitiated)
        XCTAssertEqual(info.pubkey, signerPubkey)
        XCTAssertEqual(info.relays, ["wss://relay.nostr.band"])
        XCTAssertEqual(info.secret, "abc123")
        XCTAssertNil(info.name)
        XCTAssertNil(info.permissions)
    }

    func testParseMultipleRelays() throws {
        let pubkey = "cc".repeating(count: 32)
        let uri = "nostrconnect://\(pubkey)?relay=wss%3A%2F%2Frelay.damus.io&relay=wss%3A%2F%2Fnos.lol&name=Primal"

        let info = try NIP46ConnectionParser.parse(uri)

        XCTAssertEqual(info.relays.count, 2)
        XCTAssertTrue(info.relays.contains("wss://relay.damus.io"))
        XCTAssertTrue(info.relays.contains("wss://nos.lol"))
    }

    func testParseRejectsInvalidScheme() {
        XCTAssertThrowsError(try NIP46ConnectionParser.parse("https://example.com")) { error in
            if case NIP46ConnectionParser.ParseError.unsupportedScheme(let scheme) = error {
                XCTAssertEqual(scheme, "https")
            } else {
                XCTFail("Expected unsupportedScheme error")
            }
        }
    }

    func testParseRejectsMissingPubkey() {
        XCTAssertThrowsError(try NIP46ConnectionParser.parse("nostrconnect://?relay=wss://relay.damus.io")) { error in
            XCTAssertTrue(error is NIP46ConnectionParser.ParseError)
        }
    }

    func testParseRejectsInvalidPubkey() {
        XCTAssertThrowsError(
            try NIP46ConnectionParser.parse("nostrconnect://tooshort?relay=wss://relay.damus.io")
        ) { error in
            if case NIP46ConnectionParser.ParseError.invalidPubkey = error {
                // expected
            } else {
                XCTFail("Expected invalidPubkey error, got \(error)")
            }
        }
    }

    func testParseRejectsMissingRelay() {
        let pubkey = "dd".repeating(count: 32)
        XCTAssertThrowsError(try NIP46ConnectionParser.parse("nostrconnect://\(pubkey)")) { error in
            if case NIP46ConnectionParser.ParseError.missingRelay = error {
                // expected
            } else {
                XCTFail("Expected missingRelay error, got \(error)")
            }
        }
    }

    func testParseHandlesUnescapedRelayURL() throws {
        let pubkey = "ee".repeating(count: 32)
        let uri = "nostrconnect://\(pubkey)?relay=wss://relay.damus.io&name=Test"

        let info = try NIP46ConnectionParser.parse(uri)
        XCTAssertEqual(info.relays, ["wss://relay.damus.io"])
        XCTAssertEqual(info.name, "Test")
    }

    // MARK: - NIP-46 Message Handler

    func testParseRequest() throws {
        let json = """
        {"id":"abc123","method":"get_public_key","params":[]}
        """
        let request = try NIP46MessageHandler.parseRequest(json)
        XCTAssertEqual(request.id, "abc123")
        XCTAssertEqual(request.method, "get_public_key")
        XCTAssertTrue(request.params.isEmpty)
    }

    func testParseSignEventRequest() throws {
        let json = """
        {"id":"req-001","method":"sign_event","params":["{\\"kind\\":1,\\"content\\":\\"Hello\\",\\"tags\\":[],\\"pubkey\\":\\"\\",\\"created_at\\":1700000000,\\"id\\":\\"\\",\\"sig\\":\\"\\"}"]}
        """
        let request = try NIP46MessageHandler.parseRequest(json)
        XCTAssertEqual(request.id, "req-001")
        XCTAssertEqual(request.method, "sign_event")
        XCTAssertEqual(request.params.count, 1)
    }

    func testParseRequestRejectsInvalidJSON() {
        XCTAssertThrowsError(try NIP46MessageHandler.parseRequest("not json")) { error in
            XCTAssertTrue(error is NIP46MessageHandler.HandlerError)
        }
    }

    func testHandleGetPublicKey() async throws {
        let signer = MockSigner(privateKey: alicePrivKey)
        let session = try makeTestSession()

        let request = NIP46Request(id: "req-1", method: "get_public_key", params: [])
        let response = await NIP46MessageHandler.handleRequest(request, signer: signer, session: session)

        XCTAssertEqual(response.id, "req-1")
        XCTAssertNil(response.error)
        XCTAssertNotNil(response.result)
        XCTAssertEqual(response.result?.count, 64) // 32-byte hex pubkey
    }

    func testHandleConnect() async throws {
        let signer = MockSigner(privateKey: alicePrivKey)
        let session = try makeTestSession()

        let request = NIP46Request(id: "req-2", method: "connect", params: [NostrKeyUtils.hexEncode(bobPubKey)])
        let response = await NIP46MessageHandler.handleRequest(request, signer: signer, session: session)

        XCTAssertEqual(response.id, "req-2")
        XCTAssertEqual(response.result, "ack")
        XCTAssertNil(response.error)
    }

    func testHandleUnknownMethod() async throws {
        let signer = MockSigner(privateKey: alicePrivKey)
        let session = try makeTestSession()

        let request = NIP46Request(id: "req-3", method: "unknown_method", params: [])
        let response = await NIP46MessageHandler.handleRequest(request, signer: signer, session: session)

        XCTAssertEqual(response.id, "req-3")
        XCTAssertNil(response.result)
        XCTAssertNotNil(response.error)
        XCTAssertTrue(response.error!.contains("Unsupported method"))
    }

    // MARK: - Simulated sign_event round-trip

    func testSignEventRoundTrip() async throws {
        let signer = MockSigner(privateKey: alicePrivKey)
        let session = try makeTestSession()
        let convKey = session.conversationKey

        // 1. Build an unsigned event (what a client like Damus would send)
        let unsignedEvent = NostrEvent.unsigned(
            pubkey: "",
            kind: 1,
            content: "Hello from Damus via NIP-46!",
            createdAt: 1700000000
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let unsignedJSON = try encoder.encode(unsignedEvent)
        let unsignedString = String(data: unsignedJSON, encoding: .utf8)!

        // 2. Build NIP-46 JSON-RPC request
        let requestJSON = """
        {"id":"sign-001","method":"sign_event","params":["\(unsignedString.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))"]}
        """

        // 3. Encrypt with NIP-44 (simulating client encrypting before sending)
        let encryptedRequest = try NIP44.encrypt(plaintext: requestJSON, conversationKey: convKey)

        // 4. Decrypt on signer side (Signstr receives the kind 24133 event)
        let decryptedRequest = try NIP46MessageHandler.decryptRequest(
            payload: encryptedRequest,
            conversationKey: convKey
        )

        XCTAssertEqual(decryptedRequest.id, "sign-001")
        XCTAssertEqual(decryptedRequest.method, "sign_event")

        // 5. Handle the request (Signstr signs it)
        let response = await NIP46MessageHandler.handleRequest(
            decryptedRequest,
            signer: signer,
            session: session
        )

        XCTAssertEqual(response.id, "sign-001")
        XCTAssertNil(response.error)
        XCTAssertNotNil(response.result)

        // 6. Parse the signed event from the response
        let signedEventData = response.result!.data(using: .utf8)!
        let signedEvent = try JSONDecoder().decode(NostrEvent.self, from: signedEventData)

        // 7. Verify the signed event
        XCTAssertEqual(signedEvent.kind, 1)
        XCTAssertEqual(signedEvent.content, "Hello from Damus via NIP-46!")
        XCTAssertEqual(signedEvent.createdAt, 1700000000)
        XCTAssertEqual(signedEvent.id.count, 64, "Event ID should be 64-char hex")
        XCTAssertEqual(signedEvent.sig.count, 128, "Signature should be 128-char hex")
        XCTAssertEqual(signedEvent.pubkey.count, 64, "Pubkey should be 64-char hex")
        XCTAssertFalse(signedEvent.id.isEmpty)
        XCTAssertFalse(signedEvent.sig.isEmpty)

        // Verify pubkey matches Alice's
        let expectedPubkey = NostrKeyUtils.hexEncode(alicePubKey)
        XCTAssertEqual(signedEvent.pubkey, expectedPubkey)

        // 8. Encrypt the response (Signstr sends back via kind 24133)
        let encryptedResponse = try NIP46MessageHandler.encryptResponse(response, conversationKey: convKey)

        // 9. Decrypt on client side (Damus receives the response)
        let decryptedResponseJSON = try NIP44.decrypt(payload: encryptedResponse, conversationKey: convKey)
        let decryptedResponse = try JSONDecoder().decode(NIP46Response.self, from: decryptedResponseJSON.data(using: .utf8)!)

        XCTAssertEqual(decryptedResponse.id, "sign-001")
        XCTAssertNil(decryptedResponse.error)
        XCTAssertNotNil(decryptedResponse.result)

        // Full circle: the client can now parse the signed event
        let finalEvent = try JSONDecoder().decode(NostrEvent.self, from: decryptedResponse.result!.data(using: .utf8)!)
        XCTAssertEqual(finalEvent.sig.count, 128)
        XCTAssertEqual(finalEvent.pubkey, expectedPubkey)
    }

    // MARK: - Encrypt / Decrypt response round-trip

    func testEncryptDecryptResponse() throws {
        let convKey = try NIP44.conversationKey(
            privateKey: alicePrivKey,
            publicKey: bobPubKey
        )

        let response = NIP46Response.success(id: "test-1", result: "ack")
        let encrypted = try NIP46MessageHandler.encryptResponse(response, conversationKey: convKey)

        let decryptedJSON = try NIP44.decrypt(payload: encrypted, conversationKey: convKey)
        let decoded = try JSONDecoder().decode(NIP46Response.self, from: decryptedJSON.data(using: .utf8)!)

        XCTAssertEqual(decoded.id, "test-1")
        XCTAssertEqual(decoded.result, "ack")
        XCTAssertNil(decoded.error)
    }

    // MARK: - NIP46Session

    func testSessionDisplayNameUsesAppName() throws {
        let session = try makeTestSession()
        XCTAssertEqual(session.displayName, "TestClient")
    }

    func testSessionDisplayNameFallsToPubkey() throws {
        let convKey = try NIP44.conversationKey(
            privateKey: alicePrivKey,
            publicKey: bobPubKey
        )
        let pubkeyHex = NostrKeyUtils.hexEncode(bobPubKey)
        let session = NIP46Session(
            appName: nil,
            clientPubkey: pubkeyHex,
            relays: ["wss://relay.damus.io"],
            conversationKey: convKey
        )
        XCTAssertTrue(session.displayName.contains("..."))
    }

    // MARK: - Helpers

    private func makeTestSession() throws -> NIP46Session {
        let convKey = try NIP44.conversationKey(
            privateKey: alicePrivKey,
            publicKey: bobPubKey
        )
        return NIP46Session(
            appName: "TestClient",
            clientPubkey: NostrKeyUtils.hexEncode(bobPubKey),
            relays: ["wss://relay.damus.io"],
            conversationKey: convKey
        )
    }
}

// MARK: - Test helpers

private extension String {
    func repeating(count: Int) -> String {
        String(repeating: self, count: count)
    }
}
