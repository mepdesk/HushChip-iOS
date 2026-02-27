# SIGNSTR iOS APP -- CLAUDE CODE SPINE DOCUMENT

**INCLUDE THIS DOCUMENT AT THE START OF EVERY CLAUDE CODE SESSION.**

This is the single source of truth for the Signstr iOS app project. It tells you what this project is, what the architecture looks like, the Nostr protocol logic, the two-tier signing model, and the design system to follow.

---

## WHAT IS THIS PROJECT

Signstr is the first standalone Nostr event signer for iOS. It lets users store their Nostr private key (nsec) securely and sign events (posts, reactions, DMs) without pasting their nsec into every Nostr client.

The app has two signing tiers:

**Tier 1 — Software Signer (v1.0, launch product, no card needed):**
The nsec is encrypted using the device's Secure Enclave (iOS) and stored locally. The app decrypts the key in memory only when signing, then discards it. This is already more secure than every Nostr client that stores nsec in plaintext.

**Tier 2 — Card Signer (v2.0, hardware upgrade):**
The user purchases a NostrKey card (NFC smartcard with Satochip applet). The nsec is migrated from device to card. From that point, the private key lives in the card's secure element and never touches the phone. Signing happens by NFC tap.

The app is a fork of the HushChip iOS app (itself a fork of Toporin/Seedkeeper-iOS). The NFC/APDU infrastructure from HushChip is preserved but dormant until v2.0.

**Fork source:** github.com/hushchip/HushChip-iOS
**Upstream:** github.com/Toporin/Seedkeeper-iOS (Swift, GPL-3.0)
**Card applet (v2.0):** github.com/Toporin/SatochipApplet v0.14-0.2 (AGPLv3)
**APDU reference (v2.0):** github.com/Toporin/pysatochip (Python CLI, LGPL v3)
**Licence:** GPL-3.0 (must remain GPL-3.0, source must be public)
**Product name:** Signstr (app), NostrKey (physical card)
**Bundle ID:** uk.co.hushchip.signstr (or com.signstr.app -- TBD)
**Website:** signstr.com

---

## THE TWO-TIER MODEL

```
TIER 1 (v1.0) — Software Signer
┌─────────────────────────────────────────────────┐
│  nsec encrypted in iOS Secure Enclave           │
│  App decrypts in memory → signs → discards      │
│  Key never hits disk in plaintext               │
│  Already better than every Nostr client         │
└─────────────────────────────────────────────────┘

TIER 2 (v2.0) — Card Signer (NostrKey)
┌─────────────────────────────────────────────────┐
│  nsec stored in NFC card secure element         │
│  App sends hash → card signs → app broadcasts   │
│  Key NEVER touches the phone                    │
│  Air-gapped. Maximum security.                  │
└─────────────────────────────────────────────────┘

The upgrade path: "Start signing today. Go air-gapped when you're ready."
```

### Why This Matters

There is currently NO standalone Nostr signer app on iOS:
- Amber is Android only
- Nostash is a Safari extension only
- nsec.app is browser-based
- Every iOS Nostr client (Damus, Primal, Nos) stores the nsec directly

Signstr v1.0 fills this gap immediately. The card is the premium upgrade, not the prerequisite.

---

## ARCHITECTURE

