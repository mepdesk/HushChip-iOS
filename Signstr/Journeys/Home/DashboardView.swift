// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/hushchip/Signstr-iOS
//
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// https://github.com/Toporin/Seedkeeper-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  DashboardView.swift
//  Signstr
//
//  Created by Lionel Delvaux on 04/05/2024.
//

import Foundation
import SwiftUI
import SatochipSwift
import CryptoSwift

struct SeedkeeperSecretHeaderDto: Hashable {

    public static let HEADER_SIZE = 13

    public var sid = 0
    public var type = SeedkeeperSecretType.defaultType
    public var subtype: UInt8 = UInt8(0) // todo:
    public var origin = SeedkeeperSecretOrigin.plainImport
    public var exportRights = SeedkeeperExportRights.exportPlaintextAllowed
    public var nbExportPlaintext: UInt8 = UInt8(0)
    public var nbExportEncrypted: UInt8 = UInt8(0)
    public var useCounter: UInt8 = UInt8(0)
    public var rfu2: UInt8 = UInt8(0) // currently not used
    public var fingerprintBytes = [UInt8](repeating: 0, count: 4)
    public var label = ""

    public init(secretHeader: SeedkeeperSecretHeader) {
        self.sid = secretHeader.sid
        self.type = secretHeader.type
        self.subtype = secretHeader.subtype
        self.origin = secretHeader.origin
        self.exportRights = secretHeader.exportRights
        self.nbExportPlaintext = secretHeader.nbExportPlaintext
        self.nbExportEncrypted = secretHeader.nbExportEncrypted
        self.useCounter = secretHeader.useCounter
        self.rfu2 = secretHeader.rfu2
        self.fingerprintBytes = secretHeader.fingerprintBytes
        self.label = secretHeader.label
    }

    func toSeedkeeperSecretHeader() -> SeedkeeperSecretHeader {
        return SeedkeeperSecretHeader(sid: sid,
                                       type: type,
                                       subtype: subtype,
                                       origin: origin,
                                       exportRights: exportRights,
                                       nbExportPlaintext: nbExportPlaintext,
                                       nbExportEncrypted: nbExportEncrypted,
                                       useCounter: useCounter,
                                       rfu2: rfu2,
                                       fingerprintBytes: fingerprintBytes,
                                       label: label)
    }
}

// MARK: - Secret type icon text helper

private func secretTypeIconText(for type: SeedkeeperSecretType) -> String {
    switch type {
    case .bip39Mnemonic:
        return "Aa"
    case .password, .masterPassword:
        return "\u{25CF}" // filled circle
    case .walletDescriptor:
        return "{ }"
    case .data:
        return "T"
    case .secret2FA:
        return "2F"
    case .masterseed:
        return "S"
    default:
        return "?"
    }
}

private func secretTypeDisplayName(for type: SeedkeeperSecretType) -> String {
    switch type {
    case .bip39Mnemonic:
        return "BIP39 Mnemonic"
    case .password:
        return "Password"
    case .masterPassword:
        return "Master Password"
    case .walletDescriptor:
        return "Wallet Descriptor"
    case .data:
        return "Free Text"
    case .secret2FA:
        return "2FA Secret"
    case .masterseed:
        return "Master Seed"
    case .electrumMnemonic:
        return "Electrum Mnemonic"
    case .privkey:
        return "Private Key"
    case .pubkey, .pubkeyAuthenticated:
        return "Public Key"
    case .key:
        return "Key"
    case .certificate:
        return "Certificate"
    case .shamirSecretShare:
        return "Shamir Share"
    default:
        return "Secret"
    }
}

// MARK: - DashboardView

struct DashboardView: View {
    @EnvironmentObject var cardState: CardState
    @Binding var homeNavigationPath: NavigationPath
    @State private var searchText: String = ""

    private var filteredSecrets: [SeedkeeperSecretHeaderDto] {
        if searchText.isEmpty {
            return cardState.masterSecretHeaders
        }
        return cardState.masterSecretHeaders.filter {
            $0.label.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var secretCount: Int {
        cardState.masterSecretHeaders.count
    }

    // Estimate memory usage based on secret count (no card API for this)
    private var memoryUsedPercent: Int {
        let maxSecrets = 16
        let pct = min(100, (secretCount * 100) / max(1, maxSecrets))
        return pct
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Card health bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.sgBgSurface)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.sgBorderHover)
                                .frame(width: geo.size.width * CGFloat(memoryUsedPercent) / 100.0, height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text("\(secretCount) SECRETS \u{00B7} \(memoryUsedPercent)% MEMORY USED")
                        .font(.custom("Outfit-Light", size: 10))
                        .tracking(2)
                        .foregroundColor(.sgTextFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Dimensions.lateralPadding)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.sgTextGhost)
                        .font(.system(size: 13))
                    TextField("", text: $searchText, prompt: Text("Search secrets").foregroundColor(.sgTextGhost))
                        .font(.custom("Outfit-Light", size: 13))
                        .foregroundColor(.sgTextBright)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.sgBgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.sgBorder, lineWidth: 1)
                )
                .cornerRadius(8)
                .padding(.horizontal, Dimensions.lateralPadding)
                .padding(.bottom, 12)

                // Secret list or empty state
                if cardState.masterSecretHeaders.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("No secrets stored")
                            .font(.custom("Outfit-Light", size: 13))
                            .foregroundColor(.sgTextFaint)
                        Text("Tap + to add your first secret")
                            .font(.custom("Outfit-Light", size: 11))
                            .foregroundColor(.sgTextGhost)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredSecrets, id: \.self) { secret in
                            SecretRowView(secret: secret)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    homeNavigationPath.append(NavigationRoutes.showSecret(secret))
                                }
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: Dimensions.lateralPadding, bottom: 4, trailing: Dimensions.lateralPadding))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .refreshable {
                        Task {
                            cardState.scan()
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }

            // Floating action button
            Button(action: {
                homeNavigationPath.append(NavigationRoutes.addSecret)
            }) {
                Text("+")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.sgTextBright)
                    .frame(width: 52, height: 52)
                    .background(Color.sgBgRaised)
                    .overlay(
                        Circle()
                            .stroke(Color.sgBorderHover, lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .padding(.trailing, Dimensions.lateralPadding)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Secret Row

private struct SecretRowView: View {
    let secret: SeedkeeperSecretHeaderDto

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Text(secretTypeIconText(for: secret.type))
                .font(.custom("Outfit-Regular", size: 11))
                .foregroundColor(.sgTextFaint)
                .frame(width: 28, height: 28)
                .background(Color.sgBgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.sgBorder, lineWidth: 1)
                )
                .cornerRadius(6)

            // Label + type name
            VStack(alignment: .leading, spacing: 2) {
                Text(secret.label)
                    .font(.custom("Outfit-Regular", size: 12))
                    .foregroundColor(.sgTextBody)
                    .lineLimit(1)
                Text(secretTypeDisplayName(for: secret.type))
                    .font(.custom("Outfit-Light", size: 10))
                    .foregroundColor(.sgTextFaint)
                    .lineLimit(1)
            }

            Spacer()

            // Chevron
            Text("\u{203A}")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.sgTextGhost)
        }
        .padding(16)
        .background(Color.sgBgRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.sgBorder, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}
