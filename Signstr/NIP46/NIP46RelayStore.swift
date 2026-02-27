// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  NIP46RelayStore.swift
//  Signstr — Persists the list of relays Signstr listens on for NIP-46 signing requests.

import Foundation

/// Manages the relay list that Signstr uses for NIP-46 communication.
/// Persists to UserDefaults and provides default relays on first launch.
final class NIP46RelayStore: ObservableObject {

    static let shared = NIP46RelayStore()

    private static let storageKey = "signstr.nip46_relays"

    static let defaultRelays: [String] = [
        "wss://relay.nsec.app",
        "wss://relay.damus.io",
        "wss://nos.lol"
    ]

    @Published private(set) var relays: [String] = []

    private init() {
        if let stored = UserDefaults.standard.stringArray(forKey: Self.storageKey) {
            relays = stored
        } else {
            relays = Self.defaultRelays
            save()
        }
    }

    func addRelay(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !relays.contains(trimmed) else { return }
        relays.append(trimmed)
        save()
    }

    func removeRelay(at offsets: IndexSet) {
        relays.remove(atOffsets: offsets)
        save()
    }

    func removeRelay(_ url: String) {
        relays.removeAll { $0 == url }
        save()
    }

    func resetToDefaults() {
        relays = Self.defaultRelays
        save()
    }

    private func save() {
        UserDefaults.standard.set(relays, forKey: Self.storageKey)
    }
}
