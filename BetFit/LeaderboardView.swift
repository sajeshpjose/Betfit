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
    @State private var selectedFilter: LeaderboardFilter = .teams

    let teams: [LeaderboardTeam] = [
        LeaderboardTeam(rank: 1, teamName: "Alpha Movers",   member1: "Amir M.",   member2: "Priya K.",  steps: 15321, distanceKm: 10.2, isYou: false),
        LeaderboardTeam(rank: 2, teamName: "The Fast Pair",  member1: "Sajesh",    member2: "John T.",   steps: 14343, distanceKm: 9.5,  isYou: true),
        LeaderboardTeam(rank: 3, teamName: "Road Runners",   member1: "Rania N.",  member2: "Chris L.",  steps: 13890, distanceKm: 9.2,  isYou: false),
        LeaderboardTeam(rank: 4, teamName: "Brisk Walkers",  member1: "Ben W.",    member2: "Leo M.",    steps: 12100, distanceKm: 8.0,  isYou: false),
        LeaderboardTeam(rank: 5, teamName: "Step Squad",     member1: "Sara F.",   member2: "Tim G.",    steps: 11450, distanceKm: 7.6,  isYou: false),
        LeaderboardTeam(rank: 6, teamName: "Morning Crew",   member1: "Maya R.",   member2: "Nav P.",    steps: 10980, distanceKm: 7.3,  isYou: false),
        LeaderboardTeam(rank: 7, teamName: "Duo Dynamos",    member1: "Dan K.",    member2: "Eve J.",    steps: 10210, distanceKm: 6.8,  isYou: false),
        LeaderboardTeam(rank: 8, teamName: "Hustle & Grind", member1: "Hannah L.", member2: "Omar B.",   steps: 9870,  distanceKm: 6.5,  isYou: false),
    ]

    var yourTeam: LeaderboardTeam? { teams.first { $0.isYou } }
    var top3: [LeaderboardTeam] { Array(teams.prefix(3)) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bfBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        DarkPodiumView(teams: top3)
                            .padding(.bottom, 12)

                        VStack(spacing: 10) {
                            if let you = yourTeam {
                                YourPositionBanner(team: you, behindBy: 978)
                            }
                            HStack {
                                Text("All teams · 50 competing")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.bfTextMuted)
                                    .textCase(.uppercase).tracking(0.6)
                                Spacer()
                            }
                            .padding(.horizontal, 2)

                            VStack(spacing: 8) {
                                ForEach(teams) { team in
                                    DarkLeaderboardRowView(team: team)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Leaderboard").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("6 days left").font(.system(size: 10, weight: .bold)).foregroundColor(.black)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.bfPrimary).clipShape(Capsule())
                }
            }
            .toolbarBackground(Color.bfBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                DarkFilterTabBar(selected: $selectedFilter).background(Color.bfBg)
            }
        }
    }
}

// DarkFilterTabBar → use BFFilterTabBar from Molecules.swift
typealias DarkFilterTabBar = BFFilterTabBar<LeaderboardFilter>

struct DarkPodiumView: View {
    let teams: [LeaderboardTeam]
    var podiumOrder: [LeaderboardTeam] {
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
    let team: LeaderboardTeam
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
    let team: LeaderboardTeam
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
    let team: LeaderboardTeam
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
