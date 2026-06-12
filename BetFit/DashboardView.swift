// ============================================================
// DashboardView.swift — Dark Mode Fixed
// BetFit
// ============================================================

import SwiftUI

struct TeamMember: Identifiable {
    let id = UUID()
    let initials: String
    let name: String
    let steps: Int
    let avatarColor: Color
    let textColor: Color
}

struct LeaderboardRow: Identifiable {
    let id = UUID()
    let rank: Int
    let teamName: String
    let steps: Int
    let isYou: Bool
}

struct DashboardView: View {

    @StateObject private var sync = StepSyncManager.shared
    let challengeId = "00000000-0000-0000-0000-000000000001"
    let dailyGoal: Int = 10000

    let teamMembers: [TeamMember] = [
        TeamMember(initials: "SK", name: "You",     steps: 6241, avatarColor: .bfPrimary,            textColor: Color(hex: "#000000")),
        TeamMember(initials: "JT", name: "John T.", steps: 8102, avatarColor: Color(hex: "#2A2A2A"), textColor: Color(hex: "#AAAAAA")),
    ]

    let leaderboardRows: [LeaderboardRow] = [
        LeaderboardRow(rank: 1, teamName: "Alpha Movers",  steps: 15321, isYou: false),
        LeaderboardRow(rank: 2, teamName: "The Fast Pair", steps: 14343, isYou: true),
        LeaderboardRow(rank: 3, teamName: "Road Runners",  steps: 13890, isYou: false),
    ]

    var goalProgress: Double { min(Double(sync.todaySteps) / Double(dailyGoal), 1.0) }
    var teamTotalSteps: Int  { teamMembers.reduce(0) { $0 + $1.steps } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bfBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {

                        if let error = sync.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.bfWarning)
                                Text(error).font(.system(size: 12)).foregroundColor(.bfTextWeak)
                            }
                            .padding(12)
                            .background(Color.bfWarning.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        SectionLabel("Today")
                        StepRingCard(steps: sync.todaySteps, goal: dailyGoal, distanceKm: sync.todayDistanceKm, calories: Int(Double(sync.todaySteps) * 0.04), progress: goalProgress)

                        SectionLabel("Your team")
                        DarkTeamCard(teamName: "The Fast Pair", rank: 2, members: teamMembers, totalSteps: teamTotalSteps, goalSteps: 23000)

                        SectionLabel("Challenge")
                        DarkChallengeCard(challengeName: "June Wellness Sprint", company: "Acme Corp", daysLeft: 6, teamSteps: teamTotalSteps, rank: 2, behindBy: 980)

                        SectionLabel("Couch to 5K")
                        DarkC25KDashCard(day: 8, totalDays: 30)

                        SectionLabel("Leaderboard")
                        DarkMiniLeaderboard(rows: leaderboardRows)

                        if let synced = sync.lastSyncedAt {
                            Text("Synced \(synced.formatted(.relative(presentation: .named)))")
                                .font(.system(size: 10))
                                .foregroundColor(.bfTextMuted)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("BetFit").font(.system(size: 22, weight: .bold)).foregroundColor(.bfPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await sync.syncToday(challengeId: challengeId) } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.bfBgRaised)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.bfBorder, lineWidth: 0.5))
                    }
                }
            }
            .toolbarBackground(Color.bfBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                let granted = await sync.requestAuthorization()
                if granted {
                    await sync.syncToday(challengeId: challengeId)
                    sync.setupBackgroundDelivery(challengeId: challengeId)
                }
            }
            .refreshable { await sync.syncToday(challengeId: challengeId) }
        }
    }
}

// SectionLabel → use BFSectionLabel from Atoms.swift
typealias SectionLabel = BFSectionLabel

// ============================================================
// MARK: - Step Ring Card
// ============================================================
struct StepRingCard: View {
    let steps: Int
    let goal: Int
    let distanceKm: Double
    let calories: Int
    let progress: Double

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.bfPrimary.opacity(0.15), lineWidth: 10)
                    .frame(width: 96, height: 96)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.bfPrimary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: progress)
                VStack(spacing: 1) {
                    Text(steps.formatted()).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    Text("steps").font(.system(size: 9, weight: .medium)).foregroundColor(.bfTextWeak)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Goal: \(goal.formatted()) steps").font(.system(size: 11)).foregroundColor(.bfTextWeak)
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.1f km", distanceKm)).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        Text("Distance").font(.system(size: 10)).foregroundColor(.bfTextWeak)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(calories) cal").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        Text("Calories").font(.system(size: 10)).foregroundColor(.bfTextWeak)
                    }
                }
                BFProgressBar(progress: progress, height: 5)
                Text("\(Int(progress * 100))% of daily goal").font(.system(size: 10)).foregroundColor(.bfTextWeak)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.bfBgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bfBorder, lineWidth: 0.5))
    }
}

// ============================================================
// MARK: - Team Card (dark)
// ============================================================
struct DarkTeamCard: View {
    let teamName: String
    let rank: Int
    let members: [TeamMember]
    let totalSteps: Int
    let goalSteps: Int

