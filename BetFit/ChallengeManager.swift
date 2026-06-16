// ============================================================
// ChallengeManager.swift
// BetFit
// ============================================================
// Fetches challenges, teams, and members from Supabase.
// ============================================================

import Foundation
import Combine

@MainActor
final class ChallengeManager: ObservableObject {

    static let shared = ChallengeManager()

    @Published var publicChallenges: [BFChallenge]   = []
    @Published var enrolledChallenges: [BFChallenge] = []
    @Published var myTeams: [String: BFChallengeTeam] = [:]          // keyed by challenge id
    @Published var teamMembers: [String: [BFTeamMember]] = [:]       // keyed by team id
    @Published var leaderboards: [String: [ChallengeLeaderboardEntry]] = [:] // keyed by challenge id
    @Published var isLoading  = false
    @Published var errorMessage: String? = nil

    private init() {}

    // ── Load all public challenges + user's enrolled challenges
    func loadChallenges() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let publicTask   = fetchPublicChallenges()
        async let enrolledTask = fetchEnrolledChallenges()

        let (pub, enrolled) = await (publicTask, enrolledTask)
        publicChallenges   = pub
        enrolledChallenges = enrolled

        // Schedule local end-date warnings for enrolled challenges
        scheduleEndingWarnings(for: enrolled)
    }

    // ── All public challenges
    private func fetchPublicChallenges() async -> [BFChallenge] {
        do {
            let data = try await AuthManager.shared.get(
                path: "challenges?is_public=eq.true&select=*&order=start_date.asc"
            )
            let challenges = (try? JSONDecoder().decode([BFChallenge].self, from: data)) ?? []
            print("✓ Fetched \(challenges.count) public challenges")
            return challenges
        } catch {
            print("✗ Error fetching public challenges: \(error)")
            return []
        }
    }

    // ── Challenges the current user has a team in
    private func fetchEnrolledChallenges() async -> [BFChallenge] {
        guard let userId = AuthManager.shared.userId else { return [] }
        do {
            let data = try await AuthManager.shared.get(
                path: "challenge_teams?created_by=eq.\(userId)&select=challenge_id,challenges(*)"
            )
            struct Row: Codable { let challenge: BFChallenge?; enum CodingKeys: String, CodingKey { case challenge = "challenges" } }
            let rows = (try? JSONDecoder().decode([Row].self, from: data)) ?? []
            return rows.compactMap(\.challenge)
        } catch {
            return []
        }
    }

    // ── Create a team and enroll in a challenge
    func enroll(challengeId: UUID, teamName: String) async throws {
        guard let userId = AuthManager.shared.userId else { throw URLError(.userAuthenticationRequired) }

        let payload: [String: Any] = [
            "challenge_id": challengeId.uuidString,
            "name":         teamName,
            "created_by":   userId
        ]
        let data = try await AuthManager.shared.post(
            path: "challenge_teams",
            body: payload,
            method: "POST"
        )

        // Parse returned team and cache it
        guard let team = try? JSONDecoder().decode(BFChallengeTeam.self, from: data) else {
            print("❌ Failed to decode created team")
            throw URLError(.badServerResponse)
        }

        myTeams[challengeId.uuidString] = team
        print("✓ Created team: \(team.name)")

        // Auto-add the creator as first member
        do {
            try await addMember(teamId: team.id, userId: userId)
            print("✓ Added user as team member")
        } catch {
            print("❌ Failed to add user as member: \(error)")
            throw error
        }

        // Load the updated team with members to populate the UI
        await loadTeam(for: challengeId)

        // Refresh challenge lists
        await loadChallenges()
    }

    // ── Add a user to a team (called after enroll or when invite is accepted)
    func addMember(teamId: UUID, userId: String) async throws {
        let payload: [String: Any] = [
            "team_id": teamId.uuidString,
            "user_id": userId
        ]
        _ = try await AuthManager.shared.post(
            path: "challenge_team_members",
            body: payload,
            method: "POST"
        )
    }

    // ── Load team + members for a specific challenge
    func loadTeam(for challengeId: UUID) async {
        guard let userId = AuthManager.shared.userId else { return }

        // Fetch user's team in this challenge
        do {
            let teamData = try await AuthManager.shared.get(
                path: "challenge_teams?challenge_id=eq.\(challengeId.uuidString)&created_by=eq.\(userId)&select=*&limit=1"
            )
            let teams = (try? JSONDecoder().decode([BFChallengeTeam].self, from: teamData)) ?? []
            guard let team = teams.first else {
                print("❌ No team found for challenge \(challengeId) created by user \(userId)")
                return
            }
            myTeams[challengeId.uuidString] = team
            print("✓ Loaded team: \(team.name) (id: \(team.id))")

            // Fetch members of that team joined with their profiles
            // Using the explicit join syntax: challenge_team_members → auth.users → profiles
            let memberData = try await AuthManager.shared.get(
                path: "challenge_team_members?team_id=eq.\(team.id.uuidString)&select=user_id,profiles!inner(full_name,handle,avatar_url)"
            )

            do {
                let members = try JSONDecoder().decode([BFTeamMember].self, from: memberData)
                print("✓ Loaded \(members.count) team members")
                teamMembers[team.id.uuidString] = members
            } catch let decodingError {
                print("❌ Failed to decode team members: \(decodingError)")
                print("Raw response: \(String(data: memberData, encoding: .utf8) ?? "unable to decode")")
                teamMembers[team.id.uuidString] = []
            }
        } catch {
            print("❌ loadTeam error: \(error)")
        }
    }

    // ── Fetch leaderboard from the `challenge_leaderboard` Supabase view
    func loadLeaderboard(for challengeId: UUID) async {
        let myTeamId = myTeams[challengeId.uuidString]?.id
        do {
            let data = try await AuthManager.shared.get(
                path: "challenge_leaderboard?challenge_id=eq.\(challengeId.uuidString)&order=rank.asc"
            )
            let rows = (try? JSONDecoder().decode([LeaderboardAPIRow].self, from: data)) ?? []
            leaderboards[challengeId.uuidString] = rows.map { $0.toEntry(myTeamId: myTeamId) }
        } catch {
            print("loadLeaderboard error: \(error)")
        }
    }

    // ── Convenience: top N entries for a challenge (used by dashboard mini-leaderboard)
    func topEntries(for challengeId: String, limit: Int = 3) -> [ChallengeLeaderboardEntry] {
        Array((leaderboards[challengeId] ?? []).prefix(limit))
    }

    private func scheduleEndingWarnings(for challenges: [BFChallenge]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for challenge in challenges {
            guard let endDate = formatter.date(from: challenge.endDate) else { continue }
            NotificationManager.shared.scheduleChallengeEndingWarning(
                challengeName: challenge.name,
                endDate: endDate
            )
        }
    }

    func isEnrolled(in challengeId: UUID) -> Bool {
        enrolledChallenges.contains { $0.id == challengeId }
    }
}

// ── Team member model (joined with profiles)
struct BFTeamMember: Identifiable, Codable {
    let userId: String
    let profile: MemberProfile?

    var id: String { userId }  // Use userId as stable identifier

    var displayName: String { profile?.fullName ?? "Unknown" }
    var handle: String      { profile?.handle    ?? "" }
    var initials: String {
        let parts = displayName.split(separator: " ")
        return parts.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    struct MemberProfile: Codable {
        let fullName: String?
        let handle: String?
        let avatarURL: String?
        enum CodingKeys: String, CodingKey {
            case fullName  = "full_name"
            case handle
            case avatarURL = "avatar_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case userId  = "user_id"
        case profile = "profiles"
    }
}
