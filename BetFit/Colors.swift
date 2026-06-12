// ============================================================
// Colors.swift
// BetFit
// ============================================================
// Dark mode color system — always dark regardless of system setting.
// Replace the Color extensions in Onboarding.swift with this file.
// Delete the Color extension block from Onboarding.swift after adding this.
// ============================================================

import SwiftUI

extension Color {

    // ── Brand
    static let bfPrimary         = Color(hex: "#D5FF45")  // acid yellow-green
    static let bfPrimary20       = Color(hex: "#D5FF45").opacity(0.15) // subtle tint on dark
    static let bfPrimaryDisabled = Color(hex: "#D5FF45").opacity(0.3)

    // ── Backgrounds
    static let bfBg              = Color(hex: "#0A0A0A")  // deepest black
    static let bfBgRaised        = Color(hex: "#141414")  // card background
    static let bfBgElevated      = Color(hex: "#1C1C1C")  // elevated surface

    // ── Text
    static let bfBlack           = Color(hex: "#FFFFFF")  // inverted — white on dark
    static let bfTextWeak        = Color(hex: "#888888")  // secondary text
    static let bfTextMuted       = Color(hex: "#444444")  // placeholder / disabled
    static let bfTextOnPrimary   = Color(hex: "#000000")  // text on yellow-green

    // ── Borders
    static let bfBorder          = Color.white.opacity(0.12)
    static let bfBorderLight     = Color.white.opacity(0.06)

    // ── Semantic
    static let bfSuccess         = Color(hex: "#4CAF50")
    static let bfWarning         = Color(hex: "#FF9500")
    static let bfDestructive     = Color(hex: "#FF453A")

    // ── Hex initialiser
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
