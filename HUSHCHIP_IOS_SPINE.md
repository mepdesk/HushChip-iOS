# HUSHCHIP iOS APP -- CLAUDE CODE SPINE DOCUMENT

**INCLUDE THIS DOCUMENT AT THE START OF EVERY CLAUDE CODE SESSION.**

This is the single source of truth for the HushChip iOS app project. It tells you what this project is, what you can change, what you MUST NOT change, and the design system to follow.

---

## WHAT IS THIS PROJECT

HushChip is a rebranded fork of the open-source SeedKeeper iOS app (github.com/Toporin/Seedkeeper-iOS). It is a companion app for a physical NFC smart card that stores secrets (seed phrases, passwords, etc.) on a PIN-protected secure element.

The app communicates with the card via NFC using APDU commands. The card runs an unmodified JavaCard applet. The app is a UI wrapper around the card's APDU protocol.

**Original repo:** github.com/Toporin/Seedkeeper-iOS (Swift, GPL-3.0, 12 commits)
**Original Xcode project:** Seedkeeper.xcodeproj, main source in `Seedkeeper/` folder
**Licence:** GPL-3.0 (must remain GPL-3.0, source must be public)

---

## THE GOLDEN RULE

```
┌─────────────────────────────────────────────────┐
│                                                 │
│   DO NOT MODIFY THE APDU / NFC / CARD           │
│   COMMUNICATION LAYER.                          │
│                                                 │
│   If a file sends bytes to the card or          │
│   parses bytes from the card, DO NOT TOUCH IT.  │
│                                                 │
│   If you are unsure whether something is part   │
│   of the APDU layer, ASK before changing it.    │
│                                                 │
└─────────────────────────────────────────────────┘
```

### What Counts as the APDU / Card Communication Layer

Any code that does ANY of the following is OFF LIMITS:

- Builds APDU command byte arrays (CLA, INS, P1, P2, data, Le)
- Parses APDU response byte arrays (SW1, SW2, response data)
- Manages the NFC session lifecycle (NFCTagReaderSession)
- Sends commands to the card via CoreNFC (sendCommand / send)
- Implements the secure channel (ECDH key exchange, AES-128-CBC encryption)
- Handles BIP39 wordlist validation or mnemonic-to-seed conversion
- Implements the card-to-card encrypted backup protocol
- Handles PIN verification protocol with the card
- Manages card authentication (authentikey, PKI certificates)

### What You CAN Freely Change

- All SwiftUI views, screens, layouts, colours, fonts, spacing
- All string literals (app name, labels, descriptions, error messages)
- All asset files (icons, images, colours in asset catalogs)
- App icon, splash screen, launch storyboard
- Info.plist (bundle ID, app name, version)
- Xcode project settings (signing, capabilities, scheme names)
- Navigation flow and screen routing
- Adding entirely new screens that only call existing card functions
- Adding app-side-only features (clipboard timer, haptics, biometrics, local storage)

### The Architecture

```
HushChip iOS App
│
├── UI Layer ← CHANGE EVERYTHING HERE
│   ├── Views / Screens (SwiftUI)
│   ├── Theme (colours, fonts, spacing)
│   ├── Assets (icons, images, app icon)
│   ├── Strings / Localisation
│   └── Navigation / Routing
│
├── Business Logic ← CHANGE CAREFULLY
│   ├── ViewModels / State management
│   ├── Password generator (can enhance)
│   ├── Clipboard manager (add auto-clear)
│   ├── Local storage (card nicknames, tags)
│   └── Feature flags (remove auth check)
│
├── APDU Layer ← DO NOT CHANGE
│   ├── Card communication (APDU builders/parsers)
│   ├── NFC session handler
│   ├── Secure channel (ECDH + AES)
│   ├── BIP39 wordlist + validation
│   ├── Encrypted backup protocol
│   └── PIN verification protocol
│
└── Platform Layer ← MINIMAL CHANGES (fix bugs only)
    ├── CoreNFC integration (may need iOS compatibility fix)
    ├── Biometrics (add new - LocalAuthentication framework)
    └── Haptics (add new - UIFeedbackGenerator)
```

