#!/usr/bin/env swift
// generate_icon.swift — generates HushChip 1024x1024 app icon
// Run: swift generate_icon.swift

import AppKit
import CoreText
import CoreGraphics

// ── helpers ──────────────────────────────────────────────────────────────────

func hex(_ h: UInt32, alpha: CGFloat = 1.0) -> NSColor {
    let r = CGFloat((h >> 16) & 0xff) / 255
    let g = CGFloat((h >>  8) & 0xff) / 255
    let b = CGFloat( h        & 0xff) / 255
    return NSColor(red: r, green: g, blue: b, alpha: alpha)
}

// ── font loading ──────────────────────────────────────────────────────────────

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent()
let fontURL = scriptDir
    .appendingPathComponent("HushChip/Resources/Fonts/Outfit-ExtraLight.ttf")

var fontError: Unmanaged<CFError>?
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &fontError)
if let err = fontError { print("Font warning: \(err.takeRetainedValue())") }

// ── canvas ────────────────────────────────────────────────────────────────────

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    print("No CGContext"); exit(1)
}

// 1. Background — #09090b
ctx.setFillColor(hex(0x09090b).cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// ── Card ──────────────────────────────────────────────────────────────────────

let cardW: CGFloat = 820
let cardH: CGFloat = 820
let cardX: CGFloat = (size - cardW) / 2
let cardY: CGFloat = (size - cardH) / 2
let cardRect = CGRect(x: cardX, y: cardY, width: cardW, height: cardH)
let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 80, cornerHeight: 80, transform: nil)

// 2. Card gradient — #12121a (top) → #0e0e10 (bottom), clipped to card shape
ctx.saveGState()
ctx.addPath(cardPath)
ctx.clip()

let gradColors = [hex(0x12121a).cgColor, hex(0x0e0e10).cgColor] as CFArray
let gradLocs: [CGFloat] = [0.0, 1.0]
if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                         colors: gradColors, locations: gradLocs) {
    // CG origin is bottom-left, so "top" = cardY+cardH, "bottom" = cardY
    ctx.drawLinearGradient(grad,
        start: CGPoint(x: cardX + cardW / 2, y: cardY + cardH),
        end:   CGPoint(x: cardX + cardW / 2, y: cardY),
        options: [])
}
ctx.restoreGState()

// 3. Grain / noise texture — overlaid on card at low opacity
//    Generate a 256×256 grayscale noise tile, then draw it tiled & scaled over
//    the card, clipped to the card path, at ~8% opacity.
//    Using a seeded LCG so the result is deterministic.
let noiseSize = 256
var lcgState: UInt64 = 0xdeadbeef_cafef00d
func lcgNext() -> UInt8 {
    lcgState = lcgState &* 6364136223846793005 &+ 1442695040888963407
    return UInt8((lcgState >> 33) & 0xff)
}

var grainPixels = [UInt8](repeating: 0, count: noiseSize * noiseSize)
for i in 0 ..< grainPixels.count {
    grainPixels[i] = lcgNext()
}

if let grainProvider = CGDataProvider(data: Data(grainPixels) as CFData),
   let grainCGImage = CGImage(width: noiseSize, height: noiseSize,
                              bitsPerComponent: 8, bitsPerPixel: 8,
                              bytesPerRow: noiseSize,
                              space: CGColorSpaceCreateDeviceGray(),
                              bitmapInfo: CGBitmapInfo(rawValue: 0),
                              provider: grainProvider,
                              decode: nil, shouldInterpolate: true,
                              intent: .defaultIntent) {

    ctx.saveGState()
    ctx.addPath(cardPath)
    ctx.clip()
    ctx.setAlpha(0.08)   // matte PVC grain — subtle, not harsh

    // Tile the noise across the card in a 4×4 grid of ~256pt squares
    let tileSize: CGFloat = CGFloat(noiseSize)
    let tilesX = Int(ceil(cardW / tileSize)) + 1
    let tilesY = Int(ceil(cardH / tileSize)) + 1
    for ty in 0 ..< tilesY {
        for tx in 0 ..< tilesX {
            let tileRect = CGRect(
                x: cardX + CGFloat(tx) * tileSize,
                y: cardY + CGFloat(ty) * tileSize,
                width: tileSize, height: tileSize)
            ctx.draw(grainCGImage, in: tileRect)
        }
    }
    ctx.restoreGState()
}

// 4. Card border — 1px edge highlight (#1a1a1e) for dimensionality
ctx.setStrokeColor(hex(0x1a1a1e).cgColor)
ctx.setLineWidth(1.5)
ctx.addPath(cardPath)
ctx.strokePath()

// ── EMV chip ──────────────────────────────────────────────────────────────────

// 5. Chip body — #b8993e
let chipW: CGFloat = 310
let chipH: CGFloat = 238
let chipX: CGFloat = (size - chipW) / 2
let chipY: CGFloat = (size - chipH) / 2 + 40
let chipPath = CGPath(roundedRect: CGRect(x: chipX, y: chipY, width: chipW, height: chipH),
                      cornerWidth: 18, cornerHeight: 18, transform: nil)
ctx.setFillColor(hex(0xb8993e).cgColor)
ctx.addPath(chipPath)
ctx.fillPath()

// 6. Chip contact grid lines — #8a6e22
ctx.setStrokeColor(hex(0x8a6e22).cgColor)
ctx.setLineWidth(2.0)

ctx.move(to: CGPoint(x: chipX + chipW / 2, y: chipY + 6))
ctx.addLine(to: CGPoint(x: chipX + chipW / 2, y: chipY + chipH - 6))
ctx.strokePath()

let topLineY = chipY + chipH * (1.0 / 3.0)
ctx.move(to: CGPoint(x: chipX + 6, y: topLineY))
ctx.addLine(to: CGPoint(x: chipX + chipW - 6, y: topLineY))
ctx.strokePath()

let bottomLineY = chipY + chipH * (2.0 / 3.0)
ctx.move(to: CGPoint(x: chipX + 6, y: bottomLineY))
ctx.addLine(to: CGPoint(x: chipX + chipW - 6, y: bottomLineY))
ctx.strokePath()

// 7. "HUSH" text — Outfit ExtraLight 68pt, wide tracking, rgba(255,255,255,0.14)
let atts: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Outfit-ExtraLight", size: 68) ?? NSFont.systemFont(ofSize: 68, weight: .ultraLight),
    .foregroundColor: NSColor.white.withAlphaComponent(0.14),
    .kern: NSNumber(value: 20.0)
]
let label = NSAttributedString(string: "HUSH", attributes: atts)
let labelSize = label.size()
let labelX = (size - labelSize.width) / 2
let labelY = chipY - labelSize.height - 22
label.draw(at: NSPoint(x: labelX, y: labelY))

// ── export ────────────────────────────────────────────────────────────────────

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to encode PNG"); exit(1)
}

let outURL = scriptDir
    .appendingPathComponent("HushChip/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
do {
    try png.write(to: outURL)
    print("✓ AppIcon.png written to \(outURL.path)")
} catch {
    print("Write error: \(error)"); exit(1)
}
