// Copyright (c) 2026 Gridmark Technologies Ltd (HushChip)
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// Licensed under GPL-3.0
//
//
//  HushChipApp.swift
//  HushChip
//
//  Created by Lionel Delvaux on 17/04/2024.
//

import SwiftUI

@main
struct HushChipApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var dataController = DataController.shared
    @StateObject var cardState = CardState()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeView()
                    .environment(\.managedObjectContext, dataController.container.viewContext)
                    .environmentObject(cardState)
                    .preferredColorScheme(.dark)
                    .background(Color.hcBg.ignoresSafeArea())
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
