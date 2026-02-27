// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  EventLogView.swift
//  Signstr — Chronological list of all signing requests

import SwiftUI

struct EventLogView: View {
    @ObservedObject private var logStore = SigningLogStore.shared
    @State private var selectedEntry: SigningLogEntry?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            if logStore.entries.isEmpty {
                emptyContent
            } else {
                logListContent
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            dismiss()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                Text("Back")
                    .font(.custom("Outfit-Regular", size: 12))
            }
            .foregroundColor(.sgTextMuted)
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("EVENT LOG")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
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

            Text("Signing requests will appear here as apps request signatures.")
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Log list

    private var logListContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                Text("\(logStore.entries.count) EVENTS")
                    .font(.outfit(.regular, size: 9))
                    .tracking(3)
                    .foregroundColor(.sgTextGhost)

                Spacer().frame(height: 16)

                ForEach(logStore.entries) { entry in
                    Button(action: { selectedEntry = entry }) {
                        logRow(entry)
                    }

                    if entry.id != logStore.entries.last?.id {
                        Rectangle()
                            .fill(Color.sgBorder)
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Log row

    private func logRow(_ entry: SigningLogEntry) -> some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(entry.approved ? Color(hex: "#2d5a3d") : Color.sgDanger.opacity(0.6))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.appName)
                        .font(.outfit(.regular, size: 13))
                        .foregroundColor(.sgTextBright)

                    Spacer()

                    Text(formatTimestamp(entry.timestamp))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.sgTextFaint)
                }

                Text(entry.kindDescription)
                    .font(.outfit(.light, size: 11))
                    .foregroundColor(.sgTextBody)

                if !entry.contentPreview.isEmpty {
                    Text(entry.truncatedContent)
                        .font(.outfit(.light, size: 11))
                        .foregroundColor(.sgTextFaint)
                        .lineLimit(1)
                }

                // Badge
                Text(entry.approved ? "APPROVED" : "REJECTED")
                    .font(.outfit(.regular, size: 8))
                    .tracking(2)
                    .foregroundColor(entry.approved ? Color(hex: "#2d5a3d") : .sgDanger)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (entry.approved ? Color(hex: "#2d5a3d") : Color.sgDanger).opacity(0.15)
                    )
                    .cornerRadius(4)
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

    // MARK: - Helpers

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let time = formatter.string(from: date)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "dd MMM"
        let day = dayFormatter.string(from: date)

        return "\(day) \(time)"
    }
}

// MARK: - Detail view (full event JSON)

struct EventLogDetailView: View {
    let entry: SigningLogEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 24)

                    // Header
                    HStack {
                        Text("EVENT DETAIL")
                            .font(.outfit(.regular, size: 10))
                            .tracking(5)
                            .foregroundColor(.sgTextGhost)

                        Spacer()

                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.sgTextMuted)
                        }
                    }

                    Spacer().frame(height: 24)

                    // Info card
                    VStack(alignment: .leading, spacing: 16) {
                        detailRow(label: "APP", value: entry.appName)

                        detailRow(
                            label: "TIMESTAMP",
                            value: entry.timestamp.formatted(date: .abbreviated, time: .standard)
                        )

                        detailRow(label: "EVENT KIND", value: entry.kindDescription)

                        detailRow(label: "STATUS", value: entry.approved ? "Approved" : "Rejected")

                        if !entry.contentPreview.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CONTENT")
                                    .font(.outfit(.regular, size: 9))
                                    .tracking(3)
                                    .foregroundColor(.sgTextGhost)

                                Text(entry.contentPreview)
                                    .font(.outfit(.light, size: 12))
                                    .foregroundColor(.sgTextBody)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        detailRow(
                            label: "CLIENT PUBKEY",
                            value: entry.clientPubkey
                        )
                    }
                    .padding(Dimensions.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.sgBgRaised)
                    .cornerRadius(Dimensions.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                            .stroke(Color.sgBorder, lineWidth: 1)
                    )

                    // Event JSON (if available)
                    if !entry.eventJSON.isEmpty {
                        Spacer().frame(height: 24)

                        Text("RAW EVENT JSON")
                            .font(.outfit(.regular, size: 9))
                            .tracking(3)
                            .foregroundColor(.sgTextGhost)

                        Spacer().frame(height: 8)

                        Text(prettyJSON(entry.eventJSON))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.sgTextFaint)
                            .padding(Dimensions.cardPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.sgBgSurface)
                            .cornerRadius(Dimensions.cardCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                                    .stroke(Color.sgBorder, lineWidth: 1)
                            )

                        Spacer().frame(height: 12)

                        Button(action: {
                            ClipboardManager.shared.copy(entry.eventJSON)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11))
                                Text("COPY JSON")
                                    .font(.outfit(.regular, size: 10))
                                    .tracking(2)
                            }
                            .foregroundColor(.sgTextMuted)
                        }
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .presentationDetents([.large])
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.outfit(.regular, size: 9))
                .tracking(3)
                .foregroundColor(.sgTextGhost)

            Text(value)
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextBody)
        }
    }

    private func prettyJSON(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
              let str = String(data: pretty, encoding: .utf8) else {
            return json
        }
        return str
    }
}
