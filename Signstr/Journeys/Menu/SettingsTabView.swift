// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// Licensed under GPL-3.0
//
//  SettingsTabView.swift
//  Signstr

import SwiftUI
import LocalAuthentication

struct SettingsTabView: View {
    @EnvironmentObject var cardState: CardState
    @EnvironmentObject var nip46Service: NIP46Service

    @State private var defaultPolicy: ApprovalPolicy = ApprovalPolicyStore.defaultPolicy
    @State private var biometricsEnabled: Bool = true
    @State private var showDeleteKeyConfirm = false
    @State private var showDeleteKeyFinal = false
    @State private var showPolicyPicker = false

    private var biometricTypeName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        @unknown default: return "Biometrics"
        }
    }

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

                        // ── SIGNING section ──
                        sectionLabel("SIGNING")
                        Spacer().frame(height: 8)

                        // Default approval policy picker
                        approvalPolicyRow
                        Spacer().frame(height: 8)

                        // Biometrics toggle
                        biometricsToggleRow
                        Spacer().frame(height: 8)

                        // NIP-46 Relay config
                        settingsRow(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "NIP-46 Relays",
                            subtitle: "\(NIP46RelayStore.shared.relays.count) relay\(NIP46RelayStore.shared.relays.count == 1 ? "" : "s") configured"
                        ) {
                            cardState.homeNavigationPath.append(NavigationRoutes.relayConfig)
                        }

                        Spacer().frame(height: 32)

                        // ── GENERAL section ──
                        sectionLabel("GENERAL")
                        Spacer().frame(height: 8)

                        settingsRow(icon: "list.clipboard", title: "Event Log", subtitle: "Signing request history") {
                            cardState.homeNavigationPath.append(NavigationRoutes.eventLog)
                        }
                        Spacer().frame(height: 8)
                        settingsRow(icon: "doc.text", title: "Debug Logs", subtitle: "View application logs") {
                            cardState.homeNavigationPath.append(NavigationRoutes.logs)
                        }
                        Spacer().frame(height: 8)
                        settingsRow(icon: "info.circle", title: "About", subtitle: "Version, licence, and credits") {
                            cardState.homeNavigationPath.append(NavigationRoutes.about)
                        }

                        Spacer().frame(height: 32)

                        // ── DANGER ZONE section ──
                        dangerSectionLabel("DANGER ZONE")
                        Spacer().frame(height: 8)

                        dangerRow(icon: "exclamationmark.shield", title: "Emergency Export", subtitle: "Reveal nsec with QR code") {
                            cardState.homeNavigationPath.append(NavigationRoutes.emergencyExport)
                        }
                        Spacer().frame(height: 8)

                        dangerRow(icon: "trash", title: "Delete Key", subtitle: "Permanently wipe key from device") {
                            showDeleteKeyConfirm = true
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
                    EmptyView()
                case .logs:
                    LogsView(homeNavigationPath: $cardState.homeNavigationPath)
                case .eventLog:
                    EventLogView()
                case .emergencyExport:
                    EmergencyExportView()
                case .about:
                    AboutView(homeNavigationPath: $cardState.homeNavigationPath)
                case .relayConfig:
                    RelayConfigView()
                }
            }
        }
        .onAppear {
            defaultPolicy = ApprovalPolicyStore.defaultPolicy
            biometricsEnabled = UserDefaults.standard.object(forKey: Constants.Keys.biometricsEnabled) == nil
                ? true
                : UserDefaults.standard.bool(forKey: Constants.Keys.biometricsEnabled)
        }
        .alert("Delete Key?", isPresented: $showDeleteKeyConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Key", role: .destructive) {
                showDeleteKeyFinal = true
            }
        } message: {
            Text("This will permanently delete your Nostr private key from this device. All connected apps will be disconnected. This action cannot be undone.\n\nMake sure you have a backup of your nsec before proceeding.")
        }
        .alert("Are you sure?", isPresented: $showDeleteKeyFinal) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) {
                deleteKeyAndReset()
            }
        } message: {
            Text("This is your last chance. Your key will be wiped and all sessions will be disconnected.")
        }
    }

    // MARK: - Approval policy row

    private var approvalPolicyRow: some View {
        Button(action: { showPolicyPicker = true }) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.sgTextMuted)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Default Approval Policy")
                        .font(.outfit(.regular, size: 13))
                        .foregroundColor(.sgTextBright)

                    Text(defaultPolicy.displayName)
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
        .sheet(isPresented: $showPolicyPicker) {
            defaultPolicyPickerSheet
        }
    }

    // MARK: - Biometrics toggle row

    private var biometricsToggleRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "faceid")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(.sgTextMuted)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(biometricTypeName)
                    .font(.outfit(.regular, size: 13))
                    .foregroundColor(.sgTextBright)

                Text("Require biometrics for signing approval")
                    .font(.outfit(.light, size: 11))
                    .foregroundColor(.sgTextFaint)
            }

            Spacer()

            Toggle("", isOn: $biometricsEnabled)
                .toggleStyle(SKToggleStyle(
                    onColor: Color.sgBorderHover,
                    offColor: Color.sgBgSurface,
                    thumbColor: Color.sgTextMuted
                ))
                .labelsHidden()
                .frame(width: 50)
                .onChange(of: biometricsEnabled) { newValue in
                    UserDefaults.standard.set(newValue, forKey: Constants.Keys.biometricsEnabled)
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

    // MARK: - Default policy picker sheet

    private var defaultPolicyPickerSheet: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 12)

            Capsule()
                .fill(Color.sgBorder)
                .frame(width: 36, height: 4)

            Spacer().frame(height: 24)

            Text("DEFAULT APPROVAL POLICY")
                .font(.outfit(.regular, size: 9))
                .tracking(3)
                .foregroundColor(.sgTextGhost)

            Spacer().frame(height: 8)

            Text("Applied to new connections by default.")
                .font(.outfit(.light, size: 12))
                .foregroundColor(.sgTextFaint)

            Spacer().frame(height: 20)

            VStack(spacing: 0) {
                ForEach(ApprovalPolicy.allCases) { policy in
                    Button(action: {
                        defaultPolicy = policy
                        ApprovalPolicyStore.defaultPolicy = policy
                        showPolicyPicker = false
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(defaultPolicy == policy ? Color.sgTextBright : Color.clear)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle().stroke(
                                        defaultPolicy == policy ? Color.sgTextBright : Color.sgTextGhost,
                                        lineWidth: 1
                                    )
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(policy.displayName)
                                    .font(.outfit(.regular, size: 13))
                                    .foregroundColor(defaultPolicy == policy ? .sgTextBright : .sgTextBody)

                                Text(policy.description)
                                    .font(.outfit(.light, size: 10))
                                    .foregroundColor(.sgTextFaint)
                                    .lineLimit(2)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, Dimensions.cardPadding)
                        .padding(.vertical, 10)
                    }

                    if policy != ApprovalPolicy.allCases.last {
                        Rectangle()
                            .fill(Color.sgBorder)
                            .frame(height: 1)
                            .padding(.horizontal, Dimensions.cardPadding)
                    }
                }
            }
            .background(Color.sgBgRaised)
            .cornerRadius(Dimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                    .stroke(Color.sgBorder, lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color.sgBg)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Delete key

    private func deleteKeyAndReset() {
        // Disconnect all NIP-46 sessions
        nip46Service.disconnectAll()

        // Wipe key from Keychain/Secure Enclave
        try? KeyManager.deleteKey()

        // Clear stored policies and signing log
        UserDefaults.standard.removeObject(forKey: "signstr.approval_policies")
        UserDefaults.standard.removeObject(forKey: "signstr.first_approval_times")

        // Reset key setup flag so onboarding shows key setup
        UserDefaults.standard.set(false, forKey: Constants.Keys.keySetupComplete)

        // Navigate back to key setup by clearing nav path
        cardState.homeNavigationPath = NavigationPath()
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
