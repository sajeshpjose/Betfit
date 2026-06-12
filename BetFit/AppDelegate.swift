// ============================================================
// AppDelegate.swift
// BetFit
// ============================================================
// Bridges UIApplicationDelegate callbacks into Swift concurrency.
// Wired up via @UIApplicationDelegateAdaptor in BetFitApp.
// ============================================================

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    // ── Successful APNs token registration
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { await NotificationManager.shared.storeDeviceToken(deviceToken) }
    }

    // ── Token registration failed (simulator, missing entitlement, etc.)
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error.localizedDescription)")
    }
}