    var progress: Double { min(Double(totalSteps) / Double(goalSteps), 1.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ACTIVE CHALLENGE").font(.system(size: 10, weight: .semibold)).foregroundColor(.bfPrimary)
                Spacer()
                Text("🏅 Rank #\(rank)").font(.system(size: 10, weight: .bold)).foregroundColor(.black)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.bfPrimary).clipShape(Capsule())
            }
            Text(teamName).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
            HStack(spacing: 20) {
                ForEach(members) { m in
                    HStack(spacing: 8) {
                        Circle().fill(m.avatarColor).frame(width: 32, height: 32)
                            .overlay(Text(m.initials).font(.system(size: 11, weight: .bold)).foregroundColor(m.textColor))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m.name).font(.system(size: 12, weight: .medium)).foregroundColor(Color(hex: "#AAAAAA"))
                            Text("\(m.steps.formatted()) steps").font(.system(size: 10)).foregroundColor(.bfTextMuted)
                        }
                    }
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(totalSteps.formatted()) team steps").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    Text("\(Int(progress * 100))% of goal").font(.system(size: 11)).foregroundColor(.bfTextMuted)
                }
                BFProgressBar(progress: progress, height: 5)
            }
        }
        .padding(16)
        .background(Color(hex: "#111111"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bfBorder, lineWidth: 0.5))
    }
}

// ============================================================
// MARK: - Challenge Card (dark)
// ============================================================
struct DarkChallengeCard: View {
    let challengeName: String
    let company: String
    let daysLeft: Int
    let teamSteps: Int
    let rank: Int
    let behindBy: Int

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.bfPrimary.opacity(0.12)
                HStack {
                    Text("🏢").font(.system(size: 28))
                    Spacer()
                    Text("\(daysLeft) days left").font(.system(size: 10, weight: .bold)).foregroundColor(.black)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.bfPrimary).clipShape(Capsule())
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 64)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(challengeName).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    Text("\(company) · 50 teams competing").font(.system(size: 11)).foregroundColor(.bfTextWeak)
                }
                Divider().background(Color.bfBorder)
                HStack {
                    DarkStatItem(value: "\(teamSteps.formatted())", label: "Team steps")
                    Divider().frame(height: 28).background(Color.bfBorder)
                    DarkStatItem(value: "#\(rank)", label: "Rank")
                    Divider().frame(height: 28).background(Color.bfBorder)
                    DarkStatItem(value: "\(behindBy.formatted())", label: "Behind #1")
                }
            }
            .padding(16)
            .background(Color.bfBgRaised)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bfBorder, lineWidth: 0.5))
    }
}

private struct DarkStatItem: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 10)).foregroundColor(.bfTextWeak)
        }
        .frame(maxWidth: .infinity)
    }
}

// ============================================================
// MARK: - C25K Dash Card (dark)
// ============================================================
struct DarkC25KDashCard: View {
    let day: Int
    let totalDays: Int
    let segments: [(type: String, flex: CGFloat)] = [
        ("walk", 3), ("run", 2), ("walk", 2), ("run", 2), ("walk", 2), ("run", 2), ("walk", 2)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's workout").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text("Day \(day) of \(totalDays)").font(.system(size: 11)).foregroundColor(.bfTextWeak)
            }
            GeometryReader { geo in
                let totalFlex = segments.reduce(0) { $0 + $1.flex }
                HStack(spacing: 3) {
                    ForEach(segments.indices, id: \.self) { i in
                        let seg = segments[i]
                        let w = (seg.flex / totalFlex) * (geo.size.width - CGFloat(segments.count - 1) * 3)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(seg.type == "run" ? Color.bfPrimary : Color.bfPrimary.opacity(0.15))
                            .frame(width: w, height: 20)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bfBorder, lineWidth: 0.5))
                    }
                }
            }
            .frame(height: 20)
            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.bfPrimary.opacity(0.15)).frame(width: 10, height: 10)
                    Text("Walk").font(.system(size: 10)).foregroundColor(.bfTextWeak)
                }
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.bfPrimary).frame(width: 10, height: 10)
                    Text("Run").font(.system(size: 10)).foregroundColor(.bfTextWeak)
                }
                Spacer()
                Text("~28 min total").font(.system(size: 10)).foregroundColor(.bfTextWeak)
            }
            Button(action: {}) {
                Text("Start today's session")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(Color.bfPrimary).clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color.bfBgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bfBorder, lineWidth: 0.5))
    }
}

// ============================================================
// MARK: - Mini Leaderboard (dark)
// ============================================================
struct DarkMiniLeaderboard: View {
    let rows: [LeaderboardRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Leaderboard").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text("See all →").font(.system(size: 11, weight: .medium)).foregroundColor(.bfTextWeak)
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)

            VStack(spacing: 6) {
                ForEach(rows) { row in
                    BFLeaderboardRow(
                        rank: row.rank,
                        teamName: row.teamName,
                        member1: "", member2: "",
                        steps: row.steps,
                        distanceKm: 0,
                        isYou: row.isYou,
                        compact: true
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.bfBgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bfBorder, lineWidth: 0.5))
    }
}

#Preview { DashboardView() }