```
Signstr iOS App
│
├── UI Layer (FORK FROM HUSHCHIP, REBRAND)
│   ├── Views / Screens (SwiftUI)
│   ├── Theme (Ghost palette, Outfit font -- SAME as HushChip)
│   ├── Assets (icons, images, NEW app icon)
│   ├── Strings (all new -- Signstr branding)
│   └── Navigation / Routing
│
├── Nostr Logic Layer (NEW -- WRITE FROM SCRATCH)
│   ├── NostrEvent.swift           Event construction (NIP-01)
│   ├── NostrEventSerializer.swift Event JSON serialisation for hashing
│   ├── NostrKeyUtils.swift        nsec/npub bech32 encoding/decoding
│   ├── NostrRelay.swift           WebSocket relay connection
│   ├── NostrRelayPool.swift       Multi-relay management
│   └── NostrSigner.swift          Protocol defining sign interface
│
├── Key Storage Layer (NEW -- WRITE FROM SCRATCH)
│   ├── SecureEnclaveKeyStore.swift   Tier 1: encrypt/decrypt nsec via Secure Enclave
│   ├── KeyManager.swift              Key lifecycle (generate, import, export-to-card, delete)
│   └── SignstrKeychain.swift         Keychain wrapper for encrypted key storage
│
├── Software Signing Layer (NEW -- v1.0)
│   ├── SoftwareSigner.swift          Implements NostrSigner using in-memory key
│   └── SchnorrSigner.swift           secp256k1 Schnorr signing (use swift-secp256k1 library)
│
├── Card Communication Layer (DORMANT -- ACTIVATE IN v2.0)
│   ├── SatochipCardService.swift     Satochip-specific APDU commands
│   ├── CardSigner.swift              Implements NostrSigner using NFC card
│   ├── NFCSessionManager.swift       NFC session lifecycle (INHERITED from HushChip)
│   ├── SecureChannel.swift           ECDH key exchange + AES (INHERITED from HushChip)
│   ├── PINManager.swift              PIN verify/set (INHERITED from HushChip)
│   └── APDUResponse.swift            Response parsing (INHERITED from HushChip)
│
└── Platform Layer
    ├── CoreNFC integration (INHERITED, dormant until v2.0)
    ├── Haptics (REUSE from HushChip)
    ├── Keychain (relay list, preferences)
    └── Biometrics (Face ID / Touch ID to unlock key)
```

### The Signer Protocol (Core Abstraction)

```swift
protocol NostrSigner {
    var isCardBacked: Bool { get }
    func getPublicKey() async throws -> Data          // 32-byte x-only pubkey
    func signHash(_ hash: Data) async throws -> Data  // 64-byte Schnorr signature
}

class SoftwareSigner: NostrSigner {
    // v1.0: Decrypts nsec from Secure Enclave, signs in memory, discards
    var isCardBacked: Bool { false }
}

class CardSigner: NostrSigner {
    // v2.0: Sends hash to NFC card, receives signature
    var isCardBacked: Bool { true }
}

class MockSigner: NostrSigner {
    // Development: Signs with hardcoded test key, for simulator use
    var isCardBacked: Bool { false }
    // MUST be disabled in production builds
}
```

The entire app uses `NostrSigner` protocol. Swapping from SoftwareSigner to CardSigner requires zero UI changes.

---

## THE GOLDEN RULE (v1.0)

```
┌─────────────────────────────────────────────────┐
│                                                 │
│   DO NOT MODIFY OR DELETE THE INHERITED         │
│   APDU / NFC / CARD COMMUNICATION FILES.        │
│                                                 │
│   They are DORMANT, not dead.                   │
│   They will be activated in v2.0.               │
│                                                 │
│   Leave them in the project. Don't import       │
│   them in v1.0 screens. Don't delete them.      │
│                                                 │
└─────────────────────────────────────────────────┘
```

### What You CAN Freely Change

- All SwiftUI views, screens, layouts, colours, fonts, spacing
- All string literals (app name, labels, descriptions, error messages)
- All asset files (icons, images, colours in asset catalogs)
- App icon, splash screen, launch storyboard
- Info.plist (bundle ID, app name, version)
- Xcode project settings (signing, capabilities, scheme names)
- Navigation flow and screen routing
- Adding entirely new screens and features
- All new Nostr logic, key storage, and signing code

### What You Must NOT Change (Dormant v2.0 Code)

- Files that build APDU command byte arrays
- Files that parse APDU response byte arrays
- Files managing NFC session lifecycle (NFCTagReaderSession)
- Files implementing secure channel (ECDH, AES-128-CBC)
- Files handling PIN verification protocol
- Files with CoreNFC `sendCommand` calls

---

## SECURE KEY STORAGE (v1.0)

### iOS Secure Enclave Approach

```
1. User imports nsec (paste or QR scan) OR generates new keypair
2. App derives a Secure Enclave key (P-256, kSecAttrTokenIDSecureEnclave)
3. nsec (32 bytes) is encrypted with the SE key
4. Encrypted blob stored in iOS Keychain (kSecClassGenericPassword)
5. To sign: app requests SE decryption (triggers Face ID / Touch ID)
6. Decrypted nsec held in memory ONLY during signing operation
7. nsec zeroed from memory immediately after signature is computed

The raw nsec NEVER exists on disk in plaintext.
The Secure Enclave key cannot be exported from the device.
Face ID / Touch ID gates every signing operation.
```

