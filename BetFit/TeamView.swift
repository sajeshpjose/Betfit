// ============================================================
// TeamView.swift — Dark Mode Fixed
// BetFit
// ============================================================

import SwiftUI

struct TeamView: View {
    @State private var showCopiedToast = false
    @State private var toastMessage = ""

    let teamName       = "The Fast Pair"
    let rank           = 2
    let challengeName  = "June Wellness Sprint"
    let company        = "Acme Corp"
    let daysLeft       = 6
    let inviteCode     = "FP·8821"
    let behindBy       = 980
    let totalTeams     = 50
    let dailyGoalSteps = 23000
    let endDate        = "June 17, 2026"
    let streakDays     = 6

    let members: [TeamMember] = [
        TeamMember(initials: "SK", name: "Sajesh Kumar", steps: 6241, avatarColor: .bfPrimary,            textColor: Color(hex: "#000000")),
        TeamMember(initials: "JT", name: "John Tobin",  steps: 8102, avatarColor: Color(hex: "#2A2A2A"), textColor: Color(hex: "#AAAAAA")),
    ]

    var totalSteps: Int    { members.reduce(0) { $0 + $1.steps } }
    var totalDistanceKm: Double { Double(totalSteps) * 0.000762 }
    var totalCalories: Int { Int(Double(totalSteps) * 0.04) }
    var goalProgress: Double { min(Double(totalSteps) / Double(dailyGoalSteps), 1.0) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.bfBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Rank banner
                        HStack(spacing: 12) {
                            Text("#\(rank)").font(.system(size: 32, weight: .bold)).foregroundColor(.black)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Current rank · \(challengeName)").font(.system(size: 11, weight: .semibold)).foregroundColor(.black.opacity(0.6))
                                Text("\(behindBy.formatted()) steps behind #1 · ↑ moved up 1 today").font(.system(size: 11)).foregroundColor(.black.opacity(0.5))
                            }
                            Spacer()
                            Text("🏅").font(.system(size: 24))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color.bfPrimary).clipShape(RoundedRectangle(cornerRadius: 16))

