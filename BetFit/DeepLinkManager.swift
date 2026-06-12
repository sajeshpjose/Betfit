// ============================================================
// DeepLinkManager.swift
// BetFit
// ============================================================
// Handles two URL schemes:
//
//   betfit://auth/callback          → OAuth callback (existing)
//   betfit://join/{teamId}          → invite link (custom scheme)
//   https://habet.app/join/{teamId}          → invite link (Universal Link)
//
// Universal Links require an apple-app-site-association (AASA) file
// hosted at https://habet.app/.well-known/apple-app-site-association
// with the following content:
//
//   {
//     "applinks": {
//       "apps": [],
//       "details": [
//         {
//           "appID": "894HMB2J58.com.yello.betfit",
//           "paths": ["/join/*"]
//         }
//       ]
//     }
//   }
//
// The file must be served as application/json with no redirect.
// Once hosted, Universal Links work automatically — no code change needed.
// ============================================================

import Foundation
import Combine

@MainActor
final class DeepLinkManager: ObservableObject {

    static let shared = DeepLinkManager()

    // Set when a join link is opened — ChallengesView observes this
    @Published var pendingJoinTeamId: String? = nil
    @Published var pendingChallenge: BFChallenge? = nil

    private init() {}

    // ── Called from BetFitApp .onOpenURL
    func handle(url: URL) async {
        // Auth callback — delegate to AuthManager
        if url.scheme == "betfit", url.host == "auth" {
            await AuthManager.shared.handleCallback(url: url)
            return
        }

        // Join link: betfit://join/{teamId}
        if url.scheme == "betfit", url.host == "join" {
            let teamId = url.lastPathComponent
            if !teamId.isEmpty { await resolveJoin(teamId: teamId) }
            return
        }

        // Universal Link: https://habet.app/join/{teamId}
        let components = url.pathComponents  // ["/" , "join", "{teamId}"]
        if components.count >= 3, components[1] == "join" {
            let teamId = components[2]
            await resolveJoin(teamId: teamId)
            return
        }
    }

    // ── Look up the challenge for this teamId, then signal navigation
    // Internal so NotificationManager can call it on notification tap
    func resolveJoinPublic(teamId: String) async { await resolveJoin(teamId: teamId) }

    private func resolveJoin(teamId: String) async {
        pendingJoinTeamId = teamId

        // Fetch the challenge this team belongs to so we can navigate directly
        do {
            let data = try await AuthManager.shared.get(
                path: "challenge_teams?id=eq.\(teamId)&select=challenge_id,challenges(*)&limit=1"
            )
            struct Row: Codable {
                let challenge: BFChallenge?
                enum CodingKeys: String, CodingKey { case challenge = "challenges" }
            }
            let rows = (try? JSONDecoder().decode([Row].self, from: data)) ?? []
            pendingChallenge = rows.first?.challenge
        } catch {
            print("DeepLinkManager resolveJoin error: \(error)")
        }
    }

    func clearPending() {
        pendingJoinTeamId = nil
        pendingChallenge  = nil
    }
}
