// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// Licensed under GPL-3.0
//
//  HomeView.swift
//  Signstr

import SwiftUI

// MARK: - Navigation routes (slim v1.0 set)

enum NavigationRoutes: Hashable {
    case onboarding
    case keySetup
    case generateKey
    case importNsec
    case logs
    case about
}

// MARK: - Tab selection

enum AppTab: Int, Hashable {
    case sign
    case identity
    case settings
}

// MARK: - Root tab container

struct HomeView: View {
    @EnvironmentObject var cardState: CardState

    @State private var selectedTab: AppTab = .sign

    private func needsOnboarding() -> Bool {
        return !UserDefaults.standard.bool(forKey: Constants.Keys.onboardingComplete)
    }

    private func needsKeySetup() -> Bool {
        return !UserDefaults.standard.bool(forKey: Constants.Keys.keySetupComplete)
            && !KeyManager.keyExists()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SignTabView()
                .tag(AppTab.sign)
                .tabItem {
                    Image(systemName: "signature")
                    Text("Sign")
                }

            IdentityTabView()
                .tag(AppTab.identity)
                .tabItem {
                    Image(systemName: "key")
                    Text("Identity")
                }

            SettingsTabView()
                .tag(AppTab.settings)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
        .tint(.sgTextBright)
        .onAppear {
            // Ghost-themed tab bar
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.sgBg)

            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.sgTextGhost)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(Color.sgTextGhost),
                .font: UIFont(name: "Outfit-Regular", size: 10) ?? .systemFont(ofSize: 10)
            ]
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.sgTextBright)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(Color.sgTextBright),
                .font: UIFont(name: "Outfit-Regular", size: 10) ?? .systemFont(ofSize: 10)
            ]

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance

            if needsOnboarding() {
                // Show onboarding first; it chains to key setup
                cardState.homeNavigationPath.append(NavigationRoutes.onboarding)
                selectedTab = .settings
            } else if needsKeySetup() {
                // Onboarding done but no key yet
                cardState.homeNavigationPath.append(NavigationRoutes.keySetup)
                selectedTab = .settings
            }
        }
    }
}
