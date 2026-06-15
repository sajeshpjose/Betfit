// ============================================================
// Atoms.swift — Atomic Design: Level 1
// BetFit
// ============================================================

import SwiftUI
import PhotosUI

// ════════════════════════════════════════════════
// MARK: BFCard — view modifier
// ════════════════════════════════════════════════

extension View {
    func bfCard(padding: CGFloat = 16, radius: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .background(Color.bfBgRaised)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.bfBorder, lineWidth: 0.5))
    }

    func bfElevatedCard(padding: CGFloat = 12, radius: CGFloat = 12) -> some View {
        self
            .padding(padding)
            .background(Color.bfBgElevated)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.bfBorder, lineWidth: 0.5))
    }
}

// ════════════════════════════════════════════════
// MARK: BFSectionLabel
// ════════════════════════════════════════════════

struct BFSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.bfTextMuted)
            .textCase(.uppercase)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}

// ════════════════════════════════════════════════
// MARK: BFAvatar
// ════════════════════════════════════════════════

enum BFAvatarSize {
    case xs, sm, md, lg, xl
    var diameter: CGFloat {
        switch self { case .xs: 24; case .sm: 32; case .md: 48; case .lg: 64; case .xl: 80 }
    }
    var fontSize: CGFloat {
        switch self { case .xs: 9; case .sm: 12; case .md: 16; case .lg: 22; case .xl: 26 }
    }
}

struct BFAvatar: View {
    let initials: String
    var size: BFAvatarSize = .md
    var color: Color = .bfPrimary
    var textColor: Color = .bfTextOnPrimary
    var image: Image? = nil

    var body: some View {
        Group {
            if let img = image {
                img.resizable().scaledToFill()
            } else {
                color.overlay(
                    Text(initials)
                        .font(.system(size: size.fontSize, weight: .bold))
                        .foregroundColor(textColor)
                )
            }
        }
        .frame(width: size.diameter, height: size.diameter)
        .clipShape(Circle())
    }
}

// ════════════════════════════════════════════════
// MARK: BFBadge
// ════════════════════════════════════════════════

enum BFBadgeVariant {
    case brand, success, warning, destructive, neutral, gold

    var background: Color {
        switch self {
        case .brand:       return .bfPrimary.opacity(0.15)
        case .success:     return Color(hex: "#4CAF50").opacity(0.15)
        case .warning:     return Color(hex: "#FF9500").opacity(0.15)
        case .destructive: return .bfDestructive.opacity(0.15)
        case .neutral:     return Color.white.opacity(0.06)
        case .gold:        return Color(hex: "#B8860B").opacity(0.15)
        }
    }
    var foreground: Color {
        switch self {
        case .brand:       return .bfTextOnPrimary
        case .success:     return Color(hex: "#4CAF50")
        case .warning:     return Color(hex: "#FF9500")
        case .destructive: return .bfDestructive
        case .neutral:     return .bfTextWeak
        case .gold:        return Color(hex: "#B8860B")
        }
    }
    var border: Color {
        switch self {
        case .brand:       return .bfPrimary.opacity(0.4)
        case .success:     return Color(hex: "#4CAF50").opacity(0.4)
        case .warning:     return Color(hex: "#FF9500").opacity(0.4)
        case .destructive: return .bfDestructive.opacity(0.4)
        case .neutral:     return Color.white.opacity(0.1)
        case .gold:        return Color(hex: "#B8860B").opacity(0.4)
        }
    }
}

struct BFBadge: View {
    let label: String
    var variant: BFBadgeVariant = .brand

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(variant.foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(variant.background)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(variant.border, lineWidth: 0.5))
    }
}

// ════════════════════════════════════════════════
// MARK: BFButton
// ════════════════════════════════════════════════

enum BFButtonVariant { case primary, secondary, destructive, ghost }

struct BFButton: View {
    let label: String
    var variant: BFButtonVariant = .primary
    var fullWidth: Bool = false
    var height: CGFloat = 48
    let action: () -> Void

    private var background: Color {
        switch variant {
        case .primary:     return .bfPrimary
        case .secondary:   return .bfBgElevated
        case .destructive: return .bfDestructive.opacity(0.15)
        case .ghost:       return .clear
        }
    }
    private var foreground: Color {
        switch variant {
        case .primary:     return .bfTextOnPrimary  // black text on yellow background
        case .secondary:   return .white
        case .destructive: return .bfDestructive
        case .ghost:       return .bfTextWeak
        }
    }
    private var border: Color {
        switch variant {
        case .primary:     return .clear
        case .secondary:   return .bfBorder
        case .destructive: return .bfDestructive.opacity(0.4)
        case .ghost:       return .clear
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(foreground)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(height: height)
                .padding(.horizontal, fullWidth ? 0 : 24)
                .background(background)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(border, lineWidth: 0.5))
        }
    }
}

// ════════════════════════════════════════════════
// MARK: BFStatBox
// ════════════════════════════════════════════════
// Value + label tile — used in TeamView and ProfileView

struct BFStatBox: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 10)).foregroundColor(.bfTextWeak)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bfElevatedCard()
    }
}

// ════════════════════════════════════════════════
// MARK: BFProgressBar
// ════════════════════════════════════════════════

struct BFProgressBar: View {
    let progress: Double  // 0–1
    var height: CGFloat = 7
    var color: Color = .bfPrimary

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.15)).frame(height: height)
                Capsule().fill(color)
                    .frame(width: geo.size.width * progress, height: height)
                    .animation(.easeOut(duration: 0.8), value: progress)
            }
        }
        .frame(height: height)
    }
}

// ════════════════════════════════════════════════
// MARK: BFToast
// ════════════════════════════════════════════════

struct BFToast: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.bfPrimary)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

// ════════════════════════════════════════════════
// MARK: BFNavBarTitle
// ════════════════════════════════════════════════

struct BFNavBarTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.bfTextWeak)
            }
        }
    }
}
