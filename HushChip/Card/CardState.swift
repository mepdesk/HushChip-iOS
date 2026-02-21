//
//  CardData.swift
//  Satodime
//
//  Created by Satochip on 01/12/2023.
//

import Foundation
import CoreNFC
import SatochipSwift
import CryptoSwift
import Combine
import SwiftUI
import UIKit
import MnemonicSwift

enum SatocardError: Error {
    case testError(String)
    case randomGeneratorError
    case invalidResponse
}

enum ScannedCardType {
    case master
    case backup
}

class CardState: ObservableObject {
    var dataControllerContext = DataController.shared.container.viewContext
    
    var cmdSet: SatocardCommandSet!
    
    @Published var cardStatus: CardStatus?
    @Published var backupCardStatus: CardStatus?
    
    @Published var isCardDataAvailable = false
    @Published var authentikeyHex = ""
    @Published var certificateDic = [String: String]()
    @Published var certificateCode = PkiReturnCode.unknown
    @Published var errorMessage: String?
    @Published var homeNavigationPath = NavigationPath()

    // HushChip: wrong-PIN UX state
    /// Set to true when the last card scan failed PIN verification. PinCodeView observes
    /// this on appear to trigger the shake animation and reads false after consuming it.
    @Published var wrongPinAttempt: Bool = false
    /// Running count of consecutive wrong PIN attempts against the current card.
    /// Shown as "X attempts remaining" in PinCodeView. Reset on success or new card setup.
    @Published var consecutiveWrongPins: Int = 0
    
    @Published var authentikeyHexForBackup = ""
    @Published var certificateDicForBackup = [String: String]()
    @Published var certificateCodeForBackup = PkiReturnCode.unknown
    
    @Published var cardLabel: String = "n/a"
    var cardLabelToSet: String?
    
    var session: SatocardController?
    var cardController: SatocardController?
    
    private(set) var isPinVerificationSuccess: Bool = false
    
    var pinCodeToSetup: String?
    var pinForMasterCard: String?
    var pinForBackupCard: String?
    
    @Published var masterSecretHeaders: [SeedkeeperSecretHeaderDto] = []
    
    @Published var mode: BackupMode = .start
    
    var secretsForBackup: [SeedkeeperSecretHeaderDto:SeedkeeperSecretObject] = [:]
    
    var currentSecretHeader: SeedkeeperSecretHeaderDto?
    @Published var currentSecretObject: SeedkeeperSecretObject? {
        didSet {
            if currentSecretObject?.secretHeader.type == .password,
               let secretBytes = currentSecretObject?.secretBytes,
               let data = parsePasswordCardData(from: secretBytes) {
                    currentPasswordCardData = data
            } else if currentSecretObject?.secretHeader.type == .bip39Mnemonic, let secretBytes = currentSecretObject?.secretBytes,
                      let data = parseMnemonicCardData(from: secretBytes) {
                currentMnemonicCardData = data
            }
        }
    }
    @Published var currentSecretString: String = ""
    @Published var currentPasswordCardData: PasswordCardData?
    @Published var currentMnemonicCardData: MnemonicCardData?
    
    var passwordPayloadToImportOnCard: PasswordPayload?
    var mnemonicPayloadToImportOnCard: MnemonicPayload?
    
    var mnemonicManualImportPayload: MnemonicManualImportPayload?
    var passwordManualImportPayload: PasswordManualImportPayload?
    
    func logEvent(log: LogModel) {
        dataControllerContext.saveLogEntry(log: log)
    }

    // *********************************************************
    // MARK: - Master card connection
    // *********************************************************
    func scan() {
        print("CardState scan()")
        DispatchQueue.main.async {
            self.resetState()
        }
        session = SatocardController(onConnect: onConnection, onFailure: onDisconnection)
        session?.start(alertMessage: "Scan your card")
    }
    
