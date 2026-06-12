// ============================================================
// NotificationManager.swift
// BetFit
// ============================================================
// Handles:
//   1. Permission request
//   2. Device token → Supabase storage (for server-side push)
//   3. Local notifications (daily step reminder)
//   4. Foreground notification display
//
// ── Server-side setup (Supabase) ────────────────────────────
// Run this SQL once:
//
//   create table public.device_tokens (
//     id         uuid default gen_random_uuid() primary key,
//     user_id    uuid not null references auth.users(id) on delete cascade,
//     token      text not null,
//     platform   text not null default 'ios',
//     updated_at timestamptz default now(),
//     unique(user_id, platform)
//   );
//   alter table public.device_tokens enable row level security;
//   create policy "users manage own tokens"
//     on public.device_tokens for all using (auth.uid() = user_id);
//
// ── Supabase Edge Function (send-notification) ──────────────
// Deploy to supabase/functions/send-notification/index.ts
// Called with: { userId, title, body, data? }
// Uses APNs HTTP/2 + your AuthKey_62J3RLVCY5.p8 to deliver.
//
// Trigger it from:
//   • Database webhook on step_logs INSERT → notify teammates
//   • Scheduled function (cron) for daily reminders + challenge countdowns
//   • challenge_team_members INSERT → notify team owner of new member
//
// ── When to change aps-environment ──────────────────────────
// BetFit.entitlements currently uses "development".
// Change to "production" before uploading to App Store Connect.
// ============================================================

import Foundation
import Combine
import UserNotifications
import UIKit

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // ── 1. Request permission (call from onboarding or first dashboard load)
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    // ── 2. Store APNs device token in Supabase (called from AppDelegate)
    func storeDeviceToken(_ tokenData: Data) async {
        guard let userId = AuthManager.shared.userId else { return }

        let token = tokenData.map { String(format: "%02x", $0) }.joined()

        let payload: [String: Any] = [
            "user_id":    userId,
            "token":      token,
            "platform":   "ios",
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        _ = try? await AuthManager.shared.post(
            path: "device_tokens?on_conflict=user_id,platform",
            body: payload,
            method: "POST"
        )
    }

    // ── 3. Schedule daily step reminder (local, no server needed)
    //    Call once after the user grants permission.
    //    Default: 6 PM if user hasn't reached their goal.
    func scheduleDailyStepReminder(at hour: Int = 18, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()

        // Remove any existing reminder first
        center.removePendingNotificationRequests(withIdentifiers: ["daily-step-reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak! 🔥"
        content.body  = "You haven't hit your step goal yet today. Your team is counting on you."
        content.sound = .default
        content.badge = 1

        var comps = DateComponents()
        comps.hour   = hour
        comps.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-step-reminder",
            content:    content,
            trigger:    trigger
        )
        center.add(request)
    }

    // ── 4. Schedule a challenge-ending warning (local)
    func scheduleChallengeEndingWarning(challengeName: String, endDate: Date) {
        let center = UNUserNotificationCenter.current()
        let id = "challenge-ending-\(challengeName.hashValue)"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard let warningDate = Calendar.current.date(byAdding: .day, value: -2, to: endDate),
              warningDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "2 days left! ⏳"
        content.body  = "\(challengeName) ends soon. Push hard to climb the leaderboard."
        content.sound = .default

        let comps   = Calendar.current.dateComponents([.year, .month, .day, .hour], from: warningDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    // ── 5. Show notification banner even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // ── 6. Handle notification tap (route to correct screen)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Server-side push can include { "type": "challenge", "challengeId": "..." }
        if let type = userInfo["type"] as? String,
           type == "challenge",
           let teamId = userInfo["teamId"] as? String {
            Task { await DeepLinkManager.shared.resolveJoinPublic(teamId: teamId) }
        }

        completionHandler()
    }

    // ── Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
}
