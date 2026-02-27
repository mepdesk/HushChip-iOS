// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// https://github.com/Toporin/Seedkeeper-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  OnboardingContainerView.swift
//  Signstr

import Foundation
import SwiftUI

struct OnboardingContainerView: View {
    @EnvironmentObject var cardState: CardState

    /// Called when the user taps "GET STARTED" on the last page.
    var onComplete: () -> Void

    @State private var currentPage = 0

    private let pageCount = 3

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Constants.Keys.onboardingComplete)
        onComplete()
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.sgBg.ignoresSafeArea()

            // Swipeable pages — native page indicator hidden, custom dots used below
            TabView(selection: $currentPage) {
                OnboardingWelcomeView()
                    .tag(0)
                OnboardingInfoView()
                    .tag(1)
                OnboardingNFCView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Bottom bar: dots + action button
            VStack(spacing: 20) {

                // Page dots — active dot is wider capsule
                HStack(spacing: 8) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Capsule()
                            .frame(width: index == currentPage ? 18 : 6, height: 6)
                            .foregroundColor(index == currentPage ? .sgTextMuted : .sgTextGhost)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }

                // Action button
                if currentPage < pageCount - 1 {
                    Button(action: {
                        withAnimation {
                            currentPage = min(currentPage + 1, pageCount - 1)
                        }
                    }) {
                        Text("NEXT")
                            .font(.outfit(.regular, size: 11))
                            .tracking(4)
                            .foregroundColor(.sgTextBright)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.sgBorder)
                            .cornerRadius(Dimensions.buttonCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                                    .stroke(Color.sgBorderHover, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                } else {
                    Button(action: {
                        completeOnboarding()
                    }) {
                        Text("GET STARTED")
                            .font(.outfit(.regular, size: 11))
                            .tracking(4)
                            .foregroundColor(.sgTextBright)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.sgBorder)
                            .cornerRadius(Dimensions.buttonCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                                    .stroke(Color.sgBorderHover, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, Dimensions.defaultBottomMargin)
        }
        .navigationBarBackButtonHidden(true)
    }
}