    func onConnection(cardChannel: CardChannel) -> Void {
        Task {
            do {
                try await handleConnection(cardChannel: cardChannel)
            } catch {
                logEvent(log: LogModel(type: .error, message: "onConnection : \(error.localizedDescription)"))
                let friendly = self.friendlyError(error.localizedDescription)
                DispatchQueue.main.async {
                    self.errorMessage = friendly
                }
                session?.stop(errorMessage: friendly)
            }
        }
    }
    
    private func handleConnection(cardChannel: CardChannel) async throws {
        cmdSet = SatocardCommandSet(cardChannel: cardChannel)
        
        let (statusApdu, cardType) = try await fetchCardStatus()

        // Haptic: card detected
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        cardStatus = try CardStatus(rapdu: statusApdu)
        
        if let cardStatus = cardStatus, !cardStatus.setupDone {
            // let version = getCardVersionInt(cardStatus: cardStatus)
            // if version <= 0x00010001 {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Fresh card — reset any stale wrong-PIN state from a previous card
                    self.consecutiveWrongPins = 0
                    self.wrongPinAttempt = false
                    homeNavigationPath.append(NavigationRoutes.createPinCode(PinCodeNavigationData(mode: .createPinCode, pinCode: nil)))
                }
                session?.stop(alertMessage: String(localized: "nfcCardNeedsSetup"))
                return
            // }
        } else {
            guard let pinForMasterCard = pinForMasterCard else {
                // HushChip: PIN not stored yet — stop session quietly (no error UI) and go to PIN entry
                session?.stop(alertMessage: "")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    homeNavigationPath.append(NavigationRoutes.pinCode(.rescanCard))
                }
                return
            }

            let pinBytes = Array(pinForMasterCard.utf8)
            do {
                var response = try cmdSet.cardVerifyPIN(pin: pinBytes)
                self.isPinVerificationSuccess = true
                // Reset wrong-PIN counters on success
                DispatchQueue.main.async { [weak self] in
                    self?.consecutiveWrongPins = 0
                    self?.wrongPinAttempt = false
                }
            } catch {
                self.pinForMasterCard = nil
                self.isPinVerificationSuccess = false
                logEvent(log: LogModel(type: .error, message: "onConnection : \(error.localizedDescription)"))
                // HushChip: navigate back to PIN entry so user can try again
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.wrongPinAttempt = true
                    self.consecutiveWrongPins += 1
                    let remaining = max(5 - self.consecutiveWrongPins, 0)
                    let friendly = self.friendlyError(error.localizedDescription, pinTriesLeft: remaining)
                    self.session?.stop(errorMessage: friendly)
                    self.homeNavigationPath.append(NavigationRoutes.pinCode(.rescanCard))
                }
                return
            }
        }
        
        // HushChip: authenticity check disabled — HushChip cards use independent hardware
        // try await verifyCardAuthenticity(cardType: .master)
        try await fetchAuthentikey(cardType: .master)
        
        DispatchQueue.main.async {
            self.isCardDataAvailable = true
        }
                
        do {
            let secrets: [SeedkeeperSecretHeader] = try cmdSet.seedkeeperListSecretHeaders()
            self.masterSecretHeaders = secrets.map { SeedkeeperSecretHeaderDto(secretHeader: $0) }
            let fetchedLabel = try cmdSet.cardGetLabel()
            self.cardLabel = !fetchedLabel.isEmpty ? fetchedLabel : "n/a"
            print("Secrets: \(secrets)")
        } catch let error {
            logEvent(log: LogModel(type: .error, message: "onConnection : \(error.localizedDescription)"))
            session?.stop(errorMessage: friendlyError(error.localizedDescription))
        }

        session?.stop(alertMessage: String(localized: "nfcSecretsListSuccess"))
    }

    // *********************************************************
    // MARK: - On disconnection
    // *********************************************************
    func onDisconnection(error: Error) {
        // Handle disconnection
    }
}