### Key Generation

For users without an existing Nostr identity, the app can generate a new keypair:
1. Generate 32 random bytes using `SecRandomCopyBytes` (CSPRNG)
2. Validate as valid secp256k1 scalar
3. Derive x-only public key (npub)
4. Encrypt and store nsec per above flow
5. Display npub to user for sharing

### Key Import

For users with an existing nsec:
1. User pastes nsec1... string or scans QR code
2. App decodes bech32 (HRP "nsec") to 32-byte raw key
3. Validate as valid secp256k1 scalar
4. Encrypt and store per above flow
5. Derive and display npub
6. IMMEDIATELY zero the raw nsec from any text field / clipboard

### Key Export to Card (v2.0 Migration)

When user purchases a NostrKey card:
1. App decrypts nsec from Secure Enclave (Face ID)
2. NFC session opens, secure channel established with card
3. nsec sent to card via INS_IMPORT_KEY (encrypted over secure channel)
4. Card confirms import
5. App DELETES local encrypted nsec from Keychain
6. App switches signing mode from SoftwareSigner to CardSigner
7. From this point, all signing goes through NFC tap

---

## NOSTR PROTOCOL REFERENCE

### NIP-01: Event Format

```json
{
  "id": "<32-byte lowercase hex SHA-256 of serialised event>",
  "pubkey": "<32-byte lowercase hex x-only pubkey>",
  "created_at": <unix timestamp seconds>,
  "kind": <integer>,
  "tags": [["tag", "value"], ...],
  "content": "<string>",
  "sig": "<64-byte lowercase hex Schnorr signature>"
}
```

### Event ID Computation

The event `id` is the SHA-256 hash of the following serialised UTF-8 string:

```
[0, <pubkey>, <created_at>, <kind>, <tags>, <content>]
```

This is a JSON array with exactly these elements:
- `0` (literal integer zero)
- pubkey as lowercase hex string
- created_at as integer
- kind as integer
- tags as array of arrays of strings
- content as string

Compute SHA-256 of this UTF-8 encoded string. This 32-byte hash is both the event `id` AND the hash that gets signed (Schnorr, BIP-340).

### Event Kinds (MVP)

| Kind | Description | MVP? |
|------|-------------|------|
| 0 | Profile metadata (set_metadata) | Phase 2 |
| 1 | Short text note | YES |
| 3 | Contact list (follow list) | Phase 2 |
| 7 | Reaction (like) | Phase 2 |

MVP supports kind 1 only. The signing mechanism is identical for all kinds.

### nsec / npub Bech32 Encoding

Nostr uses bech32 encoding (NOT bech32m) with these human-readable parts:

```
nsec + <32-byte private key>  = nsec1...
npub + <32-byte x-only pubkey> = npub1...
```

Use a standard bech32 library. Do NOT implement bech32 from scratch.

### Relay Communication (WebSocket)

**Connect:** `wss://relay.example.com`

**Publish event:**
```json
["EVENT", <event JSON object>]
```

**Receive response:**
```json
["OK", "<event_id>", true, ""]           // success
["OK", "<event_id>", false, "error msg"] // failure
```

### Default Relays (MVP)

```
wss://relay.damus.io
wss://relay.nostr.band
wss://nos.lol
wss://relay.snort.social
wss://nostr.wine
```

User can add/remove relays in settings.

---

## SATOCHIP APDU COMMAND MAP (v2.0 REFERENCE -- DO NOT IMPLEMENT YET)

These commands are documented here for completeness. They will be implemented when card support is added in v2.0.

### Applet Selection

```
SELECT Satochip Applet
CLA: 0x00, INS: 0xA4, P1: 0x04, P2: 0x00
Data: 0x53 0x61 0x74 0x6F 0x43 0x68 0x69 0x70  ("SatoChip" in ASCII)
AID: 5361746F43686970
```

### PIN Verification