---

## IDENTIFYING APDU LAYER FILES

When you first explore the codebase, you need to identify which files belong to the APDU layer. Look for these patterns:

**APDU layer indicators (DO NOT MODIFY):**
- Files/classes containing "APDU", "CardChannel", "CardManager", "NFCSession"
- Files importing `CoreNFC` that handle `NFCISO7816Tag` or `NFCISO7816APDU`
- Files containing hex byte arrays like `[0x00, 0xA4, 0x04, 0x00]`
- Files referencing INS codes: `INS_SETUP`, `INS_VERIFY_PIN`, `INS_IMPORT_SECRET`, etc.
- Files handling `secp256k1`, ECDH, AES encryption for secure channel
- Files with BIP39 word lists or mnemonic validation
- Any file that directly calls `tag.sendCommand()` or similar NFC send methods

**UI layer indicators (SAFE TO MODIFY):**
- SwiftUI `View` structs
- Files primarily containing layout code (`VStack`, `HStack`, `List`, etc.)
- `Color`, `Font`, image asset references
- Navigation / routing logic
- String constants and localisation files
- ViewModel/ObservableObject classes (modify presentation logic, not card calls)

**When in doubt:** Read the file. If it constructs byte arrays or parses raw bytes from the card, leave it alone. If it shows things on screen or handles user input, it is safe to change.

---

## DESIGN SYSTEM: GHOST

The app uses the "Ghost" aesthetic. Dark mode only. No light mode. No accent colour. Greyscale only.

### Colour Palette

```swift
// MARK: - HushChip Ghost Palette
extension Color {
    static let hcBg          = Color(hex: "#09090b") // App background
    static let hcBgRaised    = Color(hex: "#0e0e10") // Cards, list items
    static let hcBgSurface   = Color(hex: "#111113") // Card interiors, input backgrounds
    static let hcBorder       = Color(hex: "#1a1a1e") // Default borders, dividers
    static let hcBorderHover  = Color(hex: "#28282e") // Active borders, selected states
    static let hcTextGhost    = Color(hex: "#38383e") // Section labels, placeholders
    static let hcTextFaint    = Color(hex: "#5a5a64") // Secondary text, descriptions
    static let hcTextMuted    = Color(hex: "#8a8a96") // Nav titles, body text
    static let hcTextBody     = Color(hex: "#a8a8b4") // Secret labels, primary content
    static let hcTextBright   = Color(hex: "#cdcdd6") // Headings, emphasis
    static let hcTextWhite    = Color(hex: "#e4e4ec") // Maximum emphasis (rare)
    static let hcDanger       = Color(hex: "#c45555") // Wrong PIN, delete, warnings
    static let hcDangerBorder = Color(hex: "#3d2020") // Warning box borders
    static let hcDangerBg     = Color(red: 60/255, green: 30/255, blue: 30/255, opacity: 0.15)
}
```

The palette has a very slight cool blue-grey undertone. The only non-grey element in the entire app is the gold EMV chip on the app icon and splash screen.

### Typography

**Font:** Outfit (must be bundled in app, not loaded from CDN)
**Weights:** 200 (ultralight), 300 (light), 400 (regular), 500 (medium)

```swift
// MARK: - HushChip Typography
// Register Outfit font files in Info.plist under "Fonts provided by application"
extension Font {
    static func outfit(_ weight: Font.Weight, size: CGFloat) -> Font {
        let name: String
        switch weight {
        case .ultraLight: name = "Outfit-ExtraLight"  // 200
        case .light:      name = "Outfit-Light"       // 300
        case .regular:    name = "Outfit-Regular"     // 400
        case .medium:     name = "Outfit-Medium"      // 500
        default:          name = "Outfit-Regular"
        }
        return .custom(name, size: size)
    }
}
```

