// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// Licensed under GPL-3.0
//
//  NIP46TestClientView.swift
//  Signstr — Debug NIP-46 test client for end-to-end testing

import CryptoKit
import CoreImage.CIFilterBuiltins
import Foundation
import P256K
import SwiftUI

/// A debug screen that acts as a NIP-46 **client** (not signer).
///
/// Generates a throwaway keypair, builds a `nostrconnect://` URI, shows it as QR,
/// subscribes to kind 24133 events, and logs every step of decryption.
/// This lets us test both sides (client + signer) on the same device.
struct NIP46TestClientView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var nip46Service: NIP46Service

    @StateObject private var vm = NIP46TestClientVM()

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 32)

                    Image(systemName: "ant")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(.sgTextGhost)

                    Spacer().frame(height: 8)

                    Text("NIP-46 TEST CLIENT")
                        .font(.outfit(.regular, size: 10))
                        .tracking(5)
                        .foregroundColor(.sgTextGhost)

                    Spacer().frame(height: 24)

                    // ── Key info ──
                    keyInfoCard

                    Spacer().frame(height: 16)

                    // ── QR code ──
                    qrCodeCard

                    Spacer().frame(height: 16)

                    // ── URI copyable ──
                    uriCard

                    Spacer().frame(height: 16)

                    // ── Controls ──
                    controlsCard

                    Spacer().frame(height: 16)

                    // ── Self-test: scan as signer ──
                    selfTestCard

                    Spacer().frame(height: 16)

                    // ── Event log ──
                    logCard

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            vm.disconnect()
            dismiss()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                Text("Back")
                    .font(.custom("Outfit-Regular", size: 12))
            }
            .foregroundColor(.sgTextMuted)
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("DEBUG CLIENT")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
            }
        }
        .onAppear {
            vm.generateKeyAndURI()
        }
        .onDisappear {
            vm.disconnect()
        }
    }

    // MARK: - Key info card

    private var keyInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("CLIENT KEYPAIR")

            labeledMono("Pubkey:", vm.clientPubkeyHex)
            labeledMono("Privkey:", vm.clientPrivkeyHex.prefix(8) + "..." + vm.clientPrivkeyHex.suffix(4))
        }
        .cardStyle()
    }

    // MARK: - QR code

    private var qrCodeCard: some View {
        VStack(spacing: 12) {
            sectionHeader("SCAN WITH SIGNSTR SIGNER")

            if let qrImage = vm.qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(Dimensions.cardCornerRadius)
            } else {
                Text("Generating...")
                    .font(.outfit(.light, size: 12))
                    .foregroundColor(.sgTextFaint)
            }

            Text("Scan this QR as if you were the signer adding a connection.")
                .font(.outfit(.light, size: 11))
                .foregroundColor(.sgTextFaint)
                .multilineTextAlignment(.center)
        }
        .cardStyle()
    }

    // MARK: - URI card

    private var uriCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("CONNECTION URI")

            Text(vm.nostrConnectURI)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.sgTextBody)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                ClipboardManager.shared.copy(vm.nostrConnectURI)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                    Text("COPY URI")
                        .font(.outfit(.regular, size: 9))
                        .tracking(2)
                }
                .foregroundColor(.sgTextMuted)
            }
        }
        .cardStyle()
    }

    // MARK: - Controls

    private var controlsCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                SKButton(text: vm.isSubscribed ? "Listening..." : "Subscribe", style: .inform) {
                    vm.subscribeToRelay()
                }
                .disabled(vm.isSubscribed)

                SKButton(text: "Disconnect", style: .inform) {
                    vm.disconnect()
                }
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(vm.isSubscribed ? Color.green : Color.sgTextGhost)
                    .frame(width: 6, height: 6)

                Text(vm.connectionStatus)
                    .font(.outfit(.light, size: 10))
                    .foregroundColor(.sgTextFaint)
            }
        }
        .cardStyle()
    }

    // MARK: - Self-test: feed URI to our own signer

    private var selfTestCard: some View {
        VStack(spacing: 8) {
            sectionHeader("SELF-TEST")

            Text("Feed the URI directly to Signstr's signer side (no external app needed).")
                .font(.outfit(.light, size: 11))
                .foregroundColor(.sgTextFaint)
                .fixedSize(horizontal: false, vertical: true)

            SKButton(text: "Self-test: Connect as Signer", style: .inform) {
                vm.selfTestConnect(nip46Service: nip46Service)
            }

            if let selfTestResult = vm.selfTestResult {
                Text(selfTestResult)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(selfTestResult.contains("ERROR") ? .sgDanger : Color(hex: "#2d5a3d"))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle()
    }

    // MARK: - Log card

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("EVENT LOG")
                Spacer()
                Button(action: { vm.logEntries.removeAll() }) {
                    Text("CLEAR")
                        .font(.outfit(.regular, size: 9))
                        .tracking(2)
                        .foregroundColor(.sgTextGhost)
                }
            }

            if vm.logEntries.isEmpty {
                Text("No events yet. Subscribe, then scan the QR with Signstr or paste the URI into AddConnection.")
                    .font(.outfit(.light, size: 11))
                    .foregroundColor(.sgTextFaint)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(vm.logEntries) { entry in
                        logRow(entry)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.outfit(.regular, size: 9))
            .tracking(3)
            .foregroundColor(.sgTextGhost)
    }

    private func labeledMono(_ label: String, _ value: some StringProtocol) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.outfit(.regular, size: 10))
                .foregroundColor(.sgTextMuted)
                .frame(width: 55, alignment: .trailing)

            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.sgTextBody)
                .lineLimit(2)
        }
    }

    private func logRow(_ entry: NIP46TestLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(entry.isError ? Color.sgDanger : Color(hex: "#2d5a3d"))
                    .frame(width: 4, height: 4)

                Text(entry.timestamp)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.sgTextGhost)
            }

            Text(entry.message)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(entry.isError ? .sgDanger : .sgTextBody)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Card style modifier

