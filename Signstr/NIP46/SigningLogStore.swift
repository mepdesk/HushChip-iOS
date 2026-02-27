// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  SigningLogStore.swift
//  Signstr — Local event log for NIP-46 signing requests

import Foundation

/// A single signing request log entry.
struct SigningLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let appName: String
    let clientPubkey: String
    let eventKind: Int
    let contentPreview: String
    let approved: Bool
    let eventJSON: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        appName: String,
        clientPubkey: String,
        eventKind: Int,
        contentPreview: String,
        approved: Bool,
        eventJSON: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appName = appName
        self.clientPubkey = clientPubkey
        self.eventKind = eventKind
        self.contentPreview = contentPreview
        self.approved = approved
        self.eventJSON = eventJSON
    }

    var kindDescription: String {
        PendingSigningRequest.humanReadableKind(eventKind)
    }

    var truncatedContent: String {
        if contentPreview.count > 120 {
            return String(contentPreview.prefix(120)) + "..."
        }
        return contentPreview
    }
}

/// Persists signing log entries locally using UserDefaults + JSON.
final class SigningLogStore: ObservableObject {
    static let shared = SigningLogStore()

    private static let storageKey = "signstr.signing_log"

    @Published private(set) var entries: [SigningLogEntry] = []

    private init() {
        entries = Self.loadEntries()
    }

    /// Adds a new log entry and persists.
    func addEntry(_ entry: SigningLogEntry) {
        entries.insert(entry, at: 0) // newest first
        save()
    }

    /// Logs a signing request result.
    func log(
        appName: String,
        clientPubkey: String,
        eventKind: Int,
        content: String,
        approved: Bool,
        eventJSON: String = ""
    ) {
        let entry = SigningLogEntry(
            appName: appName,
            clientPubkey: clientPubkey,
            eventKind: eventKind,
            contentPreview: String(content.prefix(500)),
            approved: approved,
            eventJSON: eventJSON
        )
        addEntry(entry)
    }

    /// Clears all log entries.
    func clearAll() {
        entries.removeAll()
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func loadEntries() -> [SigningLogEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([SigningLogEntry].self, from: data) else {
            return []
        }
        return entries
    }
}
