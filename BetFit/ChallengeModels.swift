// ============================================================
// ChallengeModels.swift
// BetFit
// ============================================================
// Data models for the Challenges feature.
//
// Required Supabase SQL (run in SQL Editor):
//
//   create table public.challenges (
//     id              uuid default gen_random_uuid() primary key,
//     name            text not null,
//     description     text,
//     type            text not null default 'steps',  -- 'steps' | 'distance' | 'c25k'
//     team_size_min   int  not null default 2,
//     team_size_max   int  not null default 2,        -- 2–5
//     daily_goal      int  not null default 10000,
//     start_date      date not null,
//     end_date        date not null,
//     is_public       bool not null default true,
//     company         text,
//     banner_emoji    text default '🏃',
//     total_teams     int  generated always as (0) stored,  -- updated via trigger
//     created_at      timestamptz default now()
//   );
//
//   create table public.challenge_teams (
//     id           uuid default gen_random_uuid() primary key,
//     challenge_id uuid not null references public.challenges(id) on delete cascade,
//     name         text not null,
//     created_by   uuid not null references auth.users(id),
//     created_at   timestamptz default now(),
//     unique(challenge_id, created_by)
//   );
//
//   create table public.challenge_team_members (
//     id         uuid default gen_random_uuid() primary key,
//     team_id    uuid not null references public.challenge_teams(id) on delete cascade,
//     user_id    uuid not null references auth.users(id),
//     joined_at  timestamptz default now(),
//     unique(team_id, user_id)
//   );
//
//   -- RLS
//   alter table public.challenges enable row level security;
//   create policy "public challenges visible to all authenticated"
//     on public.challenges for select to authenticated using (is_public = true);
//
//   alter table public.challenge_teams enable row level security;
//   create policy "team members can view" on public.challenge_teams
//     for select using (auth.uid() = created_by);
//   create policy "authenticated users can create teams"
//     on public.challenge_teams for insert with check (auth.uid() = created_by);
//
//   alter table public.challenge_team_members enable row level security;
//   create policy "members can view" on public.challenge_team_members
//     for select using (true);
//   create policy "users can join teams" on public.challenge_team_members
//     for insert with check (auth.uid() = user_id);
// ============================================================

import Foundation

// ── Challenge type
enum ChallengeType: String, Codable {
    case steps    = "steps"
    case distance = "distance"
    case c25k     = "c25k"

    var label: String {
        switch self { case .steps: "Steps"; case .distance: "Distance"; case .c25k: "Couch to 5K" }
    }
    var icon: String {
        switch self { case .steps: "👟"; case .distance: "📍"; case .c25k: "🏃" }
    }
}

// ── A challenge created by an admin
struct BFChallenge: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let type: ChallengeType
    let teamSizeMin: Int
    let teamSizeMax: Int
    let dailyGoal: Int
    let startDate: String      // "yyyy-MM-dd"
    let endDate: String
    let isPublic: Bool
    let company: String?
    let bannerEmoji: String?
    var totalTeams: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, description, type, company
        case teamSizeMin  = "team_size_min"
        case teamSizeMax  = "team_size_max"
        case dailyGoal    = "daily_goal"
        case startDate    = "start_date"
        case endDate      = "end_date"
        case isPublic     = "is_public"
        case bannerEmoji  = "banner_emoji"
        case totalTeams   = "total_teams"
    }

    // Convenience
    var daysLeft: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let end = formatter.date(from: endDate) else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0)
    }

    var teamSizeLabel: String {
        teamSizeMin == teamSizeMax ? "\(teamSizeMin) members" : "\(teamSizeMin)–\(teamSizeMax) members"
    }
}

// ── A team enrolled in a challenge
struct BFChallengeTeam: Identifiable, Codable {
    let id: UUID
    let challengeId: UUID
    let name: String
    let createdBy: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case challengeId = "challenge_id"
        case createdBy   = "created_by"
    }
}

// ── Leaderboard row returned from a view/query
struct ChallengeLeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let teamName: String
    let member1: String
    let member2: String
    let steps: Int
    let distanceKm: Double
    let isYou: Bool
}

