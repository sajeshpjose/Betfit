// ============================================================
// Molecules.swift — Atomic Design: Level 2
// BetFit
// ============================================================

import SwiftUI

// ════════════════════════════════════════════════
// MARK: BFLeaderboardRow
// ════════════════════════════════════════════════
// Unified row for LeaderboardView (full) and DashboardView (compact)

struct BFLeaderboardRow: View {
    let rank: Int
    let teamName: String
    let member1: String
    let member2: String
    let steps: Int
    let distanceKm: Double
    var isYou: Bool = false
    var compact: Bool = false

    private var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "#B8860B")
        case 2: return Color(hex: "#888888")
        case 3: return Color(hex: "#8B5C2A")
        default: return .white
        }
    }

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            Text("\(rank)")
                .font(.system(size: compact ? 12 : 14, weight: .bold))
                .foregroundColor(rankColor)
                .frame(width: 20, alignment: .center)

            if !compact {
                HStack(spacing: -7) {
                    BFAvatar(
                        initials: String(teamName.prefix(2)).uppercased(),
                        size: .sm,
                        color: isYou ? .bfPrimary : Color(hex: "#2A2A2A"),
                        textColor: isYou ? .bfTextOnPrimary : Color(hex: "#AAAAAA")
                    )
                    Circle()
                        .fill(Color(hex: "#1E1E1E"))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle().stroke(
                                isYou ? Color.bfPrimary.opacity(0.3) : Color.bfBgRaised,
                                lineWidth: 1.5
                            )
                        )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(teamName)
                        .font(.system(size: compact ? 11 : 12, weight: isYou ? .semibold : .medium))
                        .foregroundColor(isYou ? .bfPrimary : .white)
                    if isYou {
                        Text("· You").font(.system(size: 10)).foregroundColor(.bfTextWeak)
                    }
                }
                if !compact {
                    Text("\(member1) · \(member2)")
                        .font(.system(size: 10))
                        .foregroundColor(.bfTextMuted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(steps.formatted())
                    .font(.system(size: compact ? 12 : 13, weight: .bold))
                    .foregroundColor(.white)
                if !compact {
                    Text(String(format: "%.1f km", distanceKm))
                        .font(.system(size: 10))
                        .foregroundColor(.bfTextMuted)
                }
            }
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 8 : 10)
        .background(isYou ? Color.bfPrimary.opacity(0.08) : Color.bfBgRaised)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 14))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 10 : 14)
                .stroke(isYou ? Color.bfPrimary.opacity(0.3) : Color.bfBorder, lineWidth: 0.5)
        )
    }
}

// ════════════════════════════════════════════════
// MARK: BFFilterTabBar
// ════════════════════════════════════════════════

struct BFFilterTabBar<T: RawRepresentable & Hashable & CaseIterable>: View
    where T.RawValue == String, T.AllCases: RandomAccessCollection {
    @Binding var selected: T

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(T.allCases, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.spring(response: 0.25)) { selected = filter }
                    }) {
                        Text(filter.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(selected == filter ? .black : Color(hex: "#666666"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selected == filter ? Color.bfPrimary : Color(hex: "#1E1E1E"))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.bfBorder, lineWidth: 0.5))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

// ════════════════════════════════════════════════
// MARK: BFSettingRow
// ════════════════════════════════════════════════

struct BFSettingRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = Color(hex: "#555555")
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.bfPrimary.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(.bfPrimary)
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                if !value.isEmpty {
                    Text(value).font(.system(size: 12)).foregroundColor(valueColor)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.bfTextMuted)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
        }
    }
}

// ════════════════════════════════════════════════
// MARK: BFInfoRow
// ════════════════════════════════════════════════
// SF Symbol icon + label + trailing value — used in TeamView

struct BFInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.bfPrimary.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.bfPrimary)
            }
            Text(label).font(.system(size: 12)).foregroundColor(.bfTextWeak)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
        }
    }
}

// ════════════════════════════════════════════════
// MARK: BFMemberRow
// ════════════════════════════════════════════════
// Avatar + name + handle + step count — used in TeamView

struct BFMemberRow: View {
    let member: TeamMember
    let handle: String
    var isYou: Bool = false
    var showDivider: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                BFAvatar(
                    initials: member.initials,
                    size: .md,
                    color: member.avatarColor,
                    textColor: member.textColor
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text(isYou ? "\(handle) · You" : handle)
                        .font(.system(size: 11))
                        .foregroundColor(.bfTextMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(member.steps.formatted())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("steps").font(.system(size: 10)).foregroundColor(.bfTextMuted)
                    BFBadge(label: "↑ Active", variant: .brand)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            if showDivider {
                Divider().background(Color.bfBorder).padding(.horizontal, 18)
            }
        }
    }
}
