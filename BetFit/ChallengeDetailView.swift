// ============================================================
// ChallengeDetailView.swift
// BetFit
// ============================================================

import SwiftUI

struct ChallengeDetailView: View {
    let challenge: BFChallenge
    let isEnrolled: Bool
    var onEnroll: () -> Void = {}

    @StateObject private var manager = ChallengeManager.shared
    @State private var showEnrollSheet = false
    @Environment(\.dismiss) private var dismiss

    private var leaderboard: [ChallengeLeaderboardEntry] {
        manager.leaderboards[challenge.id.uuidString] ?? []
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bfBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // ── Page title (full width, no toolbar clipping)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        if let company = challenge.company {
                            Text(company)
                                .font(.system(size: 13))
                                .foregroundColor(.bfTextWeak)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                    // ── Hero banner
                    HeroBanner(challenge: challenge)

                    VStack(spacing: 16) {

                        // ── About
                        if let desc = challenge.description {
                            VStack(alignment: .leading, spacing: 6) {
                                BFSectionLabel("About")
                                Text(desc)
                                    .font(.system(size: 13))
                                    .foregroundColor(.bfTextWeak)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .bfCard()
                        }

                        // ── Details grid
                        VStack(alignment: .leading, spacing: 10) {
                            BFSectionLabel("Details")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                BFStatBox(value: challenge.teamSizeLabel,   label: "Team size")
                                BFStatBox(value: challenge.type.label,      label: "Type")
                                BFStatBox(value: "\(challenge.dailyGoal.formatted())", label: "Daily goal (steps)")
                                BFStatBox(value: "\(challenge.daysLeft) days",          label: "Days remaining")
                                if let company = challenge.company {
                                    BFStatBox(value: company, label: "Organisation")
                                }
                                BFStatBox(value: "\(challenge.totalTeams ?? 0)", label: "Teams enrolled")
                            }
                        }
                        .bfCard()

                        // ── Your team (if enrolled)
                        if isEnrolled {
                            YourTeamCard(challenge: challenge)
                        }

                        // ── Leaderboard
                        VStack(alignment: .leading, spacing: 10) {
                            BFSectionLabel("Leaderboard")
                            if leaderboard.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        ProgressView().tint(.bfPrimary)
                                        Text("Loading leaderboard…")
                                            .font(.system(size: 12))
                                            .foregroundColor(.bfTextMuted)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                            } else {
                                VStack(spacing: 6) {
                                    ForEach(leaderboard) { entry in
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
                        }
                        .bfCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, isEnrolled ? 40 : 120)
                }
            }

            // ── Join button (only when not enrolled)
            if !isEnrolled {
                VStack(spacing: 0) {
                    Divider().background(Color.bfBorder)
                    BFButton(
                        label: "Join Challenge",
                        variant: .primary,
                        fullWidth: true,
                        action: { showEnrollSheet = true }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.bfBg)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bfBg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await manager.loadLeaderboard(for: challenge.id)
            if isEnrolled { await manager.loadTeam(for: challenge.id) }
        }
        .refreshable {
            await manager.loadLeaderboard(for: challenge.id)
        }
        .sheet(isPresented: $showEnrollSheet) {
            EnrollSheet(challenge: challenge) {
                onEnroll()
                showEnrollSheet = false
            }
        }
    }
}

// ============================================================
// MARK: - Hero Banner
// ============================================================

private struct HeroBanner: View {
    let challenge: BFChallenge
    var body: some View {
        ZStack {
            Color.bfPrimary.opacity(0.12)
            VStack(spacing: 8) {
                Text(challenge.bannerEmoji ?? "🏃")
                    .font(.system(size: 52))
                Text(challenge.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    BFBadge(label: challenge.type.label, variant: .brand)
                    if challenge.daysLeft > 0 {
                        BFBadge(label: "\(challenge.daysLeft) days left", variant: .neutral)
                    }
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
        }
    }
}

// ============================================================
// MARK: - Your Team Card (enrolled view)
// ============================================================

private struct YourTeamCard: View {
    let challenge: BFChallenge
    @StateObject private var manager = ChallengeManager.shared
    @StateObject private var stepSync = StepSyncManager.shared
    @State private var showShareSheet = false

    private var team: BFChallengeTeam? { manager.myTeams[challenge.id.uuidString] }
    private var teamName: String { team?.name ?? "Your Team" }
    private var teamId: String { team?.id.uuidString ?? "" }
    private var members: [BFTeamMember] { manager.teamMembers[teamId] ?? [] }
    private var spotsLeft: Int { max(0, challenge.teamSizeMax - members.count) }
    private var inviteCode: String { String(teamId.prefix(8)).uppercased() }
    private var inviteURL: String { "https://habet.app/join/\(teamId)" }
    private var total: Int { stepSync.todaySteps }
    private var progress: Double { min(Double(total) / Double(challenge.dailyGoal * max(members.count, 1)), 1.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    BFSectionLabel("Your Team")
                    Text(teamName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                if spotsLeft > 0 {
                    Button(action: { showShareSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.plus")
                            Text("Add member")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.bfPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.bfPrimary.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }

            // ── Avatar stack + empty slots
            HStack(spacing: -10) {
                ForEach(members) { member in
                    let isYou = member.userId == AuthManager.shared.userId
                    BFAvatar(
                        initials: member.initials,
                        size: .md,
                        color: isYou ? .bfPrimary : Color(hex: "#2A2A2A"),
                        textColor: isYou ? .bfTextOnPrimary : Color(hex: "#AAAAAA")
                    )
                    .overlay(Circle().stroke(Color.bfBg, lineWidth: 2))
                }
                ForEach(0..<spotsLeft, id: \.self) { _ in
                    Button(action: { showShareSheet = true }) {
                        ZStack {
                            Circle().fill(Color.bfBgElevated)
                                .frame(width: 48, height: 48)
                                .overlay(Circle().stroke(Color.bfBorder.opacity(0.6), lineWidth: 1))
                            Image(systemName: "plus")
                                .font(.system(size: 14))
                                .foregroundColor(.bfTextMuted)
                        }
                        .overlay(Circle().stroke(Color.bfBg, lineWidth: 2))
                    }
                }
                if spotsLeft > 0 {
                    Text("\(spotsLeft) spot\(spotsLeft > 1 ? "s" : "") open")
                        .font(.system(size: 11))
                        .foregroundColor(.bfTextMuted)
                        .padding(.leading, 16)
                }
            }

            // ── Member list
            if members.isEmpty {
                Text("Loading team members…")
                    .font(.system(size: 12))
                    .foregroundColor(.bfTextMuted)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(members.enumerated()), id: \.element.id) { i, member in
                        let isYou = member.userId == AuthManager.shared.userId
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(member.displayName)
                                        .font(.system(size: 13, weight: isYou ? .semibold : .regular))
                                        .foregroundColor(isYou ? .bfPrimary : .white)
                                    if isYou { Text("· You").font(.system(size: 11)).foregroundColor(.bfTextMuted) }
                                }
                                Text(member.handle)
                                    .font(.system(size: 11))
                                    .foregroundColor(.bfTextMuted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(isYou ? stepSync.todaySteps.formatted() : "—")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text("steps today")
                                    .font(.system(size: 10))
                                    .foregroundColor(.bfTextMuted)
                            }
                        }
                        .padding(.vertical, 10)
                        if i < members.count - 1 { Divider().background(Color.bfBorder) }
                    }
                }
            }

            // ── Team progress
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Team goal · \(total.formatted()) / \(challenge.dailyGoal.formatted()) steps")
                        .font(.system(size: 11))
                        .foregroundColor(.bfTextWeak)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                BFProgressBar(progress: progress)
            }

            // ── Invite code row (always visible so existing members can reshare)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("INVITE CODE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.bfTextMuted)
                        .tracking(1)
                    Text(inviteCode)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.bfPrimary)
                        .tracking(3)
                }
                Spacer()
                Button(action: { showShareSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Invite")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.bfPrimary)
                    .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(Color.bfPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bfPrimary.opacity(0.2), lineWidth: 0.5))
        }
        .bfCard()
        .task { await manager.loadTeam(for: challenge.id) }
        .sheet(isPresented: $showShareSheet) {
            ShareInviteSheet(teamName: teamName, inviteCode: inviteCode, inviteURL: inviteURL, challenge: challenge)
        }
    }
}