// ── Leaderboard row returned from the `challenge_leaderboard` Supabase view.
//
// Required Supabase SQL (run in SQL Editor):
//
//   create or replace view public.challenge_leaderboard as
//   select
//     ct.id                                                       as team_id,
//     ct.challenge_id,
//     ct.name                                                     as team_name,
//     coalesce(sum(sl.step_count), 0)::int                       as total_steps,
//     coalesce(sum(sl.distance_km), 0)::float                    as total_distance_km,
//     rank() over (
//       partition by ct.challenge_id
//       order by coalesce(sum(sl.step_count), 0) desc
//     )::int                                                      as rank
//   from public.challenge_teams ct
//   left join public.challenge_team_members ctm on ctm.team_id = ct.id
//   left join public.step_logs sl
//     on  sl.user_id      = ctm.user_id
//     and sl.challenge_id = ct.challenge_id
//   group by ct.id, ct.challenge_id, ct.name;
//
//   -- Allow authenticated users to read leaderboard data
//   grant select on public.challenge_leaderboard to authenticated;

struct LeaderboardAPIRow: Identifiable, Codable {
    let teamId: UUID
    let challengeId: UUID
    let teamName: String
    let totalSteps: Int
    let totalDistanceKm: Double
    let rank: Int

    var id: UUID { teamId }

    enum CodingKeys: String, CodingKey {
        case teamId          = "team_id"
        case challengeId     = "challenge_id"
        case teamName        = "team_name"
        case totalSteps      = "total_steps"
        case totalDistanceKm = "total_distance_km"
        case rank
    }

    func toEntry(myTeamId: UUID?) -> ChallengeLeaderboardEntry {
        ChallengeLeaderboardEntry(
            rank:        rank,
            teamName:    teamName,
            member1:     "",
            member2:     "",
            steps:       totalSteps,
            distanceKm:  totalDistanceKm,
            isYou:       myTeamId == teamId
        )
    }
}

// ── Sample data used while real data loads
extension BFChallenge {
    static let samples: [BFChallenge] = [
        BFChallenge(id: UUID(), name: "June Wellness Sprint",  description: "Walk your way to the top this June. Teams of 2 compete for the most steps across the month.",  type: .steps,    teamSizeMin: 2, teamSizeMax: 2, dailyGoal: 10000, startDate: "2026-06-01", endDate: "2026-06-30", isPublic: true, company: "Acme Corp",   bannerEmoji: "🏃", totalTeams: 50),
        BFChallenge(id: UUID(), name: "Summer Distance Cup",   description: "Log the most kilometres walked or run. Teams of up to 3.",                                        type: .distance, teamSizeMin: 2, teamSizeMax: 3, dailyGoal: 8000,  startDate: "2026-07-01", endDate: "2026-07-31", isPublic: true, company: nil,           bannerEmoji: "📍", totalTeams: 24),
        BFChallenge(id: UUID(), name: "Couch to 5K Program",   description: "A structured 30-day running plan for all levels. Complete sessions solo or with a partner.",     type: .c25k,     teamSizeMin: 1, teamSizeMax: 2, dailyGoal: 5000,  startDate: "2026-06-15", endDate: "2026-07-15", isPublic: true, company: nil,           bannerEmoji: "🏅", totalTeams: 18),
        BFChallenge(id: UUID(), name: "Q3 Company Step-Off",   description: "Thamzi's internal quarterly step challenge. All employees welcome.",                              type: .steps,    teamSizeMin: 2, teamSizeMax: 4, dailyGoal: 12000, startDate: "2026-07-01", endDate: "2026-09-30", isPublic: false,company: "Thamzi",      bannerEmoji: "⚡", totalTeams: 12),
        BFChallenge(id: UUID(), name: "Weekend Warriors",      description: "Short sharp 4-week challenge. Only weekend steps count.",                                         type: .steps,    teamSizeMin: 2, teamSizeMax: 5, dailyGoal: 15000, startDate: "2026-06-21", endDate: "2026-07-20", isPublic: true, company: nil,           bannerEmoji: "🔥", totalTeams: 31),
    ]
}
