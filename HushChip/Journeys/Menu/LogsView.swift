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
//  LogsView.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 21/05/2024.
//

import Foundation
import SwiftUI

struct LogsView: View {
    // MARK: - Properties
    @FetchRequest(sortDescriptors: []) var logEntries: FetchedResults<LogEntry>
    @Binding var homeNavigationPath: NavigationPath

    var body: some View {
        ZStack {
            Color.hcBg.ignoresSafeArea()

            VStack {
                VStack {
                    Spacer()
                        .frame(height: 16)

                    HStack {
                        Text("\(String(localized: "logsNumberOfEntries")) : \(logEntries.count)")
                            .font(.custom("Outfit-Light", size: 12))
                            .fontWeight(.thin)
                            .multilineTextAlignment(.center)
                            .lineSpacing(8)

                        Button(action: {
                            let logEntriesString = logEntries.map { logEntry in
                                let log = LogModel(logEntry: logEntry)
                                return "\(Formatter().dateTimeToString(date: log.date)) - \(log.type) - \(log.message)"
                            }.joined(separator: "\n")

                            ClipboardManager.shared.copy(logEntriesString)
                        }) {
                            Image(systemName: "square.on.square")
                                .resizable()
                                .frame(width: 18, height: 18)
                                .foregroundColor(Color.hcTextMuted)
                        }
                    }


                    Spacer()
                        .frame(height: 16)

                    List {
                        ForEach(logEntries, id: \.date) { logEntry in
                            let log = LogModel(logEntry: logEntry)
                            VStack(alignment: .center) {

                                Text("\(Formatter().dateTimeToString(date: log.date)) - \(log.type)")
                                    .font(.custom("Outfit-Regular", size: 12))
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(8)

                                Text(log.message)
                                    .font(.custom("Outfit-Light", size: 12))
                                    .fontWeight(.thin)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(8)

                            }
                            .padding(8)
                            .listRowBackground(Color.clear)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12,
                                     style: RoundedCornerStyle.continuous)
                        .stroke(Color.hcBorder, lineWidth: 1)
                }
            }
            .padding(32)

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
                Text("LOGS")
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.hcTextMuted)
                    .textCase(.uppercase)
            }
        }
    }
}
