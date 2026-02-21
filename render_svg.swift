#!/usr/bin/env swift
// render_svg.swift — renders an SVG (including feTurbulence filters) via WKWebView
// Usage: swift render_svg.swift <input.svg> <output.png> <size>

import AppKit
import WebKit

let args = CommandLine.arguments
guard args.count == 4,
      let size = Int(args[3]) else {
    print("Usage: render_svg.swift <input.svg> <output.png> <size>")
    exit(1)
}

let svgPath  = (args[1] as NSString).expandingTildeInPath
let outPath  = (args[2] as NSString).expandingTildeInPath
let canvasSize = CGFloat(size)

guard FileManager.default.fileExists(atPath: svgPath) else {
    print("SVG not found: \(svgPath)"); exit(1)
}

// ── AppKit application shell (required for WKWebView) ─────────────────────
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// ── WKWebView setup ───────────────────────────────────────────────────────
let config = WKWebViewConfiguration()
let webView = WKWebView(frame: CGRect(x: 0, y: 0,
                                     width: canvasSize, height: canvasSize),
                        configuration: config)
webView.setValue(false, forKey: "drawsBackground")   // transparent background

// Wrap SVG in minimal HTML so it fills the viewport exactly
let svgData = try! Data(contentsOf: URL(fileURLWithPath: svgPath))
let svgString = String(data: svgData, encoding: .utf8)!
let html = """
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=\(size), initial-scale=1">
<style>
  * { margin:0; padding:0; }
  html, body { width:\(size)px; height:\(size)px; overflow:hidden; background:transparent; }
  svg { display:block; width:\(size)px; height:\(size)px; }
</style>
</head>
<body>\(svgString)</body>
</html>
"""

// ── Navigation delegate — fires snapshot after load ───────────────────────
class Delegate: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let outPath: String
    let size: CGFloat

    init(webView: WKWebView, outPath: String, size: CGFloat) {
        self.webView = webView; self.outPath = outPath; self.size = size
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Brief delay so filters (feTurbulence etc.) finish compositing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let cfg = WKSnapshotConfiguration()
            cfg.rect = CGRect(x: 0, y: 0, width: self.size, height: self.size)
            cfg.snapshotWidth = NSNumber(value: Double(self.size))
            webView.takeSnapshot(with: cfg) { image, error in
                if let err = error { print("Snapshot error: \(err)"); exit(1) }
                guard let img = image else { print("No image"); exit(1) }
                guard let tiff   = img.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let png    = bitmap.representation(using: .png, properties: [:])
                else { print("PNG encode failed"); exit(1) }
                do {
                    try png.write(to: URL(fileURLWithPath: self.outPath))
                    print("✓ Written \(self.outPath)")
                } catch {
                    print("Write error: \(error)"); exit(1)
                }
                NSApplication.shared.terminate(nil)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Load error: \(error)"); exit(1)
    }
}

let delegate = Delegate(webView: webView, outPath: outPath, size: canvasSize)
webView.navigationDelegate = delegate
webView.loadHTMLString(html, baseURL: URL(fileURLWithPath: svgPath).deletingLastPathComponent())

// ── Run the event loop ────────────────────────────────────────────────────
app.run()