private extension View {
    func cardStyle() -> some View {
        self
            .padding(Dimensions.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.sgBgRaised)
            .cornerRadius(Dimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                    .stroke(Color.sgBorder, lineWidth: 1)
            )
    }
}

// MARK: - Log entry model

struct NIP46TestLogEntry: Identifiable {
    let id = UUID()
    let timestamp: String
    let message: String
    let isError: Bool

    init(_ message: String, isError: Bool = false) {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss.SSS"
        self.timestamp = fmt.string(from: Date())
        self.message = message
        self.isError = isError
    }
}

// MARK: - View model

@MainActor
final class NIP46TestClientVM: ObservableObject {

    @Published var clientPubkeyHex = ""
    @Published var clientPrivkeyHex = ""
    @Published var nostrConnectURI = ""
    @Published var qrImage: UIImage?
    @Published var isSubscribed = false
    @Published var connectionStatus = "Not connected"
    @Published var logEntries: [NIP46TestLogEntry] = []
    @Published var selfTestResult: String?

    private var clientPrivateKey: Data?
    private var clientPublicKey: Data?
    private var webSocket: URLSessionWebSocketTask?
    private let relayURL = "wss://relay.damus.io"

    // MARK: - Generate keypair and URI

    func generateKeyAndURI() {
        do {
            let privKey = try P256K.Schnorr.PrivateKey()
            let privKeyData = privKey.dataRepresentation
            let pubKeyData = Data(privKey.xonly.bytes)

            clientPrivateKey = privKeyData
            clientPublicKey = pubKeyData
            clientPubkeyHex = NostrKeyUtils.hexEncode(pubKeyData)
            clientPrivkeyHex = NostrKeyUtils.hexEncode(privKeyData)

            // Build nostrconnect:// URI
            let secret = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)
            let encodedRelay = relayURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? relayURL
            nostrConnectURI = "nostrconnect://\(clientPubkeyHex)?relay=\(encodedRelay)&secret=\(secret)&name=SignstrDebugClient"

            log("Generated throwaway keypair")
            log("Pubkey: \(clientPubkeyHex)")
            log("URI: \(nostrConnectURI.prefix(80))...")

            // Generate QR
            qrImage = generateQR(for: nostrConnectURI)

        } catch {
            log("ERROR: Failed to generate keypair: \(error)", isError: true)
        }
    }

    // MARK: - Subscribe to relay

    func subscribeToRelay() {
        guard !isSubscribed else { return }
        guard let url = URL(string: relayURL) else {
            log("ERROR: Invalid relay URL", isError: true)
            return
        }

        log("Connecting to \(relayURL)...")
        connectionStatus = "Connecting..."

        let task = URLSession.shared.webSocketTask(with: url)
        webSocket = task
        task.resume()

        // Send REQ
        let sinceTimestamp = Int(Date().timeIntervalSince1970) - 10
        let subId = "debug-\(clientPubkeyHex.prefix(8))"
        let filter = """
        {"kinds":[24133],"#p":["\(clientPubkeyHex)"],"since":\(sinceTimestamp)}
        """
        let message = "[\"REQ\",\"\(subId)\",\(filter)]"

        log("Sending REQ: \(message.prefix(120))...")

        task.send(.string(message)) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.log("ERROR: REQ send failed: \(error)", isError: true)
                    self?.connectionStatus = "REQ failed"
                } else {
                    self?.log("REQ sent, listening for kind 24133 events")
                    self?.isSubscribed = true
                    self?.connectionStatus = "Subscribed"
                }
            }
        }

        // Start listening
        listenForMessages(on: task)
    }

    // MARK: - Listen

    private func listenForMessages(on task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self?.handleRelayMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self?.handleRelayMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    // Continue listening
                    if let ws = self?.webSocket {
                        self?.listenForMessages(on: ws)
                    }
                case .failure(let error):
                    self?.log("ERROR: WebSocket disconnected: \(error)", isError: true)
                    self?.isSubscribed = false
                    self?.connectionStatus = "Disconnected"
                }
            }
        }
    }

    // MARK: - Handle relay messages

    private func handleRelayMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
              array.count >= 2,
              let msgType = array[0] as? String else {
            log("Unparseable: \(text.prefix(100))")
            return
        }

        switch msgType {
        case "OK":
            let eventId = (array.count > 1 ? array[1] as? String : nil) ?? "?"
            let accepted = (array.count > 2 ? array[2] as? Bool : nil) ?? false
            log("OK: \(eventId.prefix(16))... accepted=\(accepted)")
        case "EOSE":
            log("EOSE received — subscription active")
        case "NOTICE":
            let notice = (array.count > 1 ? array[1] as? String : nil) ?? "?"
            log("NOTICE: \(notice)")
        case "EVENT":
            guard array.count >= 3,
                  let eventDict = array[2] as? [String: Any] else {
                log("EVENT but no dict", isError: true)
                return
            }
            handleIncomingEvent(eventDict)
        default:
            log("\(msgType): \(text.prefix(100))")
        }
    }

    // MARK: - Process incoming event

    private func handleIncomingEvent(_ eventDict: [String: Any]) {
        let kind = eventDict["kind"] as? Int ?? -1
        let senderPubkey = eventDict["pubkey"] as? String ?? "?"
        let content = eventDict["content"] as? String ?? ""
        let eventId = eventDict["id"] as? String ?? "?"

        log("── INCOMING EVENT ──")
        log("Kind: \(kind)")
        log("ID: \(eventId)")
        log("Sender pubkey: \(senderPubkey)")
        log("Content length: \(content.count)")
        log("Content (first 100): \(content.prefix(100))")

        // Check for NIP-04 vs NIP-44 format
        let hasIVMarker = content.contains("?iv=")
        log("Has ?iv= marker: \(hasIVMarker)")

        // Try base64 decode for version byte check
        if let decoded = Data(base64Encoded: content) {
            let versionByte = decoded.first.map { String(format: "0x%02x", $0) } ?? "nil"
            log("Base64 decoded: \(decoded.count) bytes, version byte: \(versionByte)")
            if decoded.count >= 4 {
                let first4 = decoded.prefix(4).map { String(format: "%02x", $0) }.joined()
                log("First 4 bytes: \(first4)")
            }
        } else {
            log("NOT valid base64 (likely NIP-04 format)")
        }

        guard let privKey = clientPrivateKey else {
            log("ERROR: No client private key available", isError: true)
            return
        }

        let senderPubkeyData: Data
        do {
            senderPubkeyData = try NostrKeyUtils.hexDecode(senderPubkey)
        } catch {
            log("ERROR: Invalid sender pubkey hex: \(error)", isError: true)
            return
        }

        // ── Attempt NIP-04 decryption ──
        log("── Attempting NIP-04 decryption ──")
        do {
            let ecdhSecret = try NIP04.ecdhSharedSecret(privateKey: privKey, publicKey: senderPubkeyData)
            log("NIP-04 ECDH shared secret (first 4): \(ecdhSecret.prefix(4).map { String(format: "%02x", $0) }.joined())")

            let plaintext = try NIP04.decrypt(
                payload: content,
                privateKey: privKey,
                publicKey: senderPubkeyData
            )
            log("NIP-04 DECRYPTED: \(plaintext)")

            // Try to parse as JSON-RPC response
            if let jsonData = plaintext.data(using: .utf8),
               let jsonObj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                log("Parsed JSON: id=\(jsonObj["id"] ?? "nil"), result=\(jsonObj["result"] ?? "nil"), error=\(jsonObj["error"] ?? "nil")")
            }
        } catch {
            log("NIP-04 failed: \(error)", isError: true)
        }

        // ── Attempt NIP-44 decryption (HKDF conversation key) ──
        log("── Attempting NIP-44 decryption (HKDF) ──")
        do {
            let convKey = try NIP44.conversationKey(privateKey: privKey, publicKey: senderPubkeyData)
            let ck4 = convKey.withUnsafeBytes { Data($0).prefix(4).map { String(format: "%02x", $0) }.joined() }
            log("NIP-44 conversation key (first 4): \(ck4)")

            let plaintext = try NIP44.decrypt(payload: content, conversationKey: convKey)
            log("NIP-44 (HKDF) DECRYPTED: \(plaintext)")
        } catch {
            log("NIP-44 (HKDF) failed: \(error)", isError: true)
        }

        // ── Attempt NIP-44 decryption (raw ECDH, no HKDF) ──
        log("── Attempting NIP-44 decryption (raw ECDH) ──")
        do {
            let rawECDH = try NIP44.ecdhSharedSecret(privateKey: privKey, publicKey: senderPubkeyData)
            let rawKey = SymmetricKey(data: rawECDH)
            let rk4 = rawECDH.prefix(4).map { String(format: "%02x", $0) }.joined()
            log("Raw ECDH key (first 4): \(rk4)")

            let plaintext = try NIP44.decrypt(payload: content, conversationKey: rawKey)
            log("NIP-44 (raw ECDH) DECRYPTED: \(plaintext)")
        } catch {
            log("NIP-44 (raw ECDH) failed: \(error)", isError: true)
        }

        log("── END EVENT ──")
    }

    // MARK: - Self-test

    func selfTestConnect(nip46Service: NIP46Service) {
        guard !nostrConnectURI.isEmpty else {
            selfTestResult = "ERROR: Generate URI first"
            return
        }

        // First make sure we're subscribed so we can receive the connect response
        if !isSubscribed {
            subscribeToRelay()
        }

        log("── SELF-TEST: Feeding URI to signer ──")
        selfTestResult = nil

        Task {
            do {
                // Load the signer's nsec
                let nsec = try SecureEnclaveKeyStore.load()

                // Parse the URI we generated
                let connInfo = try NIP46ConnectionParser.parse(nostrConnectURI)
                log("Parsed URI: pubkey=\(connInfo.pubkey.prefix(16))... relay=\(connInfo.relays.first ?? "nil")")

                // Feed it to the signer side
                let session = try nip46Service.addConnection(
                    from: connInfo,
                    signerPrivateKey: nsec
                )
                log("Signer created session: \(session.displayName)")
                log("Signer will now send connect response to \(relayURL)")
                selfTestResult = "OK: Signer connected. Watch log for incoming event."
            } catch {
                log("ERROR: Self-test failed: \(error)", isError: true)
                selfTestResult = "ERROR: \(error)"
            }
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isSubscribed = false
        connectionStatus = "Disconnected"
    }

    // MARK: - Helpers

    private func log(_ message: String, isError: Bool = false) {
        let entry = NIP46TestLogEntry(message, isError: isError)
        logEntries.insert(entry, at: 0) // newest first
        print("[NIP46-TestClient] \(message)")
    }

    private func generateQR(for string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }
        let scale = 10.0
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
