// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  RelayConfigView.swift
//  Signstr — NIP-46 relay configuration: add, remove, reset to defaults.

import SwiftUI

struct RelayConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var relayStore = NIP46RelayStore.shared

    @State private var newRelayURL = ""
    @State private var showAddField = false
    @State private var showResetConfirm = false

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 32)

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(.sgTextGhost)

                    Spacer().frame(height: 12)

                    Text("NIP-46 RELAYS")
                        .font(.outfit(.regular, size: 10))
                        .tracking(5)
                        .foregroundColor(.sgTextGhost)

                    Spacer().frame(height: 8)

                    Text("Signstr listens on these relays for signing requests from connected apps.")
                        .font(.outfit(.light, size: 12))
                        .foregroundColor(.sgTextFaint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    Spacer().frame(height: 28)

                    // Relay list
                    relayListCard

                    Spacer().frame(height: 16)

                    // Add relay
                    if showAddField {
                        addRelayCard
                    } else {
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showAddField = true } }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .regular))
                                Text("ADD RELAY")
                                    .font(.outfit(.regular, size: 11))
                                    .tracking(3)
                            }
                            .foregroundColor(.sgTextMuted)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Color.sgBgRaised)
                            .cornerRadius(Dimensions.cardCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                                    .stroke(Color.sgBorder, lineWidth: 1)
                            )
                        }
                    }

                    Spacer().frame(height: 24)

                    // Reset to defaults
                    Button(action: { showResetConfirm = true }) {
                        Text("RESET TO DEFAULTS")
                            .font(.outfit(.regular, size: 9))
                            .tracking(3)
                            .foregroundColor(.sgTextFaint)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
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
                Text("RELAYS")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.sgTextMuted)
                    .textCase(.uppercase)
            }
        }
        .alert("Reset Relays", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                relayStore.resetToDefaults()
            }
        } message: {
            Text("This will replace your relay list with the default relays.")
        }
    }

    // MARK: - Relay list

    private var relayListCard: some View {
        VStack(spacing: 0) {
            if relayStore.relays.isEmpty {
                HStack {
                    Text("No relays configured")
                        .font(.outfit(.light, size: 12))
                        .foregroundColor(.sgTextFaint)
                    Spacer()
                }
                .padding(Dimensions.cardPadding)
            } else {
                ForEach(Array(relayStore.relays.enumerated()), id: \.element) { index, relay in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.sgBorderHover)
                            .frame(width: 6, height: 6)

                        Text(relay.replacingOccurrences(of: "wss://", with: ""))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.sgTextBody)

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                relayStore.removeRelay(relay)
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(.sgTextGhost)
                                .frame(width: 28, height: 28)
                        }
                    }
                    .padding(.horizontal, Dimensions.cardPadding)
                    .padding(.vertical, 10)

                    if index < relayStore.relays.count - 1 {
                        Rectangle()
                            .fill(Color.sgBorder)
                            .frame(height: 1)
                            .padding(.horizontal, Dimensions.cardPadding)
                    }
                }
            }
        }
        .background(Color.sgBgRaised)
        .cornerRadius(Dimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                .stroke(Color.sgBorder, lineWidth: 1)
        )
    }

    // MARK: - Add relay

    private var addRelayCard: some View {
        VStack(spacing: 12) {
            TextField("wss://relay.example.com", text: $newRelayURL)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.sgTextBody)
                .padding(12)
                .background(Color.sgBgSurface)
                .cornerRadius(Dimensions.inputCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Dimensions.inputCornerRadius)
                        .stroke(Color.sgBorder, lineWidth: 1)
                )
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)

            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAddField = false
                        newRelayURL = ""
                    }
                }) {
                    Text("CANCEL")
                        .font(.outfit(.regular, size: 9))
                        .tracking(3)
                        .foregroundColor(.sgTextFaint)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Color.sgBgSurface)
                        .cornerRadius(Dimensions.buttonCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                                .stroke(Color.sgBorder, lineWidth: 1)
                        )
                }

                Button(action: {
                    var url = newRelayURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !url.hasPrefix("wss://") && !url.hasPrefix("ws://") {
                        url = "wss://\(url)"
                    }
                    relayStore.addRelay(url)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        newRelayURL = ""
                        showAddField = false
                    }
                }) {
                    Text("ADD")
                        .font(.outfit(.regular, size: 9))
                        .tracking(3)
                        .foregroundColor(.sgTextBright)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Color.sgBorder)
                        .cornerRadius(Dimensions.buttonCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                                .stroke(Color.sgBorderHover, lineWidth: 1)
                        )
                }
                .disabled(newRelayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(newRelayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
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
}