// ============================================================
// MARK: - Share Invite Sheet
// ============================================================

struct ShareInviteSheet: View {
    let teamName: String
    let inviteCode: String
    let inviteURL: String
    let challenge: BFChallenge
    @State private var showActivityVC = false
    @Environment(\.dismiss) private var dismiss

    var shareMessage: String {
        "Join my team \"\(teamName)\" on Betfit for the \(challenge.name) challenge! Use code \(inviteCode) or tap the link: \(inviteURL)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bfBg.ignoresSafeArea()

                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 6) {
                        Text("👥").font(.system(size: 44))
                        Text("Invite to \(teamName)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("Share the code or link — your teammate joins instantly and is added to your team in \(challenge.name).")
                            .font(.system(size: 13))
                            .foregroundColor(.bfTextWeak)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 16)

                    // Invite code
                    VStack(spacing: 6) {
                        Text("TEAM CODE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.bfTextMuted)
                            .tracking(1.5)
                        Text(inviteCode)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.bfPrimary)
                            .tracking(6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.bfPrimary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bfPrimary.opacity(0.2), lineWidth: 0.5))
                    .padding(.horizontal, 16)

                    // Share buttons
                    VStack(spacing: 10) {
                        Button(action: {
                            let av = UIActivityViewController(activityItems: [shareMessage], applicationActivities: nil)
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let vc = scene.windows.first?.rootViewController {
                                vc.present(av, animated: true)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share invite link")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.bfPrimary)
                            .clipShape(Capsule())
                        }

                        Button(action: {
                            let msg = shareMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            if let url = URL(string: "https://wa.me/?text=\(msg)") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "message.fill")
                                Text("Send via WhatsApp")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.bfBgElevated)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.bfBorder, lineWidth: 0.5))
                        }

                        Button(action: {
                            UIPasteboard.general.string = inviteURL
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy link")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.bfTextWeak)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.bfPrimary)
                }
            }
            .toolbarBackground(Color.bfBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.large])
    }
}