                        // Members
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Members").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 12)
                            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                                VStack(spacing: 0) {
                                    HStack(spacing: 12) {
                                        Circle().fill(member.avatarColor).frame(width: 42, height: 42)
                                            .overlay(Text(member.initials).font(.system(size: 14, weight: .bold)).foregroundColor(member.textColor))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(member.name).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                            Text(index == 0 ? "@sajesh · You" : "@johntobin").font(.system(size: 11)).foregroundColor(.bfTextMuted)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(member.steps.formatted()).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                            Text("steps").font(.system(size: 10)).foregroundColor(.bfTextMuted)
                                            Text("↑ Active").font(.system(size: 9, weight: .bold)).foregroundColor(.bfPrimary)
                                                .padding(.horizontal, 7).padding(.vertical, 2)
                                                .background(Color.bfPrimary.opacity(0.12)).clipShape(Capsule())
                                        }
                                    }
                                    .padding(.horizontal, 18).padding(.vertical, 12)
                                    if index < members.count - 1 { Divider().background(Color.bfBorder).padding(.horizontal, 18) }
                                }
                            }
                            Spacer().frame(height: 16)
                        }
                        .background(Color.bfBgRaised).clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.bfBorder, lineWidth: 0.5))

                        // Team stats
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Team stats today").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                DarkTeamStatBox(value: totalSteps.formatted(),              label: "Combined steps")
                                DarkTeamStatBox(value: String(format: "%.1f km", totalDistanceKm), label: "Distance walked")
                                DarkTeamStatBox(value: "\(totalCalories) cal",             label: "Calories burned")
                                DarkTeamStatBox(value: "\(streakDays) days",               label: "Streak together")
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text("Team goal progress").font(.system(size: 11)).foregroundColor(.bfTextWeak)
                                    Spacer()
                                    Text("\(Int(goalProgress * 100))% · \(totalSteps.formatted()) / \(dailyGoalSteps.formatted())")
                                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.bfPrimary.opacity(0.15)).frame(height: 7)
                                        Capsule().fill(Color.bfPrimary).frame(width: geo.size.width * goalProgress, height: 7)
                                            .animation(.easeOut(duration: 0.8), value: goalProgress)
                                    }
                                }
                                .frame(height: 7)
                            }
                        }
                        .padding(16).background(Color.bfBgRaised).clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.bfBorder, lineWidth: 0.5))

                        // Invite card
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Invite a teammate").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                Text("Share your team code or send a link. Partner joins instantly.")
                                    .font(.system(size: 12)).foregroundColor(.bfTextMuted).lineSpacing(2)
                            }
                            HStack {
                                Text(inviteCode).font(.system(size: 26, weight: .bold)).foregroundColor(.bfPrimary).tracking(4)
                                Spacer()
                                Button(action: { copyToClipboard(inviteCode); showToast("Code copied!") }) {
                                    Text("Copy").font(.system(size: 11, weight: .bold)).foregroundColor(.black)
                                        .padding(.horizontal, 14).padding(.vertical, 7)
                                        .background(Color.bfPrimary).clipShape(Capsule())
                                }
                            }
                            .padding(14).background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bfBorder, lineWidth: 0.5))

                            HStack(spacing: 10) {
                                Rectangle().fill(Color.bfBorder).frame(height: 0.5)
                                Text("or share link").font(.system(size: 10)).foregroundColor(.bfTextMuted).fixedSize()
                                Rectangle().fill(Color.bfBorder).frame(height: 0.5)
                            }

                            VStack(spacing: 8) {
                                Button(action: shareInviteLink) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share invite link")
                                    }
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .background(Color.bfBgElevated).clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.bfBorder, lineWidth: 0.5))
                                }
                                Button(action: shareViaWhatsApp) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "message.fill")
                                        Text("Send via WhatsApp")
                                    }
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .background(Color.bfBgElevated).clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.bfBorder, lineWidth: 0.5))
                                }
                            }
                        }
                        .padding(18).background(Color.bfBgRaised).clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.bfBorder, lineWidth: 0.5))

                        // Challenge info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(challengeName) · \(company)").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            ForEach([
                                ("calendar", "Challenge ends", endDate),
                                ("person.2.fill", "Teams competing", "\(totalTeams) teams"),
                                ("target", "Daily team goal", "\(dailyGoalSteps.formatted()) steps"),
                                ("trophy.fill", "Your rank", "#\(rank) of \(totalTeams)"),
                            ], id: \.0) { item in
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8).fill(Color.bfPrimary.opacity(0.12)).frame(width: 30, height: 30)
                                        Image(systemName: item.0).font(.system(size: 14)).foregroundColor(.bfPrimary)
                                    }
                                    Text(item.1).font(.system(size: 12)).foregroundColor(.bfTextWeak)
                                    Spacer()
                                    Text(item.2).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                                }
                            }
                        }
                        .padding(16).background(Color.bfBgRaised).clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.bfBorder, lineWidth: 0.5))
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 100)
                }

                if showCopiedToast {
                    ToastView(message: toastMessage).transition(.move(edge: .bottom).combined(with: .opacity)).padding(.bottom, 20)
                }
            }
            .animation(.spring(response: 0.3), value: showCopiedToast)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Your Team").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                        HStack(spacing: 6) {
                            Text(teamName).font(.system(size: 13, weight: .medium)).foregroundColor(.bfTextWeak)
                            Text("✎ Edit").font(.system(size: 11)).foregroundColor(.bfTextMuted)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(daysLeft) days left").font(.system(size: 10, weight: .bold)).foregroundColor(.black)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.bfPrimary).clipShape(Capsule())
                }
            }
            .toolbarBackground(Color.bfBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func copyToClipboard(_ text: String) { UIPasteboard.general.string = text }
    private func shareInviteLink() {
        let url = "https://betfit.app/join/fp-8821"
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let vc = scene.windows.first?.rootViewController { vc.present(av, animated: true) }
    }
    private func shareViaWhatsApp() {
        let msg = "Join my team on Betfit! Use code \(inviteCode)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://wa.me/?text=\(msg)") { UIApplication.shared.open(url) }
    }
    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showCopiedToast = false } }
    }
}

private struct DarkTeamStatBox: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 10)).foregroundColor(.bfTextWeak)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(Color.bfBgElevated).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bfBorder, lineWidth: 0.5))
    }
}

struct ToastView: View {
    let message: String
    var body: some View {
        Text(message).font(.system(size: 13, weight: .semibold)).foregroundColor(.black)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Color.bfPrimary).clipShape(Capsule())
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

#Preview { TeamView() }
