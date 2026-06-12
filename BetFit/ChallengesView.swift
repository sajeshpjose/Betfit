// ============================================================
// ChallengesView.swift
// BetFit
// ============================================================

import SwiftUI

struct ChallengesView: View {

    @StateObject private var manager  = ChallengeManager.shared
    @EnvironmentObject private var deepLink: DeepLinkManager
    @State private var deepLinkChallenge: BFChallenge? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bfBg.ignoresSafeArea()

                if manager.isLoading && manager.publicChallenges.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView().tint(.bfPrimary)
                        Text("Loading challenges…")
                            .font(.system(size: 13))
                            .foregroundColor(.bfTextWeak)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {

                            // ── Page title
                            Text("Challenges")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 4)

                            VStack(spacing: 20) {

                                // ── Active (enrolled)
                                if !manager.enrolledChallenges.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        BFSectionLabel("Active")
                                            .padding(.horizontal, 2)
                                        ForEach(manager.enrolledChallenges) { challenge in
                                            NavigationLink(destination: ChallengeDetailView(
                                                challenge: challenge,
                                                isEnrolled: true,
                                                onEnroll: {}
                                            )) {
                                                ChallengeCard(challenge: challenge, enrolled: true)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                // ── Discover (not enrolled)
                                let discover = manager.publicChallenges.filter { c in
                                    !manager.enrolledChallenges.contains { $0.id == c.id }
                                }
                                if !discover.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        BFSectionLabel("Discover")
                                            .padding(.horizontal, 2)
                                        ForEach(discover) { challenge in
                                            NavigationLink(destination: ChallengeDetailView(
                                                challenge: challenge,
                                                isEnrolled: false,
                                                onEnroll: { Task { await manager.loadChallenges() } }
                                            )) {
                                                ChallengeCard(challenge: challenge, enrolled: false)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                // ── Empty state
                                if manager.publicChallenges.isEmpty && !manager.isLoading {
                                    VStack(spacing: 8) {
                                        Text("🏁").font(.system(size: 40))
                                        Text("No challenges yet")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("Check back soon — your admin will add challenges here.")
                                            .font(.system(size: 13))
                                            .foregroundColor(.bfTextWeak)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding(.top, 60)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 100)
                        }
                    }
                    .refreshable { await manager.loadChallenges() }
                }

                if let error = manager.errorMessage {
                    VStack {
                        Spacer()
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.bfDestructive.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bfBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task { await manager.loadChallenges() }
            // ── Deep link: navigate straight to the challenge from an invite link
            .navigationDestination(item: $deepLinkChallenge) { challenge in
                ChallengeDetailView(
                    challenge: challenge,
                    isEnrolled: manager.isEnrolled(in: challenge.id),
                    onEnroll: { Task { await manager.loadChallenges() } }
                )
            }
            .onChange(of: deepLink.pendingChallenge) { _, challenge in
                guard let challenge else { return }
                deepLinkChallenge = challenge
                deepLink.clearPending()
            }
        }
    }
}

// ============================================================
// MARK: - Challenge Card
// ============================================================

struct ChallengeCard: View {
    let challenge: BFChallenge
    let enrolled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Banner strip
            ZStack {
                Color.bfPrimary.opacity(0.1)
                HStack {
                    Text(challenge.bannerEmoji ?? "🏃")
                        .font(.system(size: 32))
                    Spacer()
                    HStack(spacing: 6) {
                        if enrolled {
                            BFBadge(label: "Active", variant: .brand)
                        }
                        if challenge.daysLeft > 0 {
                            BFBadge(label: "\(challenge.daysLeft)d left", variant: .neutral)
                        } else {
                            BFBadge(label: "Ended", variant: .destructive)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 60)

            // Body
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(challenge.type.icon)
                            .font(.system(size: 12))
                        Text(challenge.type.label.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.bfPrimary)
                            .tracking(0.8)
                    }
                    Text(challenge.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    if let company = challenge.company {
                        Text(company)
                            .font(.system(size: 12))
                            .foregroundColor(.bfTextWeak)
                    }
                }

                Divider().background(Color.bfBorder)

                HStack(spacing: 0) {
                    ChallengeStatPill(icon: "person.2.fill",
                                      label: challenge.teamSizeLabel)
                    Divider().frame(height: 24).background(Color.bfBorder)
                    ChallengeStatPill(icon: "flag.fill",
                                      label: "\(challenge.totalTeams ?? 0) teams")
                    Divider().frame(height: 24).background(Color.bfBorder)
                    ChallengeStatPill(icon: "figure.walk",
                                      label: "\(challenge.dailyGoal.formatted()) / day")
                }
            }
            .padding(16)
            .background(Color.bfBgRaised)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(enrolled ? Color.bfPrimary.opacity(0.3) : Color.bfBorder, lineWidth: 0.5)
        )
    }
}

private struct ChallengeStatPill: View {
    let icon: String
    let label: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.bfPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.bfTextWeak)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview { ChallengesView().environmentObject(DeepLinkManager.shared) }
