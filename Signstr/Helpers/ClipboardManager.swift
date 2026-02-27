// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// https://github.com/Toporin/Seedkeeper-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  ClipboardManager.swift
//  Signstr — Clipboard auto-clear with 30-second timer

import Foundation
import UIKit
import Combine

/// Centralised clipboard manager. Copies text, starts a 30-second clear timer,
/// clears immediately when the app backgrounds, and publishes a toast flag.
///
/// IMPORTANT: Only clears the clipboard if it was populated via `copy(_:)`.
/// Public data copied directly via `UIPasteboard.general.string` (e.g. npub)
/// is NOT cleared on background — only private data (nsec, etc.) is.
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    /// When true the toast overlay should appear briefly.
    @Published var showClearedToast = false

    private var clearTimer: Timer?
    private var backgroundObserver: Any?

    /// True only while we have sensitive data on the clipboard that we put there.
    private var hasSensitiveCopy = false

    private init() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearOnBackground()
        }
    }

    deinit {
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        clearTimer?.invalidate()
    }

    /// Copy sensitive text to the system clipboard and start the 30-second auto-clear.
    /// Only use this for private data (nsec, logs). For public data (npub), use
    /// `UIPasteboard.general.string` directly.
    func copy(_ text: String) {
        UIPasteboard.general.string = text
        hasSensitiveCopy = true

        // Reset timer on every copy
        clearTimer?.invalidate()
        clearTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.clearNow()
            }
        }
    }

    /// Called on app background — only clears if we have an active sensitive copy.
    private func clearOnBackground() {
        guard hasSensitiveCopy else { return }
        clearNow()
    }

    /// Immediately wipe the clipboard and flash the toast.
    private func clearNow() {
        clearTimer?.invalidate()
        clearTimer = nil
        hasSensitiveCopy = false

        guard UIPasteboard.general.hasStrings else { return }
        UIPasteboard.general.string = ""

        showClearedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showClearedToast = false
        }
    }
}
