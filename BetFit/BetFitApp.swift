// ============================================================
// BetFitApp.swift
// BetFit
// ============================================================

import SwiftUI

@main
struct BetFitApp: App {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var auth = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isLoading {
                    SplashView()

                } else if !auth.isSignedIn {
                    AuthView()
                        .environmentObject(auth)

                } else if !hasCompletedOnboarding {
                    OnboardingView()
                        .environmentObject(auth)

                } else {
                    MainTabView()
                        .environmentObject(auth)
                }
            }
            // Force always dark regardless of system setting
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                Task {
                    await AuthManager.shared.handleCallback(url: url)
                }
            }
        }
    }
}

// ============================================================
// MARK: - Splash View
// ============================================================

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.bfBg.ignoresSafeArea()
            VStack(spacing: 8) {
                Text("betfit.")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.bfPrimary)
                    .tracking(-1)
                ProgressView()
                    .tint(.bfPrimary)
                    .padding(.top, 8)
            }
        }
    }
}

// ============================================================
// MARK: - Main Tab View
// ============================================================

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home",        systemImage: "house.fill") }

            LeaderboardView()
                .tabItem { Label("Leaderboard", systemImage: "trophy.fill") }

            C25KView()
                .tabItem { Label("5K Plan",     systemImage: "figure.run") }

            TeamView()
                .tabItem { Label("Team",        systemImage: "person.2.fill") }

            ProfileView()
                .tabItem { Label("Profile",     systemImage: "person.fill") }
        }
        .tint(Color.bfPrimary)
    }
}
