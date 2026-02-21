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
//  SettingsView.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 17/04/2024.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    struct dimensions {
        static let verticalGroupSeparator: CGFloat = 24
        static let verticalInsideGroupSeparator: CGFloat = 5
    }
    // MARK: - Properties
    @Binding var homeNavigationPath: NavigationPath

    @State var expertModeIsOn: Bool = false
    @State var debugModeIsOn: Bool = false

    // MARK: - Literals
    let title = "settings"
    let showLogsButtonTitle = String(localized: "settings.showLogs")

    var body: some View {

            ZStack {
                Color.hcBg.ignoresSafeArea()

                VStack {
                    Spacer()
                        .frame(height: 16)

                    Image("il_settings")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 139)

                    Spacer()
                        .frame(height: SettingsView.dimensions.verticalGroupSeparator)

                    // Replay onboarding
                    Button(action: {
                        UserDefaults.standard.set(false, forKey: Constants.Keys.onboardingComplete)
                        homeNavigationPath.append(NavigationRoutes.onboarding)
                    }) {
                        HStack {
                            SatoText(text: "Replay onboarding", style: .subtitleBold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.hcTextGhost)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 55, maxHeight: 55)
                        .background(Color.hcBgSurface)
                        .cornerRadius(Dimensions.cardCornerRadius)
                    }

                    Spacer()
                        .frame(height: SettingsView.dimensions.verticalGroupSeparator)

                    SatoText(text: "settings.expertMode", style: .SKMenuItemTitle)
                    Spacer()
                        .frame(height: SettingsView.dimensions.verticalInsideGroupSeparator)
                    SatoText(text: "settings.expertModeSubtitle", style: .SKMenuItemSubtitle)
                    Spacer()
                        .frame(height: SettingsView.dimensions.verticalInsideGroupSeparator)
                    SettingsToggle(title: "settings.expertMode",
                                   backgroundColor: Color.hcBgSurface,
                                   isOn: $expertModeIsOn,
                                   onToggle: { newValue in

                    })

                    Spacer()
                        .frame(height: SettingsView.dimensions.verticalGroupSeparator)

                    SatoText(text: "settings.debugMode", style: .SKMenuItemTitle)
                    Spacer()
                        .frame(height: SettingsView.dimensions.verticalInsideGroupSeparator)
                    SatoText(text: "settings.debugModeSubtitle", style: .SKMenuItemSubtitle)
                    Spacer()
                        .frame(height: SettingsView.dimensions.verticalInsideGroupSeparator)
                    SettingsToggle(title: "settings.debugMode",
                                   backgroundColor: Color.hcBgSurface,
                                   isOn: $debugModeIsOn,
                                   onToggle: { newValue in

                    })

                    Spacer()
                        .frame(height: SettingsView.dimensions.verticalGroupSeparator)

                    SKButton(text: showLogsButtonTitle, style: .inform) {
                        homeNavigationPath.append(NavigationRoutes.logs)
                    }

                    Spacer()
                }
                .padding([.leading, .trailing], 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: Button(action: {
                homeNavigationPath.removeLast()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Back")
                        .font(.custom("Outfit-Regular", size: 12))
                }
                .foregroundColor(.hcTextMuted)
            })
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SETTINGS")
                        .font(.custom("Outfit-Regular", size: 11))
                        .tracking(5)
                        .foregroundColor(.hcTextMuted)
                        .textCase(.uppercase)
                }
            }
    }
}

struct SettingsToggle: View {
    let title: String
    let backgroundColor: Color
    @Binding var isOn: Bool
    var onToggle: (Bool) -> Void

    var body: some View {
        HStack {
            Toggle(isOn: $isOn){
                SatoText(text: title, style: .subtitleBold)
            }
            .toggleStyle(SKToggleStyle(onColor: Color.hcBorderHover, offColor: Color.hcBgRaised, thumbColor: Color.hcTextMuted))
            .onChange(of: isOn) { newValue in
                onToggle(newValue)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 55, maxHeight: 55)
        .background(backgroundColor)
        .cornerRadius(Dimensions.cardCornerRadius)
    }
}

struct SKToggleStyle: ToggleStyle {

    var onColor: Color
    var offColor: Color
    var thumbColor: Color

    func makeBody(configuration: Self.Configuration) -> some View {
        HStack {
            configuration.label
                .font(.body)
            Spacer()
            RoundedRectangle(cornerRadius: 16, style: .circular)
                .fill(configuration.isOn ? onColor : offColor)
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(thumbColor)
                        .padding(2)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.2)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}