```
INS_VERIFY_PIN (0x22)
CLA: 0xB0, INS: 0x22, P1: 0x00, P2: 0x00
Data: PIN bytes (4-16 chars, ASCII encoded)
Response: SW1=0x90 SW2=0x00 on success; SW1=0x63 SW2=0xCX on failure (X = remaining tries)
```

### Import Private Key (nsec to card)

```
INS_IMPORT_KEY (0x32)
CLA: 0xB0, INS: 0x32, P1: keyslot (0x00-0x0F), P2: 0x00
Data: 32-byte private key (raw secp256k1 scalar)
Notes: nsec must be bech32-decoded to raw 32 bytes before sending. Up to 16 keyslots.
```

### Get Public Key from Keyslot

```
INS_GET_PUBKEY (0x33)
CLA: 0xB0, INS: 0x33, P1: keyslot, P2: 0x00
Response: 65-byte uncompressed pubkey (04 || x || y)
For Nostr: strip prefix, take first 32 bytes (x-only) = npub
```

### Sign Schnorr Hash (THE CORE COMMAND)

```
INS_SIGN_SCHNORR_HASH (0x74)
CLA: 0xB0, INS: 0x74, P1: keyslot, P2: 0x00
Data: 32-byte hash
Response: 64-byte Schnorr signature (r || s)
Notes: BIP-340 Schnorr, no key tweaking. Suitable for Nostr.
```

### Full Card Signing Flow

```
1. SELECT Satochip applet (AID: 5361746F43686970)
2. INS_INIT_SECURE_CHANNEL (establish encrypted session)
3. INS_VERIFY_PIN (unlock card)
4. [First time] INS_IMPORT_KEY (import nsec to keyslot 0)
5. INS_GET_PUBKEY (get npub from keyslot 0)
6. App constructs Nostr event (NIP-01 format)
7. App computes SHA-256 hash of serialised event
8. INS_SIGN_SCHNORR_HASH (send hash, receive signature)
9. App attaches signature + pubkey to event JSON
10. App broadcasts signed event to relays via WebSocket
```

---

## DESIGN SYSTEM: GHOST

The app uses the "Ghost" aesthetic from HushChip. Dark mode only. No light mode.

### Colour Palette

```swift
// MARK: - Signstr Ghost Palette (identical to HushChip)
extension Color {
    static let sgBg          = Color(hex: "#09090b") // App background
    static let sgBgRaised    = Color(hex: "#0e0e10") // Cards, list items
    static let sgBgSurface   = Color(hex: "#111113") // Card interiors, input backgrounds
    static let sgBorder       = Color(hex: "#1a1a1e") // Default borders, dividers
    static let sgBorderHover  = Color(hex: "#28282e") // Active borders, selected states
    static let sgTextGhost    = Color(hex: "#38383e") // Section labels, placeholders
    static let sgTextFaint    = Color(hex: "#5a5a64") // Secondary text, descriptions
    static let sgTextMuted    = Color(hex: "#8a8a96") // Nav titles, body text
    static let sgTextBody     = Color(hex: "#a8a8b4") // Labels, primary content
    static let sgTextBright   = Color(hex: "#cdcdd6") // Headings, emphasis
    static let sgTextWhite    = Color(hex: "#e4e4ec") // Maximum emphasis (rare)
    static let sgDanger       = Color(hex: "#c45555") // Errors, warnings
    static let sgDangerBorder = Color(hex: "#3d2020") // Warning box borders
    static let sgDangerBg     = Color(red: 60/255, green: 30/255, blue: 30/255, opacity: 0.15)
}
```

### Typography

**Font:** Outfit (bundled in app)
**Weights:** 200 (ultralight), 300 (light), 400 (regular), 500 (medium)

Same usage table as HushChip spine. See HUSHCHIP_IOS_SPINE.md for full typography specs.

### Component Specs

**Cards:** bg #0e0e10, border 1px #1a1a1e, corner radius 12px, padding 16px
**Buttons (primary):** bg #1a1a1e, border #28282e, text #cdcdd6, corner radius 10px, padding 14px, full width, uppercase, 4pt letter-spacing
**Buttons (secondary):** bg transparent, border #28282e, text #a8a8b4
**Buttons (danger):** bg transparent, border #3d1f1f, text #c45555
**Input fields:** bg #0c0c0e, border #1a1a1e, corner radius 8px, text #cdcdd6, placeholder #38383e

