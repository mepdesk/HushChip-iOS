// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  EventsTabView.swift
//  Signstr — Events tab: identity-scoped signing history log

import SwiftUI

struct EventsTabView: View {
    @EnvironmentObject var nip46Service: NIP46Service
    @ObservedObject var identityManager = IdentityManager.shared
    @ObservedObject var logStore = SigningLogStore.shared

    @State private var selectedIdentityId: String?
    @State private var selectedEntry: SigningLogEntry?

    private var activeIdentityId: String? {
        selectedIdentityId ?? identityManager.activeIdentity?.id
    }

    private var filteredEntries: [SigningLogEntry] {
        guard let id = activeIdentityId else { return [] }
        return logStore.entries(forIdentity: id)
    }

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            VStack(spacing: 0) {
                if identityManager.hasIdentities {
                    IdentityPickerView(
                        identityManager: identityManager,
                        selectedIdentityId: $selectedIdentityId,
                        onIdentityTap: { _ in },
                        onAddIdentity: nil
                    )
                    .environmentObject(nip46Service)

                    Rectangle()
                        .fill(Color.sgBorder)
                        .frame(height: 1)
                }

                if filteredEntries.isEmpty {
                    emptyContent
                } else {
                    eventList
                }
            }
        }
        .onAppear {
            if selectedIdentityId == nil {
                selectedIdentityId = identityManager.activeIdentity?.id
            }
        }
        .sheet(item: $selectedEntry) { entry in
            EventLogDetailView(entry: entry)
        }
    }

    // MARK: - Empty state

    private var emptyContent: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "list.clipboard")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(.sgTextGhost)

            Text("NO EVENTS")
                .font(.outfit(.regular, size: 11))
                .tracking(5)
                .foregroundColor(.sgTextMuted)

            Text("No signing events yet.\nConnect an app to get started.")
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Event list

    private var eventList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                Spacer().frame(height: 16)

                Text("\(filteredEntries.count) EVENT\(filteredEntries.count == 1 ? "" : "S")")
                    .font(.outfit(.regular, size: 9))
                    .tracking(3)
                    .foregroundColor(.sgTextGhost)

                Spacer().frame(height: 8)

                ForEach(filteredEntries) { entry in
                    Button(action: { selectedEntry = entry }) {
                        eventRow(entry)
                    }
                }

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Event row

    private func eventRow(_ entry: SigningLogEntry) -> some View {
        HStack(spacing: 12) {
            // Status badge
            statusBadge(for: entry)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.kindDescription)
                        .font(.outfit(.regular, size: 13))
                        .foregroundColor(.sgTextBright)

                    Spacer()

                    Text(relativeTimestamp(entry.timestamp))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.sgTextGhost)
                }

                Text(entry.appName)
                    .font(.outfit(.light, size: 11))
                    .foregroundColor(.sgTextFaint)
            }
        }
        .padding(Dimensions.cardPadding)
        .background(Color.sgBgRaised)
        .cornerRadius(Dimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                .stroke(Color.sgBorder, lineWidth: 1)
        )
    }

    // MARK: - Status badge

    private func statusBadge(for entry: SigningLogEntry) -> some View {
        let (text, color) = badgeInfo(for: entry)
        return Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(color)
            .frame(width: 24, height: 24)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }

    private func badgeInfo(for entry: SigningLogEntry) -> (String, Color) {
        if !entry.approved {
            return ("X", Color(hex: "#8a3d3d")) // muted red
        }
        if entry.autoApproved {
            return ("A", Color(hex: "#3d5a8a")) // muted blue
        }
        return ("\u{2713}", Color(hex: "#3d6a4d")) // muted green, checkmark
    }

    // MARK: - Relative timestamp

    private func relativeTimestamp(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 5 { return "now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 7 { return "\(days)d ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: date)
    }
}
