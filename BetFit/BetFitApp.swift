// ============================================================
// BetFitApp.swift
// BetFit
// ============================================================

import SwiftUI

@main
struct BetFitApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var auth     = AuthManager.shared
    @StateObject private var deepLink = DeepLinkManager.shared

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
                        .environmentObject(deepLink)
                        .task {
                            // Request notification permission once signed in
                            await NotificationManager.shared.checkAuthorizationStatus()
                            if !NotificationManager.shared.isAuthorized {
                                await NotificationManager.shared.requestPermission()
                            }
                            if NotificationManager.shared.isAuthorized {
                                NotificationManager.shared.scheduleDailyStepReminder()
                            }
                        }
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                Task { await DeepLinkManager.shared.handle(url: url) }
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
                .tabItem { Label("Home",       systemImage: "house.fill") }

            ChallengesView()
                .tabItem { Label("Challenges", systemImage: "trophy.fill") }

            ProfileView()
                .tabItem { Label("Profile",    systemImage: "person.fill") }
        }
        .tint(Color.bfPrimary)
    }
}
