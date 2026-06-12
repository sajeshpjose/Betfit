// ============================================================
// ProfileManager.swift
// BetFit
// ============================================================
// Loads and saves user profile from/to Supabase `profiles` table.
//
// Required Supabase SQL (run once in the SQL Editor):
//
//   create table public.profiles (
//     id          uuid not null references auth.users(id) on delete cascade,
//     full_name   text,
//     handle      text,
//     company     text,
//     avatar_url  text,
//     updated_at  timestamptz default now(),
//     primary key (id)
//   );
//
//   alter table public.profiles enable row level security;
//
//   create policy "read own profile"
//     on public.profiles for select using (auth.uid() = id);
//   create policy "insert own profile"
//     on public.profiles for insert with check (auth.uid() = id);
//   create policy "update own profile"
//     on public.profiles for update using (auth.uid() = id);
// ============================================================

import Foundation
import Combine

// Shared config — keep in sync with SupabaseManager.swift
private let SUPABASE_URL = "https://jdaqkumsyvijqqgudbjj.supabase.co"
private let SUPABASE_KEY = "sb_publishable_QqaBpCWOr3z-rh7l7JZtDg_R_g-RHKn"

// ── Model
struct BFProfile: Codable {
    let id: String
    var fullName: String?
    var handle: String?
    var company: String?
    var avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName  = "full_name"
        case handle
        case company
        case avatarURL = "avatar_url"
    }
}

// ── Manager
@MainActor
final class ProfileManager: ObservableObject {

    static let shared = ProfileManager()

    @Published var fullName: String  = ""
    @Published var handle: String    = ""
    @Published var company: String   = ""
    @Published var avatarURL: String? = nil
    @Published var isLoading: Bool   = false
    @Published var errorMessage: String? = nil

    private init() {}

    // ── Load profile from Supabase on sign-in
    func load() async {
        guard let userId = AuthManager.shared.userId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await AuthManager.shared.get(
                path: "profiles?id=eq.\(userId)&select=*&limit=1"
            )
            let profiles = try JSONDecoder().decode([BFProfile].self, from: data)
            if let p = profiles.first {
                fullName  = p.fullName  ?? ""
                handle    = p.handle    ?? ""
                company   = p.company   ?? ""
                avatarURL = p.avatarURL
            }
        } catch {
            // Profile row may not exist yet — that's fine on first sign-in
        }
    }

        // ── Upload avatar image to Supabase Storage and return its public URL
    // Requires a public "avatars" bucket in Supabase Storage.
    // Create it via: Storage → New bucket → name "avatars" → Public ✓
    func uploadAvatar(imageData: Data) async throws -> String {
        guard let userId = AuthManager.shared.userId,
              let token  = AuthManager.shared.accessToken else {
            throw URLError(.userAuthenticationRequired)
        }

        let path    = "\(userId)/avatar.jpg"
        let urlStr  = "\(SUPABASE_URL)/storage/v1/object/avatars/\(path)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)",        forHTTPHeaderField: "Authorization")
        req.setValue(SUPABASE_KEY,             forHTTPHeaderField: "apikey")
        req.setValue("image/jpeg",             forHTTPHeaderField: "Content-Type")
        req.setValue("max-age=3600",           forHTTPHeaderField: "Cache-Control")
        req.setValue("upsert",                 forHTTPHeaderField: "x-upsert")  // overwrite on re-upload
        req.httpBody = imageData

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // Return the public URL
        let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/avatars/\(path)"
        avatarURL = publicURL
        return publicURL
    }

    // ── Save profile edits to Supabase (upsert)
    func save(fullName: String, handle: String, company: String) async throws {
        guard let userId = AuthManager.shared.userId else { return }
        isLoading = true
        defer { isLoading = false }

        let payload: [String: Any] = [
            "id":         userId,
            "full_name":  fullName,
            "handle":     handle,
            "company":    company,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]

        _ = try await AuthManager.shared.post(
            path: "profiles?on_conflict=id",
            body: payload,
            method: "POST"
        )

        self.fullName = fullName
        self.handle   = handle
        self.company  = company
    }
}
