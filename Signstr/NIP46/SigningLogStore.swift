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
    let autoApproved: Bool
    /// True when auto-approved specifically because the event kind is in the safe set (0, 3, 10002).
    let safeKindAutoApproved: Bool
    let eventJSON: String
    /// Identity UUID that owns this signing event (nil for legacy entries).
    let identityId: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        appName: String,
        clientPubkey: String,
        eventKind: Int,
        contentPreview: String,
        approved: Bool,
        autoApproved: Bool = false,
        safeKindAutoApproved: Bool = false,
        eventJSON: String = "",
        identityId: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appName = appName
        self.clientPubkey = clientPubkey
        self.eventKind = eventKind
        self.contentPreview = contentPreview
        self.approved = approved
        self.autoApproved = autoApproved
        self.safeKindAutoApproved = safeKindAutoApproved
        self.eventJSON = eventJSON
        self.identityId = identityId
    }

    // Backwards-compatible decoding: older entries may lack newer fields.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        appName = try container.decode(String.self, forKey: .appName)
        clientPubkey = try container.decode(String.self, forKey: .clientPubkey)
        eventKind = try container.decode(Int.self, forKey: .eventKind)
        contentPreview = try container.decode(String.self, forKey: .contentPreview)
        approved = try container.decode(Bool.self, forKey: .approved)
        autoApproved = try container.decodeIfPresent(Bool.self, forKey: .autoApproved) ?? false
        safeKindAutoApproved = try container.decodeIfPresent(Bool.self, forKey: .safeKindAutoApproved) ?? false
        eventJSON = try container.decode(String.self, forKey: .eventJSON)
        identityId = try container.decodeIfPresent(String.self, forKey: .identityId)
    }

    var kindDescription: String {
        PendingSigningRequest.humanReadableKind(eventKind)
    }

    var statusBadge: String {
        if !approved { return "REJECTED" }
        if safeKindAutoApproved { return "SAFE-AUTO" }
        if autoApproved { return "AUTO-APPROVED" }
        return "APPROVED"
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

    /// Adds a new log entry and persists. Caps at 200 entries per identity.
    func addEntry(_ entry: SigningLogEntry) {
        entries.insert(entry, at: 0) // newest first

        // Cap at 200 entries per identity
        if let identityId = entry.identityId {
            var count = 0
            entries.removeAll { e in
                guard e.identityId == identityId else { return false }
                count += 1
                return count > 200
            }
        }

        save()
    }

    /// Logs a signing request result.
    func log(
        appName: String,
        clientPubkey: String,
        eventKind: Int,
        content: String,
        approved: Bool,
        autoApproved: Bool = false,
        safeKindAutoApproved: Bool = false,
        eventJSON: String = "",
        identityId: String? = nil
    ) {
        let entry = SigningLogEntry(
            appName: appName,
            clientPubkey: clientPubkey,
            eventKind: eventKind,
            contentPreview: String(content.prefix(500)),
            approved: approved,
            autoApproved: autoApproved,
            safeKindAutoApproved: safeKindAutoApproved,
            eventJSON: eventJSON,
            identityId: identityId
        )
        addEntry(entry)
    }

    /// Returns entries for a specific identity, newest first.
    func entries(forIdentity identityId: String) -> [SigningLogEntry] {
        entries.filter { $0.identityId == identityId }
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
