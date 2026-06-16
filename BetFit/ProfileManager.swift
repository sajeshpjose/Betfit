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

    @Published var fullName: String   = ""
    @Published var handle: String     = ""
    @Published var company: String    = ""
    @Published var avatarURL: String? = nil
    @Published var isLoading: Bool    = false
    @Published var errorMessage: String? = nil

    // ── Stats
    @Published var streakDays:     Int    = 0
    @Published var challengeCount: Int    = 0
    @Published var bestFinish:     String = "—"

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
    func save(fullName: String, handle: String, company: String, avatarURL: String? = nil) async throws {
        guard let userId = AuthManager.shared.userId else { return }
        isLoading = true
        defer { isLoading = false }

        var payload: [String: Any] = [
            "id":         userId,
            "full_name":  fullName,
            "handle":     handle,
            "company":    company,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]

        if let avatarURL = avatarURL {
            payload["avatar_url"] = avatarURL
        }

        _ = try await AuthManager.shared.post(
            path: "profiles?on_conflict=id",
            body: payload,
            method: "POST"
        )

        self.fullName = fullName
        self.handle   = handle
        self.company  = company
        if let avatarURL = avatarURL {
            self.avatarURL = avatarURL
        }
    }

    // ── Fetch streak, challenge count, and best finish from Supabase
    func fetchStats() async {
        guard let userId = AuthManager.shared.userId else { return }
        async let streakTask     = fetchStreak(userId: userId)
        async let challengeTask  = fetchChallengeCount(userId: userId)
        async let bestTask       = fetchBestFinish(userId: userId)
        let (streak, count, best) = await (streakTask, challengeTask, bestTask)
        streakDays     = streak
        challengeCount = count
        bestFinish     = best
    }

    // ── Count consecutive days with steps > 0 working backwards from today
    private func fetchStreak(userId: String) async -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let from = Calendar.current.date(byAdding: .day, value: -60, to: Date()) else { return 0 }
        let fromStr = formatter.string(from: from)

        guard let data = try? await AuthManager.shared.get(
            path: "step_logs?user_id=eq.\(userId)&log_date=gte.\(fromStr)&select=log_date,step_count&order=log_date.desc"
        ) else { return 0 }

        struct LogRow: Codable {
            let logDate: String
            let stepCount: Int
            enum CodingKeys: String, CodingKey { case logDate = "log_date"; case stepCount = "step_count" }
        }
        let rows = (try? JSONDecoder().decode([LogRow].self, from: data)) ?? []
        let dateSet = Set(rows.filter { $0.stepCount > 0 }.map(\.logDate))

        var streak  = 0
        var check   = Date()
        let cal     = Calendar.current
        for _ in 0..<60 {
            if dateSet.contains(formatter.string(from: check)) {
                streak += 1
                check = cal.date(byAdding: .day, value: -1, to: check) ?? check
            } else {
                break
            }
        }
        return streak
    }

    // ── Count challenges the user has enrolled in
    private func fetchChallengeCount(userId: String) async -> Int {
        guard let data = try? await AuthManager.shared.get(
            path: "challenge_teams?created_by=eq.\(userId)&select=id"
        ) else { return 0 }
        struct Row: Codable { let id: UUID }
        return ((try? JSONDecoder().decode([Row].self, from: data)) ?? []).count
    }

    // ── Find best (lowest) rank achieved across all challenges
    private func fetchBestFinish(userId: String) async -> String {
        // Get user's team IDs
        guard let teamData = try? await AuthManager.shared.get(
            path: "challenge_teams?created_by=eq.\(userId)&select=id"
        ) else { return "—" }
        struct TeamRow: Codable { let id: UUID }
        let teams = (try? JSONDecoder().decode([TeamRow].self, from: teamData)) ?? []
        guard !teams.isEmpty else { return "—" }

        let ids = teams.map { $0.id.uuidString }.joined(separator: ",")

        // Query leaderboard for those teams — pick lowest rank
        guard let lbData = try? await AuthManager.shared.get(
            path: "challenge_leaderboard?team_id=in.(\(ids))&select=rank&order=rank.asc&limit=1"
        ) else { return "—" }
        struct RankRow: Codable { let rank: Int }
        guard let best = ((try? JSONDecoder().decode([RankRow].self, from: lbData)) ?? []).first else { return "—" }

        switch best.rank {
        case 1: return "🥇 1st"
        case 2: return "🥈 2nd"
        case 3: return "🥉 3rd"
        default: return "#\(best.rank)"
        }
    }
}
