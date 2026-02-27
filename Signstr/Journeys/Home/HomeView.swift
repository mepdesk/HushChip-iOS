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
    case connections
    case identity
    case settings
}

// MARK: - Root tab container

struct HomeView: View {
    @EnvironmentObject var cardState: CardState
    @EnvironmentObject var nip46Service: NIP46Service

    @State private var selectedTab: AppTab = .connections
    @State private var showOnboarding = false
    @State private var showKeySetup = false

    private func needsOnboarding() -> Bool {
        return !UserDefaults.standard.bool(forKey: Constants.Keys.onboardingComplete)
    }

    private func needsKeySetup() -> Bool {
        return !UserDefaults.standard.bool(forKey: Constants.Keys.keySetupComplete)
            && !KeyManager.keyExists()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ConnectionsTabView()
                .tag(AppTab.connections)
                .tabItem {
                    Image(systemName: "link")
                    Text("Connections")
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
                showOnboarding = true
            } else if needsKeySetup() {
                showKeySetup = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingContainerView(onComplete: {
                showOnboarding = false
                if needsKeySetup() {
                    showKeySetup = true
                }
            })
            .environmentObject(cardState)
        }
        .fullScreenCover(isPresented: $showKeySetup) {
            NavigationStack(path: $cardState.homeNavigationPath) {
                KeySetupView()
                    .navigationDestination(for: NavigationRoutes.self) { route in
                        switch route {
                        case .generateKey: GenerateKeyView()
                        case .importNsec: ImportNsecView()
                        default: EmptyView()
                        }
                    }
            }
            .environmentObject(cardState)
            .environmentObject(nip46Service)
            .preferredColorScheme(.dark)
            .onChange(of: cardState.homeNavigationPath) { newPath in
                // GenerateKeyView/ImportNsecView clear the path after saving the key
                if newPath.isEmpty && KeyManager.keyExists() {
                    showKeySetup = false
                }
            }
        }
    }
}
