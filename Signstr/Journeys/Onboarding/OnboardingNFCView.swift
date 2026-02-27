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
//  OnboardingNFCView.swift
//  Signstr — Onboarding Screen 3: "Face ID protects every signature."

import Foundation
import SwiftUI

// MARK: - Face ID illustration

/// Face ID icon built from SwiftUI primitives.
private struct FaceIDIllustration: View {

    var body: some View {
        ZStack {
            // Rounded frame corners (Face ID bracket style)
            FaceIDBrackets()
                .stroke(Color.sgBorderHover, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 88, height: 88)

            // Face features
            VStack(spacing: 10) {
                // Eyes
                HStack(spacing: 22) {
                    // Left eye
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.sgBorderHover)
                            .frame(width: 6, height: 6)
                    }
                    // Right eye
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.sgBorderHover)
                            .frame(width: 6, height: 6)
                    }
                }

                // Nose line
                NosePath()
                    .stroke(Color.sgBorderHover, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 6, height: 10)

                // Mouth arc
                MouthArc()
                    .stroke(Color.sgBorderHover, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 20, height: 6)
            }
        }
        .frame(width: 120, height: 120)
    }
}

/// Corner brackets (Face ID scan frame).
private struct FaceIDBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corner: CGFloat = 16
        let len: CGFloat = 20

        // Top-left
        path.move(to: CGPoint(x: 0, y: len))
        path.addLine(to: CGPoint(x: 0, y: corner))
        path.addQuadCurve(to: CGPoint(x: corner, y: 0), control: .zero)
        path.addLine(to: CGPoint(x: len, y: 0))

        // Top-right
        path.move(to: CGPoint(x: rect.maxX - len, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: corner), control: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: len))

        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - corner, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))

        // Bottom-left
        path.move(to: CGPoint(x: len, y: rect.maxY))
        path.addLine(to: CGPoint(x: corner, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY - corner), control: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY - len))

        return path
    }
}

/// A small vertical L-shaped nose line.
private struct NosePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

/// A small upward-curving mouth arc.
private struct MouthArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: 0),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

// MARK: - Screen 3

struct OnboardingNFCView: View {

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Illustration ────────────────────────────────────────
            FaceIDIllustration()

            Spacer().frame(height: 44)

            // ── Heading ─────────────────────────────────────────────
            Text("Face ID protects every signature.")
                .font(.outfit(.light, size: 20))
                .tracking(0.3)
                .foregroundColor(.sgTextBright)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 24)

            // ── Info box ────────────────────────────────────────────
            Text("Every time you sign an event, Face ID confirms it's really you. Your key is never exposed.")
                .font(.outfit(.light, size: 12))
                .foregroundColor(.sgTextMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.sgBgRaised)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.sgBorder, lineWidth: 1)
                )
                .padding(.horizontal, 32)

            Spacer()
            // Reserve space for the bottom bar (dots + button)
            Spacer().frame(height: 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sgBg)
    }
}
