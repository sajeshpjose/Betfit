// ============================================================
// AuthView.swift
// BetFit
// ============================================================

import SwiftUI

struct AuthView: View {

    @StateObject private var auth = AuthManager.shared
    @State private var isLoadingApple  = false
    @State private var isLoadingGoogle = false

    var body: some View {
        ZStack {
            Color.bfPrimary.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Yellow hero
                VStack(spacing: 12) {
                    Spacer()

                    Text("betfit.")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.bfBlack)
                        .tracking(-1)

                    Text("Walk more. Win together.")
                        .font(.system(size: 15))
                        .foregroundColor(.bfTextWeak)

                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.black.opacity(0.06))
                            .frame(width: 220, height: 160)

                        VStack(spacing: 12) {
                            HStack(spacing: 16) {
                                SignInChip(emoji: "👟", value: "8.4k", label: "steps")
                                SignInChip(emoji: "🏅", value: "#2",   label: "rank")
                            }
                            Image(systemName: "figure.walk")
                                .font(.system(size: 44))
                                .foregroundColor(.bfBlack.opacity(0.5))
                        }
                    }
                    .padding(.top, 12)

                    Spacer()
                }
                .frame(maxHeight: .infinity)

                // ── White bottom sheet
                VStack(alignment: .leading, spacing: 20) {

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sign in to Betfit")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.bfBlack)
                        Text("Join team challenges, track your steps, and compete with your colleagues.")
                            .font(.system(size: 14))
                            .foregroundColor(.bfTextWeak)
                            .lineSpacing(3)
                    }

                    // Error
                    if let error = auth.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.bfTextWeak)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    VStack(spacing: 12) {

                        // Apple
                        Button(action: {
                            Task {
                                isLoadingApple = true
                                await auth.signInWithApple()
                                isLoadingApple = false
                            }
                        }) {
                            HStack(spacing: 10) {
                                if isLoadingApple {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 18, weight: .medium))
                                    Text("Continue with Apple")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.black)
                            .clipShape(Capsule())
                        }
                        .disabled(isLoadingApple || isLoadingGoogle)

                        // Google
                        Button(action: {
                            Task {
                                isLoadingGoogle = true
                                await auth.signInWithGoogle()
                                isLoadingGoogle = false
                            }
                        }) {
                            HStack(spacing: 10) {
                                if isLoadingGoogle {
                                    ProgressView().tint(.bfBlack)
                                } else {
                                    Image(systemName: "globe")
                                        .font(.system(size: 18))
                                        .foregroundColor(.blue)
                                    Text("Continue with Google")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.bfBlack)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.bfBgRaised)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.bfBorder, lineWidth: 0.5))
                        }
                        .disabled(isLoadingApple || isLoadingGoogle)
                    }

                    Text("By continuing you agree to Betfit's Terms of Service and Privacy Policy.")
                        .font(.system(size: 11))
                        .foregroundColor(.bfTextMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 48)
                .background(Color.bfBgRaised)
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

private struct SignInChip: View {
    let emoji: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(emoji).font(.system(size: 20))
            Text(value).font(.system(size: 14, weight: .bold)).foregroundColor(.bfBlack)
            Text(label).font(.system(size: 9)).foregroundColor(.bfTextWeak)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.bfBgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    AuthView()
}
