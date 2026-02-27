// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// Licensed under GPL-3.0
//
//  SettingsTabView.swift
//  Signstr

import SwiftUI

struct SettingsTabView: View {
    @EnvironmentObject var cardState: CardState

    var body: some View {
        NavigationStack(path: $cardState.homeNavigationPath) {
            ZStack {
                Color.sgBg.ignoresSafeArea()

                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "gearshape")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(.sgTextGhost)

                    Text("SETTINGS")
                        .font(.custom("Outfit-Regular", size: 11))
                        .tracking(5)
                        .foregroundColor(.sgTextMuted)

                    Text("Relay config, keys, and preferences will appear here")
                        .font(.outfit(.light, size: 13))
                        .foregroundColor(.sgTextFaint)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .navigationDestination(for: NavigationRoutes.self) { route in
                switch route {
                case .onboarding:
                    OnboardingContainerView(onComplete: {})
                case .keySetup:
                    KeySetupView()
                case .generateKey:
                    GenerateKeyView()
                case .importNsec:
                    ImportNsecView()
                case .logs:
                    LogsView(homeNavigationPath: $cardState.homeNavigationPath)
                case .about:
                    AboutView(homeNavigationPath: $cardState.homeNavigationPath)
                }
            }
        }
    }
}
