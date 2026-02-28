// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// Licensed under GPL-3.0
//
//
//  SignstrApp.swift
//  Signstr
//
//  Created by Lionel Delvaux on 17/04/2024.
//

import SwiftUI

@main
struct SignstrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var dataController = DataController.shared
    @StateObject var cardState = CardState()
    @StateObject var nip46Service = NIP46Service(signer: SoftwareSigner())
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeView()
                    .environment(\.managedObjectContext, dataController.container.viewContext)
                    .environmentObject(cardState)
                    .environmentObject(nip46Service)
                    .preferredColorScheme(.dark)
                    .background(Color.sgBg.ignoresSafeArea())
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                }

                // Clipboard auto-clear toast (always on top)
                ClipboardToast()
            }
            .preferredColorScheme(.dark)
            .onAppear {
                // Migrate existing single key to multi-identity system
                let im = IdentityManager.shared
                if !im.hasIdentities && SecureEnclaveKeyStore.hasStoredKey() {
                    im.migrateExistingKey()
                    if let firstId = im.identities.first?.id {
                        im.migrateExistingConnections(identityId: firstId)
                    }
                }

                // Ensure per-identity approval policies are persisted
                // (fills in defaults for identities created before this feature)
                im.migrateApprovalPolicies()

                nip46Service.restoreConnections()

                // Fetch Nostr profile metadata (picture, name) for all identities
                NostrProfileFetcher.shared.fetchAllProfiles()

                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