**Usage by element:**

| Element | Weight | Size | Letter Spacing | Transform |
|---------|--------|------|---------------|-----------|
| Nav title | 400 | 11 | 5pt | uppercase |
| Nav button | 400 | 10 | 2pt | uppercase |
| Section label | 400 | 9 | 3pt | uppercase |
| Card title / secret name | 400 | 12 | 0 | none |
| Body text | 300 | 11-12 | 0 | none |
| Onboarding heading | 300 | 16 | 0.5pt | none |
| Input text | 300 | 13 | 0 | none |
| Button text | 400 | 11 | 4pt | uppercase |
| Tab bar label | 400 | 8 | 1pt | uppercase |
| Tag badge | 400 | 9 | 1pt | uppercase |
| Counter text | 400 | 9 | 1-2pt | uppercase |
| Monospace (fingerprints) | system mono | 9-10 | 0 | none |

### Component Specs

**Cards:** bg #0e0e10, border 1px #1a1a1e, corner radius 12px, padding 16px
**Buttons (primary):** bg #1a1a1e, border #28282e, text #cdcdd6, corner radius 10px, padding 14px, full width, uppercase, 4pt letter-spacing
**Buttons (secondary):** bg transparent, border #28282e, text #a8a8b4
**Buttons (danger):** bg transparent, border #3d1f1f, text #c45555
**Input fields:** bg #0c0c0e, border #1a1a1e, corner radius 8px, text #cdcdd6, placeholder #38383e
**Warning boxes:** border #3d2020, bg rgba(60,30,30,0.15), text #c45555, corner radius 8px

### Navigation

**Top nav bar:** Sticky, blurred background rgba(9,9,11,0.85), border-bottom rgba(26,26,30,0.6), ~62px height
**Tab bar (bottom):** 3 tabs -- Card, Generate, Settings. Active: opacity 1 icon #8a8a96. Inactive: opacity 0.35. Icons 18x18 stroke-width 1.5. Labels 8px uppercase.

---

## WHAT TO REMOVE FROM THE SEEDKEEPER APP

1. **Card authenticity check** -- HushChip cards will FAIL this (no Satochip PKI certificate). Remove the feature entirely from Settings and any automatic check on card connection.
2. **All "SeedKeeper" text** -- Replace with "HushChip" everywhere in user-facing strings.
3. **All "Satochip" text** -- Remove from user-facing UI. Keep ONLY in About/Legal screen as attribution.
4. **Satochip links** -- Remove all links to satochip.io, seedkeeper.io, Satochip Telegram/Twitter. Replace with HushChip equivalents.
5. **"Buy your SeedKeeper" prompts** -- Remove all purchase CTAs for Satochip products.
6. **French language** -- Remove for MVP. English only.
7. **Debug mode in main settings** -- Move to hidden gesture (tap version number 7 times).

## WHAT TO ADD

1. **HushChip branding** -- Ghost palette, Outfit font, card-mark logo, gold chip app icon
2. **3-screen onboarding** -- "Your secrets. On a chip." / "Tap. Store. Done." / "Your PIN is everything."
3. **Prominent PIN warning** -- Red warning box during setup requiring user confirmation
4. **Clipboard auto-clear** -- 30 second timer after copying secrets, with notification
5. **Haptic feedback** -- On NFC detect, PIN entry, success, error (see haptic map below)
6. **About/Legal screen** -- GPL-3.0 notice, credit to Toporin/Satochip, link to github.com/hushchip
7. **Better error messages** -- Human-readable NFC errors, PIN attempt warnings
8. **Card health screen** -- Memory donut chart + stats (secrets count, memory, PIN tries, applet version)

### Haptic Feedback Map

