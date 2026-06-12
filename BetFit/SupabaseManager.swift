// ============================================================
// SupabaseManager.swift
// BetFit
// ============================================================
// Calls Supabase REST API directly via URLSession.
// No SDK needed — works with any Xcode version.
//
// Replace the two constants below with your project values:
//   SUPABASE_URL  → https://YOUR_PROJECT_ID.supabase.co
//   SUPABASE_KEY  → your publishable key (sb_publishable_...)
// ============================================================

import Foundation
import Combine
import UIKit

// ============================================================
// MARK: - Config
// ============================================================

private let SUPABASE_URL = "https://jdaqkumsyvijqqgudbjj.supabase.co"
private let SUPABASE_KEY = "sb_publishable_QqaBpCWOr3z-rh7l7JZtDg_R_g-RHKn"

// ============================================================
// MARK: - Models
// ============================================================

struct BFUser: Codable, Identifiable {
    let id: UUID
    let email: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
    }
}

struct BFSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: BFUser

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn    = "expires_in"
        case user
    }
}

// ============================================================
// MARK: - Auth Manager
// ============================================================

@MainActor
final class AuthManager: ObservableObject {

    static let shared = AuthManager()

    @Published var user: BFUser?        = nil
    @Published var isLoading: Bool      = true
    @Published var errorMessage: String? = nil

    // Persisted tokens
    @Published var accessToken: String? = nil

    private let tokenKey   = "bf_access_token"
    private let refreshKey = "bf_refresh_token"

    var isSignedIn: Bool { user != nil }
    var userId: String? { user?.id.uuidString }

    private init() {
        Task { await restoreSession() }
    }

    // ── Restore session from keychain / UserDefaults on launch
    func restoreSession() async {
        isLoading = true
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            accessToken = token
            await fetchUser(token: token)
        }
        isLoading = false
    }

    // ── Fetch current user using stored token
    func fetchUser(token: String) async {
        guard let url = URL(string: "\(SUPABASE_URL)/auth/v1/user") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                user = try JSONDecoder().decode(BFUser.self, from: data)
            } else {
                // Token expired — clear it
                clearSession()
            }
        } catch {
            clearSession()
        }
    }

    // ── Sign in with Apple via Supabase OAuth
    // Opens Safari → user authenticates → deep link returns token
    func signInWithApple() {
        openOAuthURL(provider: "apple")
    }

    // ── Sign in with Google via Supabase OAuth
    func signInWithGoogle() {
        openOAuthURL(provider: "google")
    }

    private func openOAuthURL(provider: String) {
        errorMessage = nil
        let redirect = "betfit://auth/callback"
        let encoded  = redirect.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr   = "\(SUPABASE_URL)/auth/v1/authorize?provider=\(provider)&redirect_to=\(encoded)"
        guard let url = URL(string: urlStr) else { return }
        UIApplication.shared.open(url)
    }

    // ── Handle OAuth callback deep link
    // Called from BetFitApp .onOpenURL
    func handleCallback(url: URL) async {
        // Extract access_token from URL fragment
        // Supabase returns: betfit://auth/callback#access_token=...&refresh_token=...
        guard let fragment = url.fragment else { return }

        var params: [String: String] = [:]
        for part in fragment.split(separator: "&") {
            let kv = part.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                params[String(kv[0])] = String(kv[1])
            }
        }

        guard let token = params["access_token"],
              let refresh = params["refresh_token"] else {
            errorMessage = "Sign in failed — no token received."
            return
        }

        // Persist tokens
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(refresh, forKey: refreshKey)
        accessToken = token

        // Fetch user profile
        await fetchUser(token: token)
    }

    // ── Sign out
    func signOut() async {
        if let token = accessToken {
            // Tell Supabase to invalidate the token
            if let url = URL(string: "\(SUPABASE_URL)/auth/v1/logout") {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
                try? await URLSession.shared.data(for: req)
            }
        }
        clearSession()
    }

    private func clearSession() {
        user         = nil
        accessToken  = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshKey)
    }

    // ── Generic authenticated GET request helper
    // Use this in other managers to query Supabase tables
    func get(path: String) async throws -> Data {
        guard let token = accessToken,
              let url = URL(string: "\(SUPABASE_URL)/rest/v1/\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    // ── Generic authenticated POST/UPSERT helper
    func post(path: String, body: [String: Any], method: String = "POST") async throws -> Data {
        guard let token = accessToken,
              let url = URL(string: "\(SUPABASE_URL)/rest/v1/\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
}