---

## APP IDENTITY

- **App name:** Signstr
- **Bundle ID:** uk.co.hushchip.signstr (or com.signstr.app -- TBD)
- **App icon:** To be designed. Dark, minimal, Nostr-suggestive. Lightning bolt or signing motif.
- **Splash screen:** App name "SIGNSTR" in Outfit ultralight, wide letter-spacing. Pulsing dots.
- **Tab bar:** 3 tabs: Sign (pen icon) / Identity (person icon) / Settings (gear icon)
- **About:** "Signstr is a product of Gridmark Technologies Ltd"
- **Website:** signstr.com

---

## SCREEN INVENTORY (v1.0 MVP -- SOFTWARE SIGNER)

| # | Screen | Description |
|---|--------|-------------|
| 0 | Splash | "SIGNSTR" wordmark, loading dots |
| 1 | Onboarding (3 pages) | "Your Nostr identity. Secured." / "Sign events. Never paste your nsec again." / "Face ID protects every signature." |
| 2 | Home / Key Setup | Two paths: "Create new identity" OR "Import existing nsec" |
| 3a | Import nsec | Text field for nsec1... string, paste button, QR scanner |
| 3b | Generate Key | "Generate" button, shows new npub, confirms save |
| 4 | Sign (main tab) | Compose note (kind 1), "Sign & Post" button, relay broadcast status |
| 5 | Identity tab | npub display (truncated + full), npub QR code, copy button |
| 6 | Event History | Local list of recently signed events (timestamp, content preview, relay status) |
| 7 | Relays | List of connected relays, add/remove, connection status dots |
| 8 | Go Air-Gapped | Upsell: explains NostrKey card, "Move your key off this device", link to signstr.com/card |
| 9 | Settings | Biometrics toggle, delete key (danger), relay defaults, about, open source |
| 10 | About / Legal | Logo, version, licence, credits, source link |

### Signing UX Flow (v1.0 -- Software)

```
User writes note --> Taps "Sign & Post" --> Face ID prompt -->
Key decrypted in memory --> Event hashed --> Schnorr signature computed -->
Key zeroed from memory --> Event broadcast to relays -->
Success confirmation with event ID
```

The entire signing operation should feel like 1-2 seconds (Face ID is the bottleneck).

### Signing UX Flow (v2.0 -- Card)

```
User writes note --> Taps "Sign & Post" --> NFC sheet appears -->
User taps NostrKey card --> Card signs hash --> App broadcasts -->
Success confirmation with event ID
```

---

## THE UPSELL: GO AIR-GAPPED

Once a user is happily signing with the software signer, the app surfaces a "Go Air-Gapped" section. This is NOT a popup or nag screen. It is a persistent but unobtrusive card in the Identity tab or Settings.

Content:
- "Your key lives on this device. Want it off?"
- Brief explanation: NostrKey card stores your nsec in a secure element. Key never touches your phone again.
- "Tap to sign. Nothing to hack."
- Link to signstr.com/card to purchase
- Price: GBP 14.99

When the user gets a card and taps "Migrate to card":
1. Face ID unlocks the local nsec
2. NFC session opens
3. nsec imported to card (encrypted over secure channel)
4. Local nsec deleted
5. App switches to CardSigner mode
6. "Go Air-Gapped" card replaced with "Card Connected" status

---

## WHAT TO REMOVE FROM HUSHCHIP APP

1. **All SeedKeeper UI screens** -- secret list, secret detail, add secret, backup wizard, generate password/mnemonic
2. **All HushChip/SeedKeeper branding** -- replace with Signstr everywhere
3. **All Satochip/SeedKeeper links** -- replace with Signstr/HushChip equivalents
4. **Card authenticity check** -- remove (not relevant for v1.0)
5. **Secret type icons** -- remove (no secret types)
6. **Memory donut / card health** -- remove (no card in v1.0)
7. **French language** -- remove. English only for MVP.
8. **"Buy your SeedKeeper" prompts** -- remove all purchase CTAs for Satochip products

## WHAT TO KEEP FROM HUSHCHIP APP (DORMANT)