// ============================================================
// MARK: - Enroll Sheet
// ============================================================

struct EnrollSheet: View {
    let challenge: BFChallenge
    var onConfirm: () -> Void

    @State private var teamName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bfBg.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Challenge summary
                    VStack(spacing: 6) {
                        Text(challenge.bannerEmoji ?? "🏃")
                            .font(.system(size: 40))
                        Text(challenge.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text(challenge.teamSizeLabel + " · " + challenge.type.label)
                            .font(.system(size: 13))
                            .foregroundColor(.bfTextWeak)
                    }
                    .padding(.top, 8)

                    // Team name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NAME YOUR TEAM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.bfTextMuted)
                            .tracking(1)
                        TextField("e.g. The Fast Pair", text: $teamName)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .padding(14)
                            .background(Color.bfBgRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bfBorder, lineWidth: 0.5))
                            .tint(.bfPrimary)
                    }
                    .padding(.horizontal, 16)

                    // Info rows
                    VStack(spacing: 0) {
                        BFInfoRow(icon: "person.2.fill", label: "Team size",      value: challenge.teamSizeLabel)
                        Divider().background(Color.bfBorder).padding(.horizontal, 18)
                        BFInfoRow(icon: "calendar",      label: "Ends",           value: challenge.endDate)
                        Divider().background(Color.bfBorder).padding(.horizontal, 18)
                        BFInfoRow(icon: "figure.walk",   label: "Daily goal",     value: "\(challenge.dailyGoal.formatted()) steps")
                    }
                    .padding(.vertical, 4)
                    .bfCard(padding: 0)
                    .padding(.horizontal, 16)

                    Text("You can invite team members after joining.")
                        .font(.system(size: 12))
                        .foregroundColor(.bfTextMuted)
                        .multilineTextAlignment(.center)

                    Spacer()

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.bfDestructive)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    BFButton(
                        label: isLoading ? "Joining…" : "Join & Create Team",
                        variant: .primary,
                        fullWidth: true,
                        action: {
                            guard !teamName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            isLoading = true
                            errorMessage = nil
                            Task {
                                do {
                                    try await ChallengeManager.shared.enroll(
                                        challengeId: challenge.id,
                                        teamName: teamName.trimmingCharacters(in: .whitespaces)
                                    )
                                    isLoading = false
                                    onConfirm()
                                } catch {
                                    isLoading = false
                                    errorMessage = "Couldn't join — \(error.localizedDescription)"
                                }
                            }
                        }
                    )
                    .disabled(teamName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.bfTextWeak)
                }
                ToolbarItem(placement: .principal) {
                    Text("Join Challenge")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(Color.bfBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.large])
    }
}

#Preview { ChallengesView() }
