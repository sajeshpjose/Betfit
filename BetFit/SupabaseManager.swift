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
import AuthenticationServices

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
final class AuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    static let shared = AuthManager()

    @Published var user: BFUser?        = nil
    @Published var isLoading: Bool      = true
    @Published var errorMessage: String? = nil

    // Persisted tokens
    @Published var accessToken: String? = nil

    private let tokenKey       = "bf_access_token"
    private let refreshKey     = "bf_refresh_token"
    private let expiresAtKey   = "bf_token_expires_at"
    private var webAuthSession: ASWebAuthenticationSession?
    private var refreshTimer: Task<Void, Never>?

    var isSignedIn: Bool { user != nil }
    var userId: String? { user?.id.uuidString }

    override private init() {
        super.init()
        Task { await restoreSession() }
    }

    // ── Restore session from keychain / UserDefaults on launch
    func restoreSession() async {
        isLoading = true
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            accessToken = token
            // Try to refresh token if it's expired or about to expire
            if isTokenExpired() {
                await refreshAccessToken()
            } else {
                await fetchUser(token: token)
                if user != nil { await ProfileManager.shared.load() }
            }
            // Schedule next refresh
            scheduleTokenRefresh()
        }
        isLoading = false
    }

    // ── Check if access token is expired or about to expire (within 5 minutes)
    private func isTokenExpired() -> Bool {
        guard let expiresAt = UserDefaults.standard.double(forKey: expiresAtKey),
              expiresAt > 0 else { return true }
        let secondsUntilExpiry = expiresAt - Date().timeIntervalSince1970
        return secondsUntilExpiry < 300 // Refresh if less than 5 minutes remain
    }

    // ── Refresh access token using refresh token
    func refreshAccessToken() async {
        guard let refreshToken = UserDefaults.standard.string(forKey: refreshKey) else {
            clearSession()
            return
        }

        guard let url = URL(string: "\(SUPABASE_URL)/auth/v1/token?grant_type=refresh_token") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")

        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)"
        req.httpBody = body.data(using: .utf8)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                let session = try JSONDecoder().decode(BFSession.self, from: data)
                // Store new tokens and expiration time
                UserDefaults.standard.set(session.accessToken, forKey: tokenKey)
                UserDefaults.standard.set(session.refreshToken, forKey: refreshKey)
                let expiresAt = Date().timeIntervalSince1970 + Double(session.expiresIn)
                UserDefaults.standard.set(expiresAt, forKey: expiresAtKey)
                accessToken = session.accessToken
                // Verify user is still valid
                await fetchUser(token: session.accessToken)
                scheduleTokenRefresh()
            } else {
                clearSession()
            }
        } catch {
            clearSession()
        }
    }

    // ── Schedule token refresh before expiration
    private func scheduleTokenRefresh() {
        refreshTimer?.cancel()
        guard let expiresAt = UserDefaults.standard.double(forKey: expiresAtKey),
              expiresAt > 0 else { return }

        let secondsUntilExpiry = expiresAt - Date().timeIntervalSince1970
        // Refresh 5 minutes before expiry, or in 10 seconds if less than 5 minutes left
        let delaySeconds = max(10, secondsUntilExpiry - 300)

        refreshTimer = Task {
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            if !Task.isCancelled {
                await self.refreshAccessToken()
            }
        }
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
            } else if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
                // Token is invalid — try to refresh it
                await refreshAccessToken()
            } else {
                clearSession()
            }
        } catch {
            clearSession()
        }
    }

    // ── Sign in with Apple — in-app sheet via ASWebAuthenticationSession
    func signInWithApple() async {
        await performOAuth(provider: "apple")
    }

    // ── Sign in with Google — disabled for MVP
    // func signInWithGoogle() async {
    //     await performOAuth(provider: "google")
    // }

    // Presents OAuth in an in-app Safari sheet; no external browser needed.
    private func performOAuth(provider: String) async {
        errorMessage = nil
        let redirect = "betfit://auth/callback"
        let encoded  = redirect.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr   = "\(SUPABASE_URL)/auth/v1/authorize?provider=\(provider)&redirect_to=\(encoded)"
        guard let url = URL(string: urlStr) else { return }

        do {
            let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: "betfit"
                ) { callbackURL, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let callbackURL = callbackURL {
                        continuation.resume(returning: callbackURL)
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
                session.presentationContextProvider = self
                // false = share cookies with Safari (enables SSO)
                session.prefersEphemeralWebBrowserSession = false
                webAuthSession = session
                session.start()
            }
            webAuthSession = nil
            await handleCallback(url: callbackURL)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // User dismissed the sheet — nothing to do
            webAuthSession = nil
        } catch {
            webAuthSession = nil
            errorMessage = "Sign in failed. Please try again."
        }
    }

    // ASWebAuthenticationPresentationContextProviding
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
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
              let refresh = params["refresh_token"],
              let expiresInStr = params["expires_in"],
              let expiresIn = Int(expiresInStr) else {
            errorMessage = "Sign in failed — no token received."
            return
        }

        // Persist tokens and calculate expiration time
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(refresh, forKey: refreshKey)
        let expiresAt = Date().timeIntervalSince1970 + Double(expiresIn)
        UserDefaults.standard.set(expiresAt, forKey: expiresAtKey)
        accessToken = token

        // Schedule next token refresh before expiration
        scheduleTokenRefresh()

        // Fetch user profile then load Supabase profile data
        await fetchUser(token: token)
        await ProfileManager.shared.load()
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
        refreshTimer?.cancel()
        refreshTimer = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshKey)
        UserDefaults.standard.removeObject(forKey: expiresAtKey)
    }

    // ── Generic authenticated GET request helper
    // Use this in other managers to query Supabase tables
    func get(path: String) async throws -> Data {
        guard let url = URL(string: "\(SUPABASE_URL)/rest/v1/\(path)") else {
            throw URLError(.badURL)
        }

        // Refresh token if needed before making request
        if isTokenExpired() {
            await refreshAccessToken()
        }

        guard let token = accessToken else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
                // Token might have been revoked, try refreshing and retry once
                await refreshAccessToken()
                if let newToken = accessToken {
                    var retryReq = req
                    retryReq.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    let (retryData, _) = try await URLSession.shared.data(for: retryReq)
                    return retryData
                }
            }
            return data
        }
    }

    // ── Generic authenticated POST/UPSERT helper
    func post(path: String, body: [String: Any], method: String = "POST") async throws -> Data {
        guard let url = URL(string: "\(SUPABASE_URL)/rest/v1/\(path)") else {
            throw URLError(.badURL)
        }

        // Refresh token if needed before making request
        if isTokenExpired() {
            await refreshAccessToken()
        }

        guard let token = accessToken else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(SUPABASE_KEY, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
                // Token might have been revoked, try refreshing and retry once
                await refreshAccessToken()
                if let newToken = accessToken {
                    var retryReq = req
                    retryReq.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    retryReq.httpBody = try JSONSerialization.data(withJSONObject: body)
                    let (retryData, _) = try await URLSession.shared.data(for: retryReq)
                    return retryData
                }
            }
            return data
        }
    }
}
