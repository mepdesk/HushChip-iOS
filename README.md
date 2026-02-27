# Signstr iOS

The first standalone Nostr event signer for iOS. Store your nsec securely, sign events without pasting your key into every client.

**Fork heritage:** Based on [HushChip-iOS](https://github.com/hushchip/HushChip-iOS), itself a fork of [Seedkeeper-iOS](https://github.com/Toporin/Seedkeeper-iOS) by Toporin / Satochip S.R.L.

**Licence:** GPL-3.0

## Two-Tier Signing

**Tier 1 — Software Signer (v1.0):** nsec encrypted via iOS Secure Enclave, decrypted in memory only when signing, then discarded. Face ID gates every signature.

**Tier 2 — Card Signer (v2.0):** nsec migrated to a NostrKey NFC smartcard. Key never touches the phone again. Sign by tap.

## Building

Open `Signstr.xcodeproj` in Xcode 15+. Requires iOS 16.0+.

## Links

- Website: [signstr.com](https://signstr.com)
- Source: [github.com/hushchip/Signstr-iOS](https://github.com/hushchip/Signstr-iOS)
- Upstream: [github.com/Toporin/Seedkeeper-iOS](https://github.com/Toporin/Seedkeeper-iOS)
