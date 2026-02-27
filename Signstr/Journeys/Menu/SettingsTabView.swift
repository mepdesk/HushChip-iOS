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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 32)

                        Image(systemName: "gearshape")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundColor(.sgTextGhost)

                        Spacer().frame(height: 12)

                        Text("SETTINGS")
                            .font(.custom("Outfit-Regular", size: 10))
                            .tracking(5)
                            .foregroundColor(.sgTextGhost)

                        Spacer().frame(height: 32)

                        // General section
                        sectionLabel("GENERAL")
                        Spacer().frame(height: 8)
                        settingsRow(icon: "list.clipboard", title: "Event Log", subtitle: "Signing request history") {
                            cardState.homeNavigationPath.append(NavigationRoutes.eventLog)
                        }
                        Spacer().frame(height: 8)
                        settingsRow(icon: "key.viewfinder", title: "Back Up Key", subtitle: "Export your nsec securely") {
                            cardState.homeNavigationPath.append(NavigationRoutes.backUpKey)
                        }
                        Spacer().frame(height: 8)
                        settingsRow(icon: "doc.text", title: "Debug Logs", subtitle: "View application logs") {
                            cardState.homeNavigationPath.append(NavigationRoutes.logs)
                        }
                        Spacer().frame(height: 8)
                        settingsRow(icon: "info.circle", title: "About", subtitle: "Version and licence info") {
                            cardState.homeNavigationPath.append(NavigationRoutes.about)
                        }

                        Spacer().frame(height: 32)

                        // Danger zone
                        dangerSectionLabel("DANGER ZONE")
                        Spacer().frame(height: 8)
                        dangerRow(icon: "exclamationmark.shield", title: "Emergency Export", subtitle: "Reveal nsec with QR code") {
                            cardState.homeNavigationPath.append(NavigationRoutes.emergencyExport)
                        }

                        Spacer().frame(height: 60)
                    }
                    .padding(.horizontal, 24)
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
                case .backUpKey:
                    BackUpKeyView(isPostSetup: false)
                case .logs:
                    LogsView(homeNavigationPath: $cardState.homeNavigationPath)
                case .eventLog:
                    EventLogView()
                case .emergencyExport:
                    EmergencyExportView()
                case .about:
                    AboutView(homeNavigationPath: $cardState.homeNavigationPath)
                }
            }
        }
    }

    // MARK: - Section labels

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.outfit(.regular, size: 9))
            .tracking(3)
            .foregroundColor(.sgTextGhost)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }

    private func dangerSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.outfit(.regular, size: 9))
            .tracking(3)
            .foregroundColor(.sgDanger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }

    // MARK: - Settings row

    private func settingsRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.sgTextMuted)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.outfit(.regular, size: 13))
                        .foregroundColor(.sgTextBright)

                    Text(subtitle)
                        .font(.outfit(.light, size: 11))
                        .foregroundColor(.sgTextFaint)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.sgTextGhost)
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

    // MARK: - Danger row

    private func dangerRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.sgDanger)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.outfit(.regular, size: 13))
                        .foregroundColor(.sgDanger)

                    Text(subtitle)
                        .font(.outfit(.light, size: 11))
                        .foregroundColor(.sgTextFaint)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.sgTextGhost)
            }
            .padding(Dimensions.cardPadding)
            .background(Color.sgDangerBg)
            .cornerRadius(Dimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                    .stroke(Color.sgDangerBorder, lineWidth: 1)
            )
        }
    }
}
