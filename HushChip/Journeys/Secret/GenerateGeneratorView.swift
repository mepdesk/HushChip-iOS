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
//  GenerateMnemonicView.swift
//  Seedkeeper
//
//  Created by Lionel Delvaux on 07/05/2024.
//

import Foundation
import SwiftUI
import UIKit
import SatochipSwift
import MnemonicSwift

// MARK: - Ghost-styled input field

private struct GhostTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @State private var showText: Bool = false

    var body: some View {
        HStack {
            if isSecure && !showText {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.hcTextGhost))
                    .font(.custom("Outfit-Light", size: 13))
                    .foregroundColor(.hcTextBright)
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.hcTextGhost))
                    .font(.custom("Outfit-Light", size: 13))
                    .foregroundColor(.hcTextBright)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            if isSecure {
                Button(action: { showText.toggle() }) {
                    Image(systemName: showText ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                        .foregroundColor(.hcTextGhost)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.hcBgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.hcBorder, lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

// MARK: - Ghost-styled section label

private struct GhostSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.custom("Outfit-Regular", size: 9))
            .tracking(3)
            .foregroundColor(.hcTextGhost)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GenerateGeneratorView: View {
    // MARK: - Properties
    @EnvironmentObject var cardState: CardState

    @Binding var homeNavigationPath: NavigationPath
    @State var generatorModeNavData: GeneratorModeNavData
    @State private var showPickerSheet = false
    @State private var generateBtnMode = GenerateBtnMode.willGenerate

    @State var passwordOptions = PasswordOptions()

    @State private var passphraseText: String = ""
    @State private var labelText: String = ""
    @State private var loginText: String = ""
    @State private var urlText: String = ""
    @State private var freeTextContent: String = ""
    @State private var showPasswordText: Bool = false
    @State private var allowPlaintextExport: Bool = true

    @State private var mnemonicPayload: MnemonicPayload?
    @State private var passwordPayload: PasswordPayload?

    // Mnemonic word input (for manual import)
    @State private var mnemonicWords: [String] = Array(repeating: "", count: 12)
    @State private var selectedWordCount: Int = 12

    @State var seedPhrase = "" {
        didSet {
            if seedPhrase.isEmpty {
                generateBtnMode = .willGenerate
            } else {
                generateBtnMode = .willImport
            }
        }
    }

    var continueBtnTitle: String {
        switch generateBtnMode {
        case .willGenerate:
            return String(localized: "generate")
        case .willImport:
            return String(localized: "import")
        }
    }

    @State var mnemonicSizeOptions = PickerOptions(placeHolder: String(localized: "selectMnemonicSize"), items: MnemonicSize.self)

    var canGeneratePassword: Bool {
        !labelText.isEmpty && passwordOptions.userSelectedAtLeastOneIncludeOption()
    }

    var canGenerateMnemonic: Bool {
        !labelText.isEmpty && mnemonicSizeOptions.selectedOption != nil
    }

    var canManualImportMnemonic: Bool {
        !labelText.isEmpty && isMnemonicValid()
    }

    var canManualImportPassword: Bool {
        !labelText.isEmpty && seedPhrase.count >= 1
    }

    var canImportFreeText: Bool {
        !labelText.isEmpty && !freeTextContent.isEmpty
    }

    private func isMnemonicValid() -> Bool {
        do {
            try Mnemonic.validate(mnemonic: seedPhrase)
            return true
        } catch {
            return false
        }
    }

    func generateMnemonic() -> String? {
        do {
            guard let mnemonicSizeOption = mnemonicSizeOptions.selectedOption else {
                return nil
            }
            let mnemonicSize = mnemonicSizeOption.toBits()
            let mnemonic = try Mnemonic.generateMnemonic(strength: mnemonicSize)
            return mnemonic
        } catch {
            print("Error generating mnemonic: \(error)")
        }
        return nil
    }

    func generatePassword(options: PasswordOptions) -> String {
        var characterSet = ""
        if options.includeLowercase { characterSet += "abcdefghijklmnopqrstuvwxyz" }
        if options.includeUppercase { characterSet += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }
        if options.includeNumbers { characterSet += "0123456789" }
        if options.includeSymbols { characterSet += "!@#$%^&*()-_=+{}[]|;:'\",.<>?/`~" }
        guard !characterSet.isEmpty else { return "" }
        let length = Int(options.passwordLength)
        var password = ""
        for _ in 0..<length {
            if let randomCharacter = characterSet.randomElement() {
                password.append(randomCharacter)
            }
        }
        return password
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.hcBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Spacer().frame(height: 8)

                    // Mode switcher for mnemonic/password
                    if generatorModeNavData.generatorMode == .mnemonic || generatorModeNavData.generatorMode == .password {
                        modeSwitcher
                    }

                    // Mode-specific content
                    switch generatorModeNavData.generatorMode {
                    case .mnemonic:
                        if generatorModeNavData.secretCreationMode == .manualImport {
                            mnemonicImportForm
                        } else {
                            mnemonicGenerateForm
                        }
                    case .password:
                        if generatorModeNavData.secretCreationMode == .manualImport {
                            passwordImportForm
                        } else {
                            passwordGenerateForm
                        }
                    case .freeText:
                        freeTextImportForm
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, Dimensions.lateralPadding)
            }
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
                Text(toolbarTitle.uppercased())
                    .font(.custom("Outfit-Regular", size: 11))
                    .tracking(5)
                    .foregroundColor(.hcTextMuted)
                    .textCase(.uppercase)
            }
        }
        .sheet(isPresented: $showPickerSheet) {
            OptionSelectorView(pickerOptions: $mnemonicSizeOptions)
        }
        .onDisappear {
            cardState.cleanPayloadToImportOnCard()
        }
    }

    // MARK: - Toolbar title

    private var toolbarTitle: String {
        switch generatorModeNavData.generatorMode {
        case .mnemonic:
            return generatorModeNavData.secretCreationMode == .manualImport ? "Import Mnemonic" : "Generate Mnemonic"
        case .password:
            return generatorModeNavData.secretCreationMode == .manualImport ? "Import Password" : "Generate Password"
        case .freeText:
            return "Import Text"
        }
    }

    // MARK: - Mode Switcher

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            let isGenerate = generatorModeNavData.secretCreationMode == .generate
            Button(action: {
                generatorModeNavData = GeneratorModeNavData(
                    generatorMode: generatorModeNavData.generatorMode,
                    secretCreationMode: .generate
                )
                seedPhrase = ""
            }) {
                Text("GENERATE")
                    .font(.custom("Outfit-Regular", size: 10))
                    .tracking(2)
                    .foregroundColor(isGenerate ? .hcTextBright : .hcTextFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isGenerate ? Color.hcBorderHover : Color.hcBgRaised)
            }
            Button(action: {
                generatorModeNavData = GeneratorModeNavData(
                    generatorMode: generatorModeNavData.generatorMode,
                    secretCreationMode: .manualImport
                )
                seedPhrase = ""
            }) {
                Text("IMPORT")
                    .font(.custom("Outfit-Regular", size: 10))
                    .tracking(2)
                    .foregroundColor(!isGenerate ? .hcTextBright : .hcTextFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(!isGenerate ? Color.hcBorderHover : Color.hcBgRaised)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.hcBorder, lineWidth: 1)
        )
        .cornerRadius(8)
    }

    // MARK: - Mnemonic Import Form (Part B)

    private var mnemonicImportForm: some View {
        VStack(spacing: 14) {
            // Heading
            Text("Import Mnemonic")
                .font(.custom("Outfit-Regular", size: 14))
                .foregroundColor(.hcTextBright)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Label
            GhostSectionLabel(text: "Label")
            GhostTextField(placeholder: "Secret label", text: $labelText)

            // Word count selector
            GhostSectionLabel(text: "Word count")
            HStack(spacing: 0) {
                ForEach([12, 18, 24], id: \.self) { count in
                    Button(action: {
                        selectedWordCount = count
                        mnemonicWords = Array(repeating: "", count: count)
                    }) {
                        Text("\(count)")
                            .font(.custom("Outfit-Regular", size: 12))
                            .foregroundColor(selectedWordCount == count ? .hcTextBright : .hcTextFaint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedWordCount == count ? Color.hcBorderHover : Color.hcBgRaised)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.hcBorder, lineWidth: 1)
            )
            .cornerRadius(8)

            // Word grid
            GhostSectionLabel(text: "Mnemonic words")
            mnemonicWordGrid

            // Passphrase
            GhostSectionLabel(text: "Passphrase (optional)")
            GhostTextField(placeholder: "Optional passphrase", text: $passphraseText)

            // Export rights toggle
            exportRightsToggle

            // Save button
            SKButton(text: "Save to Card", style: .regular, horizontalPadding: 16, isEnabled: canManualImportMnemonic, action: {
                seedPhrase = mnemonicWords.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                guard canManualImportMnemonic else { return }

                cardState.mnemonicManualImportPayload = MnemonicManualImportPayload(
                    label: labelText,
                    passphrase: passphraseText.isEmpty ? nil : passphraseText,
                    result: seedPhrase
                )
                cardState.requestManualImportSecret(secretType: .bip39Mnemonic)
            })
        }
    }

    // MARK: - Mnemonic word grid for import

    private var mnemonicWordGrid: some View {
        let columns = 3
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
            ForEach(0..<mnemonicWords.count, id: \.self) { index in
                HStack(spacing: 4) {
                    Text("\(index + 1)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.hcTextGhost)
                        .frame(width: 18, alignment: .trailing)
                    TextField("", text: $mnemonicWords[index])
                        .font(.custom("Outfit-Light", size: 13))
                        .foregroundColor(.hcTextBright)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: mnemonicWords[index]) { newValue in
                            // BIP39 autocomplete
                            if newValue.count >= 3 {
                                let matches = SKMnemonicEnglish.words.filter { $0.hasPrefix(newValue.lowercased()) }
                                if matches.count == 1 && matches[0] != newValue {
                                    mnemonicWords[index] = matches[0]
                                }
                            }
                            // Rebuild seed phrase for validation
                            seedPhrase = mnemonicWords.filter { !$0.isEmpty }.joined(separator: " ")
                        }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .background(Color.hcBgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.hcBorder, lineWidth: 1)
                )
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Mnemonic Generate Form (Part F)

    private var mnemonicGenerateForm: some View {
        VStack(spacing: 14) {
            // Heading
            Text("Generate Mnemonic")
                .font(.custom("Outfit-Regular", size: 14))
                .foregroundColor(.hcTextBright)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Label
            GhostSectionLabel(text: "Label")
            GhostTextField(placeholder: "Secret label", text: $labelText)

            // Word count selector
            GhostSectionLabel(text: "Word count")
            HStack(spacing: 0) {
                wordCountButton(size: .twelveWords, label: "12")
                wordCountButton(size: .twentyFourWords, label: "24")
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.hcBorder, lineWidth: 1)
            )
            .cornerRadius(8)

            // Generated words display
            if !seedPhrase.isEmpty {
                GhostSectionLabel(text: "Generated mnemonic")
                generatedMnemonicGrid
            }

            // Generate / Save button
            if generateBtnMode == .willGenerate {
                SKButton(text: "Generate", style: .regular, horizontalPadding: 16, isEnabled: canGenerateMnemonic, action: {
                    seedPhrase = generateMnemonic() ?? ""
                    if !seedPhrase.isEmpty, let size = mnemonicSizeOptions.selectedOption {
                        mnemonicPayload = MnemonicPayload(
                            label: labelText,
                            mnemonicSize: size,
                            passphrase: passphraseText.isEmpty ? nil : passphraseText,
                            result: seedPhrase
                        )
                    }
                })
            }

            // Passphrase
            GhostSectionLabel(text: "Passphrase (optional)")
            GhostTextField(placeholder: "Optional passphrase", text: $passphraseText)

            if generateBtnMode == .willImport {
                // Generate New
                Button(action: {
                    seedPhrase = generateMnemonic() ?? ""
                    if !seedPhrase.isEmpty, let size = mnemonicSizeOptions.selectedOption {
                        mnemonicPayload = MnemonicPayload(
                            label: labelText,
                            mnemonicSize: size,
                            passphrase: passphraseText.isEmpty ? nil : passphraseText,
                            result: seedPhrase
                        )
                    }
                }) {
                    Text("GENERATE NEW")
                        .font(.custom("Outfit-Regular", size: 10))
                        .tracking(2)
                        .foregroundColor(.hcTextBody)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.hcBorderHover, lineWidth: 1)
                        )
                        .cornerRadius(10)
                }

                // Save to Card
                SKButton(text: "Save to Card", style: .regular, horizontalPadding: 16, action: {
                    guard let payload = mnemonicPayload else { return }
                    cardState.mnemonicPayloadToImportOnCard = payload
                    cardState.requestAddSecret(secretType: .bip39Mnemonic)
                })
            }
        }
    }

    private func wordCountButton(size: MnemonicSize, label: String) -> some View {
        Button(action: {
            mnemonicSizeOptions.selectedOption = size
            seedPhrase = ""
        }) {
            Text(label)
                .font(.custom("Outfit-Regular", size: 12))
                .foregroundColor(mnemonicSizeOptions.selectedOption == size ? .hcTextBright : .hcTextFaint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(mnemonicSizeOptions.selectedOption == size ? Color.hcBorderHover : Color.hcBgRaised)
        }
    }

    // MARK: - Generated mnemonic grid (read-only)

    private var generatedMnemonicGrid: some View {
        let words = seedPhrase.split(separator: " ").map(String.init)
        let columns = 3
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                HStack(spacing: 4) {
                    Text("\(index + 1)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.hcTextGhost)
                        .frame(width: 18, alignment: .trailing)
                    Text(word)
                        .font(.custom("Outfit-Regular", size: 13))
                        .foregroundColor(.hcTextBright)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .background(Color.hcBgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.hcBorder, lineWidth: 1)
                )
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Password Import Form (Part C)

    private var passwordImportForm: some View {
        VStack(spacing: 14) {
            Text("Import Password")
                .font(.custom("Outfit-Regular", size: 14))
                .foregroundColor(.hcTextBright)
                .frame(maxWidth: .infinity, alignment: .leading)

            GhostSectionLabel(text: "Label (required)")
            GhostTextField(placeholder: "Label", text: $labelText)

            GhostSectionLabel(text: "Password (required)")
            GhostTextField(placeholder: "Password", text: $seedPhrase, isSecure: true)

            GhostSectionLabel(text: "Login / Username (optional)")
            GhostTextField(placeholder: "Login", text: $loginText)

            GhostSectionLabel(text: "URL (optional)")
            GhostTextField(placeholder: "https://", text: $urlText)

            exportRightsToggle

            SKButton(text: "Save to Card", style: .regular, horizontalPadding: 16, isEnabled: canManualImportPassword, action: {
                cardState.passwordPayloadToImportOnCard = PasswordPayload(
                    label: labelText,
                    login: loginText.isEmpty ? nil : loginText,
                    url: urlText.isEmpty ? nil : urlText,
                    passwordLength: Double(seedPhrase.count),
                    result: seedPhrase
                )
                cardState.requestManualImportSecret(secretType: .password)
            })
        }
    }

    // MARK: - Password Generate Form (Part E)

    private var passwordGenerateForm: some View {
        VStack(spacing: 14) {
            Text("Generate Password")
                .font(.custom("Outfit-Regular", size: 14))
                .foregroundColor(.hcTextBright)
                .frame(maxWidth: .infinity, alignment: .leading)

            GhostSectionLabel(text: "Label")
            GhostTextField(placeholder: "Secret label", text: $labelText)

            GhostSectionLabel(text: "Login / Username (optional)")
            GhostTextField(placeholder: "Login", text: $loginText)

            GhostSectionLabel(text: "URL (optional)")
            GhostTextField(placeholder: "https://", text: $urlText)

            // Generated password display
            if !seedPhrase.isEmpty {
                GhostSectionLabel(text: "Generated password")
                Text(seedPhrase)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.hcTextBright)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.hcBgSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.hcBorder, lineWidth: 1)
                    )
                    .cornerRadius(8)

                HStack(spacing: 8) {
                    // Copy
                    Button(action: {
                        ClipboardManager.shared.copy(seedPhrase)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Text("COPY")
                            .font(.custom("Outfit-Regular", size: 10))
                            .tracking(2)
                            .foregroundColor(.hcTextBody)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.hcBorderHover, lineWidth: 1)
                            )
                    }
                }
            }

            // Password generator controls
            PasswordGeneratorBox(options: passwordOptions)

            // Generate / Save buttons
            if generateBtnMode == .willGenerate {
                SKButton(text: "Generate", style: .regular, horizontalPadding: 16, isEnabled: canGeneratePassword, action: {
                    let password = generatePassword(options: passwordOptions)
                    seedPhrase = password
                    passwordPayload = PasswordPayload(
                        label: labelText,
                        login: loginText.isEmpty ? nil : loginText,
                        url: urlText.isEmpty ? nil : urlText,
                        passwordLength: passwordOptions.passwordLength,
                        result: seedPhrase
                    )
                })
            } else {
                Button(action: {
                    let password = generatePassword(options: passwordOptions)
                    seedPhrase = password
                    passwordPayload = PasswordPayload(
                        label: labelText,
                        login: loginText.isEmpty ? nil : loginText,
                        url: urlText.isEmpty ? nil : urlText,
                        passwordLength: passwordOptions.passwordLength,
                        result: seedPhrase
                    )
                }) {
                    Text("REGENERATE")
                        .font(.custom("Outfit-Regular", size: 10))
                        .tracking(2)
                        .foregroundColor(.hcTextBody)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.hcBorderHover, lineWidth: 1)
                        )
                }

                SKButton(text: "Save to Card", style: .regular, horizontalPadding: 16, action: {
                    guard let payload = passwordPayload else { return }
                    cardState.passwordPayloadToImportOnCard = payload
                    cardState.requestAddSecret(secretType: .password)
                })
            }
        }
    }

    // MARK: - Free Text Import Form (Part D)

    private var freeTextImportForm: some View {
        VStack(spacing: 14) {
            Text("Import Text")
                .font(.custom("Outfit-Regular", size: 14))
                .foregroundColor(.hcTextBright)
                .frame(maxWidth: .infinity, alignment: .leading)

            GhostSectionLabel(text: "Label")
            GhostTextField(placeholder: "Secret label", text: $labelText)

            GhostSectionLabel(text: "Content")
            TextEditor(text: $freeTextContent)
                .font(.custom("Outfit-Light", size: 13))
                .foregroundColor(.hcTextBright)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color.hcBgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.hcBorder, lineWidth: 1)
                )
                .cornerRadius(8)

            exportRightsToggle

            SKButton(text: "Save to Card", style: .regular, horizontalPadding: 16, isEnabled: canImportFreeText, action: {
                // Use password import path for free text (byte format compatible)
                cardState.passwordPayloadToImportOnCard = PasswordPayload(
                    label: labelText,
                    login: nil,
                    url: nil,
                    passwordLength: Double(freeTextContent.count),
                    result: freeTextContent
                )
                cardState.requestManualImportSecret(secretType: .password)
            })
        }
    }

    // MARK: - Export rights toggle

    private var exportRightsToggle: some View {
        HStack {
            Text("Allow plaintext export")
                .font(.custom("Outfit-Light", size: 12))
                .foregroundColor(.hcTextBody)
            Spacer()
            Toggle("", isOn: $allowPlaintextExport)
                .toggleStyle(SwitchToggleStyle(tint: .hcBorderHover))
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}


enum GenerateBtnMode {
    case willGenerate
    case willImport
}

struct GeneratorModeNavData: Hashable {
    let generatorMode: GeneratorMode
    var secretCreationMode: SecretCreationMode

    init(generatorMode: GeneratorMode, secretCreationMode: SecretCreationMode) {
        self.generatorMode = generatorMode
        self.secretCreationMode = secretCreationMode
    }
}

enum GeneratorMode: String, CaseIterable, Hashable, HumanReadable {
    case mnemonic
    case password
    case freeText

    func humanReadableName() -> String {
        switch self {
        case .mnemonic:
            return String(localized: "mnemonicPhrase")
        case .password:
            return String(localized: "loginPasswordPhrase")
        case .freeText:
            return "Free Text"
        }
    }
}

enum MnemonicSize: String, CaseIterable, Hashable, HumanReadable {
    case twelveWords
    case eighteenWords
    case twentyFourWords

    func humanReadableName() -> String {
        switch self {
        case .twelveWords:
            return String(localized: "12words")
        case .eighteenWords:
            return String(localized: "18words")
        case .twentyFourWords:
            return String(localized: "24words")
        }
    }

    func toBits() -> Int {
        switch self {
        case .twelveWords:
            return 128
        case .eighteenWords:
            return 192
        case .twentyFourWords:
            return 256
        }
    }
}

struct MnemonicCardData {
    let mnemonic: String
    let passphrase: String?

    func getMnemonicSize() -> MnemonicSize? {
        let mnemonicWords = mnemonic.split(separator: " ")
        switch mnemonicWords.count {
        case 12:
            return .twelveWords
        case 18:
            return .eighteenWords
        case 24:
            return .twentyFourWords
        default:
            return nil
        }
    }

    func getSeedQRContent() -> String {
        let wordlist = SKMnemonicEnglish.words
        let indices = mnemonicToIndices(mnemonic: mnemonic, wordlist: wordlist)
        let combinedString = indices.map { String($0) }.joined(separator: " ")
        return combinedString
    }

    func getSeedQRImage() -> UIImage? {
        let wordlist = SKMnemonicEnglish.words
        let indices = mnemonicToIndices(mnemonic: mnemonic, wordlist: wordlist)
        let combinedString = indices.map { String($0) }.joined(separator: " ")

        guard let data = combinedString.data(using: .ascii) else { return nil }

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCIImage = ciImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    private func mnemonicToIndices(mnemonic: String, wordlist: [String]) -> [Int] {
        return mnemonic.split(separator: " ").compactMap { word in
            wordlist.firstIndex(of: String(word))
        }
    }
}

struct MnemonicPayload {
    var label: String
    var mnemonicSize: MnemonicSize
    var passphrase: String?
    var result: String

    func getPayloadBytes() -> [UInt8] {
        let mnemonicBytes = [UInt8](result.utf8)
        let mnemonicSize = UInt8(mnemonicBytes.count)

        var payload: [UInt8] = []
        payload.append(mnemonicSize)
        payload.append(contentsOf: mnemonicBytes)

        if let passphrase = passphrase {
            let passphraseBytes = [UInt8](passphrase.utf8)
            let passphraseSize = UInt8(passphraseBytes.count)
            payload.append(passphraseSize)
            payload.append(contentsOf: passphraseBytes)
        }

        return payload
    }
}

struct MnemonicManualImportPayload {
    var label: String
    var passphrase: String?
    var result: String

    func getPayloadBytes() -> [UInt8] {
        let mnemonicBytes = [UInt8](result.utf8)
        let mnemonicSize = UInt8(mnemonicBytes.count)

        var payload: [UInt8] = []
        payload.append(mnemonicSize)
        payload.append(contentsOf: mnemonicBytes)

        if let passphrase = passphrase {
            let passphraseBytes = [UInt8](passphrase.utf8)
            let passphraseSize = UInt8(passphraseBytes.count)
            payload.append(passphraseSize)
            payload.append(contentsOf: passphraseBytes)
        }

        return payload
    }
}

struct PasswordCardData {
    let password: String
    let login: String
    let url: String
}

struct PasswordPayload {
    var label: String
    var login: String?
    var url: String?
    var passwordLength: Double
    var result: String

    func getPayloadBytes() -> [UInt8] {
        let passwordBytes = [UInt8](result.utf8)
        let passwordSize = UInt8(passwordBytes.count)

        var payload: [UInt8] = []
        payload.append(passwordSize)
        payload.append(contentsOf: passwordBytes)

        if let login = login {
            let loginBytes = [UInt8](login.utf8)
            let loginSize = UInt8(loginBytes.count)
            payload.append(loginSize)
            payload.append(contentsOf: loginBytes)
        }

        if let url = url {
            let urlBytes = [UInt8](url.utf8)
            let urlSize = UInt8(urlBytes.count)
            payload.append(urlSize)
            payload.append(contentsOf: urlBytes)
        }

        return payload
    }
}

struct PasswordManualImportPayload {
    var label: String
    var login: String?
    var url: String?
    var result: String

    func getPayloadBytes() -> [UInt8] {
        let passwordBytes = [UInt8](result.utf8)
        let passwordSize = UInt8(passwordBytes.count)

        var payload: [UInt8] = []
        payload.append(passwordSize)
        payload.append(contentsOf: passwordBytes)

        if let login = login {
            let loginBytes = [UInt8](login.utf8)
            let loginSize = UInt8(loginBytes.count)
            payload.append(loginSize)
            payload.append(contentsOf: loginBytes)
        }

        if let url = url {
            let urlBytes = [UInt8](url.utf8)
            let urlSize = UInt8(urlBytes.count)
            payload.append(urlSize)
            payload.append(contentsOf: urlBytes)
        }

        return payload
    }
}