| Action | iOS Implementation |
|--------|-------------------|
| Card detected (NFC) | UIImpactFeedbackGenerator(.medium) |
| PIN dot entered | UIImpactFeedbackGenerator(.light) |
| Wrong PIN | UINotificationFeedbackGenerator(.error) |
| PIN accepted | UINotificationFeedbackGenerator(.success) |
| Secret saved | UINotificationFeedbackGenerator(.success) |
| Secret copied | UIImpactFeedbackGenerator(.light) |
| Delete confirm | UINotificationFeedbackGenerator(.warning) |
| Factory reset | UIImpactFeedbackGenerator(.heavy) |

---

## APP IDENTITY

- **App name:** HushChip
- **Bundle ID:** uk.co.hushchip.app (or as decided)
- **App icon:** Gold EMV chip centred on dark card surface, "HUSH" text at 15% white below chip
- **Splash screen:** Gold chip + "HUSH" + "HUSHCHIP" wordmark + pulsing dots. First-launch: diagonal glisten animation.
- **Tab bar:** Card (card icon) / Generate (clock-circle icon) / Settings (person icon)
- **About:** "HushChip is a trading name of Gridmark Technologies Ltd"

---

## SECRET TYPE ICONS

Text-based icons in rounded squares (28x28px, bg #111113, border #1a1a1e, radius 6px):

| Type | Icon Text | Colour |
|------|-----------|--------|
| BIP39 Mnemonic | Aa | #5a5a64 |
| Password | (filled circle) | #5a5a64 |
| Wallet Descriptor | { } | #5a5a64 |
| Free Text | T | #5a5a64 |
| 2FA Secret | 2F | #5a5a64 |
| Master Seed | S | #5a5a64 |

---

## LICENCE COMPLIANCE

Every new or substantially modified Swift file must include this header:

```swift
// Copyright (c) 2026 Gridmark Technologies Ltd (HushChip)
// https://github.com/hushchip/HushChip-iOS
//
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// https://github.com/Toporin/Seedkeeper-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
```

Do NOT remove or modify existing copyright headers in files from the original repo. Add the HushChip header above the original one.

---

## SCREEN INVENTORY (MVP)

| # | Screen | Description |
|---|--------|-------------|
| 0 | Splash | Gold chip, "HUSH", wordmark, loading dots. Glisten on first launch. |
| 1 | Onboarding (3 pages) | Swipeable. "Your secrets. On a chip." / "Tap. Store. Done." / "Your PIN is everything." |
| 2 | Home: Tap Your Card | NFC ripple pulse, "Tap your card" text, tab bar visible |
| 3a | PIN Entry: Unlock | Lock icon, dot row, tries counter, system keyboard |
| 3b | PIN Entry: Wrong | Red state, shake dots, warning at <=3 tries |
| 3c | PIN Entry: Setup | New PIN + confirm + card name + red warning box |
| 4 | Secret List | Search, health bar, secret rows with type icons |
| 5 | Secret Detail | Metadata card, reveal/QR/copy buttons |
| 6 | Secret Revealed | Word grid (mnemonic) or monospace (password), red warning, auto-hide 60s |
| 7a | Add Secret: Type Selector | 5 type cards |
| 7b | Add Secret: Mnemonic | Word grid, BIP39 autocomplete, export rights toggle |
| 7c | Add Secret: Password | Label + password + login + URL |
| 7d | Add Secret: Free Text | Label + multiline text |
| 8 | Generate: Password | Display, length slider, character toggles |
| 8 | Generate: Mnemonic | 12/24 toggle, word grid |
| 9 | Backup Wizard | 3-step progress, NFC ripple, per-secret progress |
| 10 | Settings | Grouped rows, danger zone with factory reset |
| 11 | Card Health | Memory donut, stats table |
| 12 | About / Legal | Logo, version, licence, credits, source link |

---

## CURRENT TASK

(Update this section at the start of each Claude Code session to reflect the current task.)

**Current phase:** [PHASE NUMBER]
**Current task:** [DESCRIPTION]
**Files being modified:** [LIST]
**Files NOT to touch:** [LIST]

---

*This document is the law. When in doubt, refer back here.*
