// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  ApprovalPolicy.swift
//  Signstr — Per-app trust/approval policy for NIP-46 signing requests

import Foundation

/// How Signstr handles incoming signing requests from a connected app.
enum ApprovalPolicy: String, Codable, CaseIterable, Identifiable {
    case alwaysAsk          = "always_ask"
    case trustForSession    = "trust_session"
    case trustFor15Min      = "trust_15min"
    case trustFor1Hour      = "trust_1hour"
    case trustFor4Hours     = "trust_4hours"
    case trustFor24Hours    = "trust_24hours"
    case trustFor7Days      = "trust_7days"
    case alwaysTrust        = "always_trust"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alwaysAsk:       return "Always Ask"
        case .trustForSession: return "Trust for Session"
        case .trustFor15Min:   return "Trust for 15 min"
        case .trustFor1Hour:   return "Trust for 1 hour"
        case .trustFor4Hours:  return "Trust for 4 hours"
        case .trustFor24Hours: return "Trust for 24 hours"
        case .trustFor7Days:   return "Trust for 7 days"
        case .alwaysTrust:     return "Always Trust"
        }
    }

    var description: String {
        switch self {
        case .alwaysAsk:
            return "Every signing request shows approval UI. Most secure."
        case .trustForSession:
            return "Auto-approve after first approval until Signstr is closed."
        case .trustFor15Min:
            return "Auto-approve for 15 minutes, then require approval again."
        case .trustFor1Hour:
            return "Auto-approve for 1 hour, then require approval again."
        case .trustFor4Hours:
            return "Auto-approve for 4 hours, then require approval again."
        case .trustFor24Hours:
            return "Auto-approve for 24 hours, then require approval again."
        case .trustFor7Days:
            return "Auto-approve for 7 days, then require approval again."
        case .alwaysTrust:
            return "Auto-approve everything from this app. Not recommended."
        }
    }

    /// Duration in seconds for timed trust policies. nil = not time-based.
    var trustDuration: TimeInterval? {
        switch self {
        case .alwaysAsk:       return nil
        case .trustForSession: return nil
        case .trustFor15Min:   return 15 * 60
        case .trustFor1Hour:   return 60 * 60
        case .trustFor4Hours:  return 4 * 60 * 60
        case .trustFor24Hours: return 24 * 60 * 60
        case .trustFor7Days:   return 7 * 24 * 60 * 60
        case .alwaysTrust:     return nil
        }
    }
}

// MARK: - Per-app policy storage

/// Persists approval policies per connected app (keyed by client pubkey).
enum ApprovalPolicyStore {
    private static let storageKey = "signstr.approval_policies"
    private static let firstApprovalKey = "signstr.first_approval_times"

    /// Returns the stored policy for a client, or `.alwaysAsk` if none set.
    static func policy(for clientPubkey: String) -> ApprovalPolicy {
        guard let dict = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String],
              let raw = dict[clientPubkey],
              let policy = ApprovalPolicy(rawValue: raw) else {
            return .alwaysAsk
        }
        return policy
    }

    /// Stores a policy for a connected app.
    static func setPolicy(_ policy: ApprovalPolicy, for clientPubkey: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String]) ?? [:]
        dict[clientPubkey] = policy.rawValue
        UserDefaults.standard.set(dict, forKey: storageKey)
    }

    /// Removes the stored policy for a client (on disconnect).
    static func removePolicy(for clientPubkey: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String]) ?? [:]
        dict.removeValue(forKey: clientPubkey)
        UserDefaults.standard.set(dict, forKey: storageKey)

        // Also clear first-approval timestamp
        var times = (UserDefaults.standard.dictionary(forKey: firstApprovalKey) as? [String: Double]) ?? [:]
        times.removeValue(forKey: clientPubkey)
        UserDefaults.standard.set(times, forKey: firstApprovalKey)
    }

    // MARK: - Timed trust tracking

    /// Records the timestamp when the user first approved a request for this session.
    static func recordFirstApproval(for clientPubkey: String) {
        var times = (UserDefaults.standard.dictionary(forKey: firstApprovalKey) as? [String: Double]) ?? [:]
        if times[clientPubkey] == nil {
            times[clientPubkey] = Date().timeIntervalSince1970
            UserDefaults.standard.set(times, forKey: firstApprovalKey)
        }
    }

    /// Returns the first-approval timestamp for a client, if any.
    static func firstApprovalTime(for clientPubkey: String) -> Date? {
        guard let times = UserDefaults.standard.dictionary(forKey: firstApprovalKey) as? [String: Double],
              let ts = times[clientPubkey] else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    /// Clears the first-approval timestamp (e.g., on session restart or policy change).
    static func clearFirstApproval(for clientPubkey: String) {
        var times = (UserDefaults.standard.dictionary(forKey: firstApprovalKey) as? [String: Double]) ?? [:]
        times.removeValue(forKey: clientPubkey)
        UserDefaults.standard.set(times, forKey: firstApprovalKey)
    }

    /// Checks whether a request from this client should be auto-approved.
    static func shouldAutoApprove(for clientPubkey: String) -> Bool {
        let policy = self.policy(for: clientPubkey)

        switch policy {
        case .alwaysAsk:
            return false

        case .alwaysTrust:
            return true

        case .trustForSession:
            // Auto-approve if user approved at least once this session
            return firstApprovalTime(for: clientPubkey) != nil

        case .trustFor15Min, .trustFor1Hour, .trustFor4Hours, .trustFor24Hours, .trustFor7Days:
            guard let firstApproval = firstApprovalTime(for: clientPubkey),
                  let duration = policy.trustDuration else { return false }
            return Date().timeIntervalSince(firstApproval) < duration
        }
    }
}
