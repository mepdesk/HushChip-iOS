// Copyright (c) 2026 Gridmark Technologies Ltd (HushChip)
// https://github.com/hushchip/HushChip-iOS
//
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// https://github.com/Toporin/Seedkeeper-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  HomeView.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 17/04/2024.
//

import SwiftUI

enum ActionAfterPin {
    case rescanCard
    case continueBackupFlow
}

enum SecretCreationMode {
    case generate
    case manualImport
}

enum NavigationRoutes: Hashable {
    case home
    case onboarding
    case menu
    case settings
    case createPinCode(PinCodeNavigationData)
    case confirmPinCode(PinCodeNavigationData)
    case setupFaceId(FaceIdNavData)
    case logs
    case cardInfo
    case authenticity
    case editPinCode
    case pinCode(ActionAfterPin)
    case addSecret
    case showSecret(SeedkeeperSecretHeaderDto)
    case generateSecretType(SecretCreationMode)
    case generateGenerator(GeneratorModeNavData)
    case generateSuccess(String)
    case about
    case backup
    case backupSuccess
}

struct HomeView: View {
    // MARK: - Properties
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var cardState: CardState

    private var isCardScanned: Bool {
        return cardState.cardStatus != nil && cardState.isPinVerificationSuccess
    }

    @State private var showSetupFlow = false

    // Returns true when the user has NOT yet completed onboarding.
    // On a fresh install the key is absent → bool(forKey:) returns false → !false = true → show onboarding.
    func shouldShowOnboarding() -> Bool {
        return !UserDefaults.standard.bool(forKey: Constants.Keys.onboardingComplete)
    }

    var body: some View {
        NavigationStack(path: $cardState.homeNavigationPath) {
            ZStack {
                Color.hcBg.ignoresSafeArea()

                VStack {
                    HeaderView(homeNavigationPath: $cardState.homeNavigationPath)

                    Spacer()

                    Spacer().frame(height: 16)

                    if isCardScanned {
                        DashboardView(homeNavigationPath: $cardState.homeNavigationPath)
                    } else {
                        EmptyScanStateOverlay(homeNavigationPath: $cardState.homeNavigationPath)
                    }
                }
            }
            .navigationBarTitle("")
            .navigationBarHidden(true)
            .navigationDestination(for: NavigationRoutes.self) { route in
                switch route {
                case .home:
                    HomeView()
                case .onboarding:
                    OnboardingContainerView()
                case .menu:
                    MenuView(homeNavigationPath: $cardState.homeNavigationPath)
                case .settings:
                    SettingsView(homeNavigationPath: $cardState.homeNavigationPath)
                case .createPinCode(let pinCodeNavigationData):
                    CreatePinCodeView(homeNavigationPath: $cardState.homeNavigationPath, pinCodeNavigationData: pinCodeNavigationData)
                case .confirmPinCode(let pinCodeNavigationData):
                    ConfirmPinCodeView(homeNavigationPath: $cardState.homeNavigationPath, pinCodeNavigationData: pinCodeNavigationData)
                case .setupFaceId(let pinCode):
                    SetupFaceIdView(homeNavigationPath: $cardState.homeNavigationPath, navData: pinCode)
                case .pinCode(let action):
                    PinCodeView(homeNavigationPath: $cardState.homeNavigationPath, actionAfterPin: action)
                case .logs:
                    LogsView(homeNavigationPath: $cardState.homeNavigationPath)
                case .cardInfo:
                    CardInfoView(homeNavigationPath: $cardState.homeNavigationPath)
                case .authenticity:
                    AuthenticityView(homeNavigationPath: $cardState.homeNavigationPath)
                case .editPinCode:
                    CreatePinCodeView(homeNavigationPath: $cardState.homeNavigationPath, pinCodeNavigationData: PinCodeNavigationData(mode: .updatePinCodeDefineNew, pinCode: nil))
                case .addSecret:
                    AddSecretView(homeNavigationPath: $cardState.homeNavigationPath)
                case .showSecret(let secret):
                    ShowSecretView(homeNavigationPath: $cardState.homeNavigationPath, secret: secret)
                case .generateSecretType(let mode):
                    GenerateSecretTypeView(homeNavigationPath: $cardState.homeNavigationPath, secretCreationMode: mode)
                case .generateGenerator(let mode):
                    GenerateGeneratorView(homeNavigationPath: $cardState.homeNavigationPath, generatorModeNavData: mode)
                case .generateSuccess(let label):
                    GenerateSuccessView(homeNavigationPath: $cardState.homeNavigationPath, secretLabel: label)
                case .about:
                    AboutView(homeNavigationPath: $cardState.homeNavigationPath)
                case .backup:
                    BackupWizardView(homeNavigationPath: $cardState.homeNavigationPath)
                case .backupSuccess:
                    BackupWizardView(homeNavigationPath: $cardState.homeNavigationPath)
                }
            }
        }
        .onAppear {
            if shouldShowOnboarding() {
                cardState.homeNavigationPath.append(NavigationRoutes.onboarding)
            }
            // Can be used to test logging
            // managedObjectContext.saveLogEntry(log: LogModel(type: .info, message: "Home view loaded"))
        }
    }
}
