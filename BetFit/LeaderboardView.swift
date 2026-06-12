// ============================================================
// LeaderboardView.swift — Dark Mode Fixed
// BetFit
// ============================================================

import SwiftUI

struct LeaderboardTeam: Identifiable {
    let id = UUID()
    let rank: Int
    let teamName: String
    let member1: String
    let member2: String
    let steps: Int
    let distanceKm: Double
    let isYou: Bool
}

enum LeaderboardFilter: String, CaseIterable {
    case teams = "Teams", individual = "Individual", thisWeek = "This week", allTime = "All time"
}

struct LeaderboardView: View {
    // Optional — pass a challengeId to show a specific challenge's leaderboard.
    // When nil, shows the user's first enrolled challenge.
    var challengeId: UUID? = nil

    @StateObject private var manager = ChallengeManager.shared
    @State private var selectedFilter: LeaderboardFilter = .teams

    private var activeChallengeId: UUID? {
        challengeId ?? manager.enrolledChallenges.first?.id
    }
    private var entries: [ChallengeLeaderboardEntry] {
        guard let id = activeChallengeId else { return [] }
        return manager.leaderboards[id.uuidString] ?? []
    }
    private var yourEntry: ChallengeLeaderboardEntry? { entries.first { $0.isYou } }
    private var top3: [ChallengeLeaderboardEntry]     { Array(entries.prefix(3)) }
    private var challenge: BFChallenge? {
        guard let id = activeChallengeId else { return nil }
        return manager.enrolledChallenges.first { $0.id == id }
            ?? manager.publicChallenges.first   { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bfBg.ignoresSafeArea()

                if entries.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView().tint(.bfPrimary)
                        Text("Loading leaderboard…")
                            .font(.system(size: 13))
                            .foregroundColor(.bfTextWeak)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Text("Leaderboard")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                                .padding(.bottom, 8)

                            DarkPodiumView(teams: top3)
                                .padding(.bottom, 12)

                            VStack(spacing: 10) {
                                if let you = yourEntry {
                                    YourPositionBanner(team: you, behindBy: yourBehindBy)
                                }

                                HStack {
                                    Text("All teams · \(entries.count) competing")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.bfTextMuted)
                                        .textCase(.uppercase).tracking(0.6)
                                    Spacer()
                                }
                                .padding(.horizontal, 2)

                                VStack(spacing: 8) {
                                    ForEach(entries) { entry in
                                        BFLeaderboardRow(
                                            rank: entry.rank,
                                            teamName: entry.teamName,
                                            member1: entry.member1,
                                            member2: entry.member2,
                                            steps: entry.steps,
                                            distanceKm: entry.distanceKm,
                                            isYou: entry.isYou
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 100)
                        }
                    }
                    .refreshable {
                        if let id = activeChallengeId {
                            await manager.loadLeaderboard(for: id)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let c = challenge, c.daysLeft > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("\(c.daysLeft) days left")
                            .font(.system(size: 10, weight: .bold)).foregroundColor(.black)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.bfPrimary).clipShape(Capsule())
                    }
                }
            }
            .toolbarBackground(Color.bfBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                DarkFilterTabBar(selected: $selectedFilter).background(Color.bfBg)
            }
            .task {
                if let id = activeChallengeId {
                    await manager.loadLeaderboard(for: id)
                }
            }
        }
    }

    private var yourBehindBy: Int {
        guard let you = yourEntry, you.rank > 1,
              let above = entries.first(where: { $0.rank == you.rank - 1 })
        else { return 0 }
        return max(0, above.steps - you.steps)
    }
}

// DarkFilterTabBar → use BFFilterTabBar from Molecules.swift
typealias DarkFilterTabBar = BFFilterTabBar<LeaderboardFilter>

struct DarkPodiumView: View {
    let teams: [ChallengeLeaderboardEntry]
    var podiumOrder: [ChallengeLeaderboardEntry] {
        guard teams.count >= 3 else { return teams }
        return [teams[1], teams[0], teams[2]]
    }
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bfBg
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(podiumOrder) { team in
                    DarkPodiumItem(team: team)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 200)
    }
}

struct DarkPodiumItem: View {
    let team: ChallengeLeaderboardEntry
    var blockHeight: CGFloat { team.rank == 1 ? 80 : team.rank == 2 ? 58 : 44 }
    var blockColor: Color {
        team.rank == 1 ? Color.bfPrimary : team.rank == 2 ? Color(hex: "#2A2A2A") : Color(hex: "#1E1E1E")
    }
    var rankLabelColor: Color { team.rank == 1 ? .black : (team.rank == 2 ? .white : Color(hex: "#555555")) }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: -6) {
                Circle().fill(team.isYou ? Color.bfPrimary : Color(hex: "#2A2A2A")).frame(width: 26, height: 26)
                Circle().fill(Color(hex: "#1E1E1E")).frame(width: 26, height: 26).overlay(Circle().stroke(Color.bfBg, lineWidth: 1.5))
            }
            Text(team.teamName).font(.system(size: 9, weight: .semibold)).foregroundColor(Color(hex: "#888888")).lineLimit(1).minimumScaleFactor(0.8)
            Text(team.steps.formatted()).font(.system(size: 9)).foregroundColor(.bfTextMuted)
            RoundedRectangle(cornerRadius: 8).fill(blockColor).frame(height: blockHeight)
                .overlay(Text(team.rank == 1 ? "🥇" : "\(team.rank)").font(.system(size: team.rank == 1 ? 20 : 14, weight: .bold)).foregroundColor(rankLabelColor))
        }
        .frame(maxWidth: .infinity)
    }
}

// DarkLeaderboardRowView → use BFLeaderboardRow from Molecules.swift
private struct DarkLeaderboardRowView: View {
    let team: ChallengeLeaderboardEntry
    var body: some View {
        BFLeaderboardRow(
            rank: team.rank,
            teamName: team.teamName,
            member1: team.member1,
            member2: team.member2,
            steps: team.steps,
            distanceKm: team.distanceKm,
            isYou: team.isYou
        )
    }
}

struct YourPositionBanner: View {
    let team: ChallengeLeaderboardEntry
    let behindBy: Int

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Position · #\(team.rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.bfPrimary)
                Text(team.teamName)
                    .font(.system(size: 11))
                    .foregroundColor(.bfTextMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(team.steps.formatted())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text("\(behindBy.formatted()) behind #\(team.rank - 1)")
                    .font(.system(size: 10))
                    .foregroundColor(.bfTextMuted)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.bfPrimary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.bfPrimary.opacity(0.4), lineWidth: 0.5))
    }
}

#Preview { LeaderboardView() }
