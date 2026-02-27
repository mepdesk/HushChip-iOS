// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/hushchip/Signstr-iOS
//
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// https://github.com/Toporin/Seedkeeper-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  SKSecretViewer.swift
//  Signstr
//
//  Created by Lionel Delvaux on 21/06/2024.
//

import Foundation
import SwiftUI
import UIKit
import QRCode

struct SKSecretViewer: View {
    @State private var showText: Bool = false
    @Binding var shouldShowQRCode: Bool
    @Binding var contentText: String
    var isEditable: Bool = false
    var userInputResult: ((String) -> Void)? = nil

    var contentTextClear: String {
        return showText ? contentText : String(repeating: "*", count: contentText.count)
    }

    public func getQRfromText(text: String) -> CGImage? {
        do {
            let doc = try QRCode.Document(utf8String: text, errorCorrection: .high)
            doc.design.foregroundColor(Color.sgBorder.cgColor!)
            doc.design.backgroundColor(Color.sgBgSurface.cgColor!)
            let generated = try doc.cgImage(CGSize(width: 200, height: 200))
            return generated
        } catch {
            return nil
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Dimensions.cardCornerRadius)
                .fill(Color.sgBgSurface)

            VStack {
                if !shouldShowQRCode {
                    HStack {
                        Spacer()
                        Button(action: {
                            ClipboardManager.shared.copy(contentText)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            Image(systemName: "square.on.square")
                                .foregroundColor(.sgTextBright)
                                .padding(5)
                        }
                        Button(action: {
                            showText.toggle()
                        }) {
                            Image(systemName: showText ? "eye.slash" : "eye")
                                .foregroundColor(.sgTextBright)
                                .padding(5)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.trailing, 10)
                }

                Spacer()

                if isEditable {
                    TextField("", text: $contentText, onEditingChanged: { (editingChanged) in
                        if editingChanged {
                        } else {
                            userInputResult?(contentText)
                        }

                    })
                        .padding()
                        .background(.clear)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if shouldShowQRCode {
                        if let cgImage = self.getQRfromText(text: contentText) {
                            Image(uiImage: UIImage(cgImage: cgImage))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 219, height: 219, alignment: .center)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    } else {
                        Text(contentTextClear)
                            .foregroundColor(.sgTextBright)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                }

                Spacer()
            }
        }
        .frame(width: .infinity, height: .infinity)
    }
}