1. **All NFC/APDU files** -- keep in project, do not import in v1.0 screens
2. **Secure channel code** -- keep for v2.0
3. **PIN verification code** -- keep for v2.0
4. **Ghost design system** -- colours, fonts, components (rebrand prefix from hc to sg)

## WHAT TO ADD

1. **Nostr logic layer** -- event construction, hashing, serialisation
2. **Key storage layer** -- Secure Enclave encryption, Keychain storage
3. **Software signing** -- secp256k1 Schnorr via swift-secp256k1 library
4. **Relay WebSocket manager** -- connect, publish, receive
5. **Bech32 encoding/decoding** -- use a library (e.g. swift-bech32)
6. **QR code display** -- show npub as QR
7. **QR code scanner** -- import nsec from QR (AVFoundation camera)
8. **Compose screen** -- text input + sign button
9. **Event history** -- local storage (UserDefaults or SQLite)
10. **Biometric gating** -- Face ID / Touch ID for every sign operation
11. **Upsell screen** -- NostrKey card promotion

---

## DEPENDENCIES (Swift Packages)

| Package | Purpose | Notes |
|---------|---------|-------|
| swift-secp256k1 | Schnorr signing (BIP-340) | Required for v1.0 software signing |
| swift-bech32 (or equivalent) | nsec/npub encoding/decoding | Standard bech32 (NOT bech32m) |
| Starscream (or URLSessionWebSocketTask) | WebSocket for relay communication | URLSessionWebSocketTask preferred (no dependency) |

Prefer Apple-native solutions where possible. URLSessionWebSocketTask (iOS 13+) eliminates the need for Starscream.

---

## LICENCE COMPLIANCE

Every new or substantially modified Swift file must include this header:

```swift
// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/hushchip/Signstr-iOS
//
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// https://github.com/Toporin/Seedkeeper-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
```

Do NOT remove or modify existing copyright headers in files from the original repo.

---

## DEVELOPMENT PHASES

### Phase 1: Nostr Logic Layer (NO KEY STORAGE YET)
Build and test with MockSigner (hardcoded test key):
- NostrEvent.swift (event construction + serialisation per NIP-01)
- NostrKeyUtils.swift (bech32 nsec/npub encoding/decoding)
- NostrRelay.swift (WebSocket connection + publish)
- NostrRelayPool.swift (multi-relay management)
- NostrEventSerializer.swift (canonical JSON array for hashing)
- MockSigner.swift (in-memory signing with test key)
- SchnorrSigner.swift (secp256k1 Schnorr via swift-secp256k1)
- Unit tests: construct event, hash, sign, verify signature matches NIP-01

### Phase 2: Key Storage + Software Signing
Implement Secure Enclave key storage:
- SecureEnclaveKeyStore.swift (encrypt/decrypt nsec)
- KeyManager.swift (generate, import, delete)
- SoftwareSigner.swift (implements NostrSigner, decrypts key per-sign)
- Biometric gating (Face ID / Touch ID)
- Test: import nsec, lock it, unlock with Face ID, sign event, verify

### Phase 3: UI + Integration
Wire everything together through screens:
- Onboarding, key setup (import or generate)
- Compose screen -> sign -> broadcast
- Identity screen (npub display, QR)
- Relay management
- Event history
- Settings
- Full end-to-end: open app, write note, Face ID, post to Nostr

### Phase 4: Polish + App Store
- Error handling and edge cases
- Upsell screen (Go Air-Gapped / NostrKey card)
- App Store assets, screenshots, description
- App Store submission

### Phase 5: Card Support (v2.0)
Activate dormant NFC/APDU code:
- SatochipCardService.swift (Satochip APDU commands)
- CardSigner.swift (implements NostrSigner via NFC)
- Key migration flow (Secure Enclave -> card)
- PIN entry UI
- NFC tap-to-sign flow
- Test with physical NostrKey card

---

## CURRENT TASK

(Update this section at the start of each Claude Code session to reflect the current task.)

**Current phase:** Phase 1 -- Nostr Logic Layer
**Current task:** Rename fork from HushChip to Signstr, then build NostrEvent, NostrKeyUtils, NostrRelay, MockSigner
**Files being modified:** New files only + branding changes
**Files NOT to touch:** All inherited APDU/NFC files (dormant for v2.0)

---

*This document is the law. When in doubt, refer back here.*
