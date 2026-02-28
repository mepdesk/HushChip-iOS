// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// Based on Seedkeeper-iOS by Toporin / Satochip S.R.L.
// Licensed under GPL-3.0
//
//
//  AppDelegate.swift
//  Signstr
//

import Foundation
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set ourselves as the notification center delegate so we can suppress
        // notifications when the app is already in the foreground.
        UNUserNotificationCenter.current().delegate = self

        // Request notification permission on first launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[Signstr] Notification permission error: \(error.localizedDescription)")
            }
            print("[Signstr] Notification permission granted: \(granted)")
        }

        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Suppress local notifications when the app is in the foreground —
    /// the signing-request approval UI is already visible.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Don't show banners/sounds while foregrounded; the approval sheet is on screen.
        completionHandler([])
    }

    /// When the user taps a notification, the system brings the app to the foreground
    /// where the pending approval prompt is already waiting. No extra routing needed.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
