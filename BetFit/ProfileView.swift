// ============================================================
// ProfileView.swift — Dark Mode Fixed
// BetFit
// ============================================================

import SwiftUI
import PhotosUI

struct Badge: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    let earned: Bool
}

struct ProfileView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @StateObject private var profile = ProfileManager.shared
    @StateObject private var sync    = StepSyncManager.shared
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var avatarImage: Image? = nil
    @State private var showSignOutAlert = false
    @State private var showEditProfile = false

    private var name:    String { profile.fullName.isEmpty ? "Your Name" : profile.fullName }
    private var handle:  String { profile.handle.isEmpty   ? "@handle"   : profile.handle }
    private var company: String { profile.company.isEmpty  ? "Your Company" : profile.company }
    let challenges = 3
    let streakDays = 6
    let bestFinish = "2× 🥈"

    let badges: [Badge] = [
        Badge(emoji: "🔥", label: "7 day streak",  earned: true),
        Badge(emoji: "👟", label: "First 10k day", earned: true),
        Badge(emoji: "🤝", label: "Team player",   earned: true),
        Badge(emoji: "🏅", label: "Top 3 finish",  earned: false),
        Badge(emoji: "🏃", label: "5K complete",   earned: false),
        Badge(emoji: "⚡", label: "30 day streak", earned: false),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bfBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        Text("Profile")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        DarkProfileHero(name: name, handle: handle, company: company, totalSteps: sync.weeklySteps.map(\.steps).reduce(0,+), challenges: challenges, streakDays: streakDays, selectedPhoto: $selectedPhoto, avatarImage: $avatarImage, onEditProfile: { showEditProfile = true })
                        DarkWeeklyChart(weeklySteps: sync.weeklySteps, dailyGoal: 10000)
                        DarkBadgesCard(badges: badges)
                        DarkAllTimeStats(totalSteps: sync.weeklySteps.map(\.steps).reduce(0,+), challenges: challenges, bestFinish: bestFinish)
                        DarkSettingsCard(onSignOut: { showSignOutAlert = true })
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "gearshape").font(.system(size: 16)).foregroundColor(.white)
                            .frame(width: 34, height: 34).background(Color.bfBgRaised).clipShape(Circle())
                            .overlay(Circle().stroke(Color.bfBorder, lineWidth: 0.5))
                    }
                }
            }
            .toolbarBackground(Color.bfBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                await sync.fetchWeeklySteps()
                // Load saved avatar from Supabase Storage URL if not already shown
                if avatarImage == nil, let urlString = profile.avatarURL,
                   let url = URL(string: urlString),
                   let (data, _) = try? await URLSession.shared.data(from: url),
                   let uiImg = UIImage(data: data) {
                    avatarImage = Image(uiImage: uiImg)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet(name: Binding(get: { name }, set: { _ in }),
                                 handle: Binding(get: { handle }, set: { _ in }),
                                 company: Binding(get: { company }, set: { _ in }))
            }
            .alert("Sign out?", isPresented: $showSignOutAlert) {
                Button("Sign out", role: .destructive) { hasCompletedOnboarding = false }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign back in to access your team and challenges.")
            }
        }
    }
}

struct DarkProfileHero: View {
    let name: String
    let handle: String
    let company: String
    let totalSteps: Int
    let challenges: Int
    let streakDays: Int
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var avatarImage: Image?
    var onEditProfile: () -> Void = {}

    func formatLarge(_ n: Int) -> String { n >= 1000 ? String(format: "%.0fk", Double(n)/1000) : "\(n)" }

    var body: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let img = avatarImage {
                            img.resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle())
                        } else {
                            Circle().fill(Color.bfPrimary).frame(width: 80, height: 80)
                                .overlay(Text("SK").font(.system(size: 26, weight: .bold)).foregroundColor(.black))
                        }
                    }
                    Circle().fill(Color.bfPrimary).frame(width: 24, height: 24)
                        .overlay(Image(systemName: "camera.fill").font(.system(size: 10)).foregroundColor(.black))
                        .overlay(Circle().stroke(Color.bfBgRaised, lineWidth: 2))
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self),
                          let uiImg = UIImage(data: data) else { return }

                    // Show immediately in the UI
                    avatarImage = Image(uiImage: uiImg)

                    // Compress and upload to Supabase Storage
                    let compressed = uiImg.jpegData(compressionQuality: 0.8) ?? data
                    do {
                        _ = try await ProfileManager.shared.uploadAvatar(imageData: compressed)
                    } catch {
                        // Non-fatal — image still shows locally
                        print("Avatar upload failed: \(error)")
                    }
                }
            }

            VStack(spacing: 3) {
                Text(name).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                Text(handle).font(.system(size: 12)).foregroundColor(.bfTextWeak)
                HStack(spacing: 4) {
                    Image(systemName: "building.2").font(.system(size: 11)).foregroundColor(.bfTextMuted)
                    Text(company).font(.system(size: 11)).foregroundColor(.bfTextMuted)
                }
                .padding(.top, 2)
            }

            Divider().background(Color.bfBorder)

            HStack {
                ProfileStatItem(value: formatLarge(totalSteps), label: "Total steps")
                Divider().frame(height: 32).background(Color.bfBorder)
                ProfileStatItem(value: "\(challenges)", label: "Challenges")
                Divider().frame(height: 32).background(Color.bfBorder)
                ProfileStatItem(value: "\(streakDays)", label: "Day streak")
            }

            BFButton(label: "Edit profile", variant: .secondary, fullWidth: true, height: 38, action: onEditProfile)
        }
        .padding(18)
        .background(Color.bfBgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.bfBorder, lineWidth: 0.5))
    }
}

private struct ProfileStatItem: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 9)).foregroundColor(.bfTextMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DarkWeeklyChart: View {
    let weeklySteps: [(day: String, steps: Int)]
    let dailyGoal: Int
    var maxSteps: Int { max(weeklySteps.map { $0.steps }.max() ?? 0, dailyGoal) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This week").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text("Goal \(dailyGoal.formatted())").font(.system(size: 9)).foregroundColor(.bfTextMuted)
            }
            GeometryReader { geo in
                let barW = (geo.size.width - CGFloat(weeklySteps.count - 1) * 6) / CGFloat(weeklySteps.count)
                let chartH: CGFloat = 80
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(weeklySteps.indices, id: \.self) { i in
                        let entry = weeklySteps[i]
                        let isToday = i == 3
                        let barH = entry.steps > 0 ? max(chartH * CGFloat(entry.steps) / CGFloat(maxSteps), 4) : 4
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isToday ? Color.bfPrimary : Color.bfPrimary.opacity(0.25))
                                .frame(width: barW, height: barH)
                                .opacity(entry.steps == 0 ? 0.2 : 1)
                            Text(entry.day).font(.system(size: 9)).foregroundColor(.bfTextMuted)
                        }
                    }
                }
                .frame(height: chartH, alignment: .bottom)
            }
            .frame(height: 100)
        }
        .padding(16)
        .background(Color.bfBgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.bfBorder, lineWidth: 0.5))
    }
}

struct DarkBadgesCard: View {
    let badges: [Badge]
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(badges) { badge in
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(badge.earned ? Color.bfPrimary : Color(hex: "#1A1A1A"))
                                .frame(height: 52)
                            Text(badge.emoji).font(.system(size: 24))
                                .grayscale(badge.earned ? 0 : 1).opacity(badge.earned ? 1 : 0.3)
                        }
                        Text(badge.label).font(.system(size: 10, weight: badge.earned ? .semibold : .regular))
                            .foregroundColor(badge.earned ? .white : .bfTextMuted)
                            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.bfBgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.bfBorder, lineWidth: 0.5))
    }
}

struct DarkAllTimeStats: View {
    let totalSteps: Int
    let challenges: Int
    let bestFinish: String
    var totalDistanceKm: Double { Double(totalSteps) * 0.000762 }
    func formatLarge(_ n: Int) -> String { n >= 1000 ? String(format: "%.0fk", Double(n)/1000) : "\(n)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All-time stats").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                DarkAllTimeStat(value: formatLarge(totalSteps) + " steps", label: "Total steps")
                DarkAllTimeStat(value: String(format: "%.0f km", totalDistanceKm), label: "Distance walked")
                DarkAllTimeStat(value: "\(challenges)", label: "Challenges joined")
                DarkAllTimeStat(value: bestFinish, label: "Best finish")
            }
        }
        .padding(16)
        .background(Color.bfBgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.bfBorder, lineWidth: 0.5))
    }
}

// DarkAllTimeStat → use BFStatBox from Atoms.swift
private typealias DarkAllTimeStat = BFStatBox

struct DarkSettingsCard: View {
    let onSignOut: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            DarkSettingRow(icon: "heart.text.square.fill", label: "Apple Health", value: "Connected", valueColor: Color.bfPrimary)
            Divider().background(Color.bfBorder).padding(.horizontal, 18)
            DarkSettingRow(icon: "bell.fill", label: "Notifications", value: "Daily reminders")
            Divider().background(Color.bfBorder).padding(.horizontal, 18)
            DarkSettingRow(icon: "building.2.fill", label: "Company", value: "Acme Corp")
            Divider().background(Color.bfBorder).padding(.horizontal, 18)
            DarkSettingRow(icon: "lock.fill", label: "Privacy", value: "Profile visible")
            Divider().background(Color.bfBorder).padding(.horizontal, 18)
            DarkSettingRow(icon: "questionmark.circle.fill", label: "Help & support", value: "")
            Divider().background(Color.bfBorder).padding(.horizontal, 18)
            Button(action: onSignOut) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9).fill(Color.red.opacity(0.15)).frame(width: 32, height: 32)
                        Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 15)).foregroundColor(.red)
                    }
                    Text("Sign out").font(.system(size: 13, weight: .medium)).foregroundColor(.red)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.bfTextMuted)
                }
                .padding(.horizontal, 18).padding(.vertical, 13)
            }
        }
        .background(Color.bfBgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.bfBorder, lineWidth: 0.5))
    }
}

// DarkSettingRow → use BFSettingRow from Molecules.swift
private typealias DarkSettingRow = BFSettingRow

struct EditProfileSheet: View {
    @Binding var name: String
    @Binding var handle: String
    @Binding var company: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profile = ProfileManager.shared

    @State private var draftName: String    = ""
    @State private var draftHandle: String  = ""
    @State private var draftCompany: String = ""
    @State private var isSaving = false
    @State private var saveError: String?   = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bfBg.ignoresSafeArea()
                VStack(spacing: 16) {
                    EditProfileField(label: "Name",    text: $draftName,    placeholder: "Your full name")
                    EditProfileField(label: "Handle",  text: $draftHandle,  placeholder: "@username")
                    EditProfileField(label: "Company", text: $draftCompany, placeholder: "Your company")

                    if let err = saveError {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(.bfDestructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.bfTextWeak)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .principal) {
                    Text("Edit Profile")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView().tint(.bfPrimary)
                    } else {
                        Button("Save") {
                            Task {
                                isSaving = true
                                saveError = nil
                                do {
                                    try await ProfileManager.shared.save(
                                        fullName: draftName,
                                        handle:   draftHandle,
                                        company:  draftCompany
                                    )
                                    dismiss()
                                } catch {
                                    saveError = "Failed to save. Please try again."
                                }
                                isSaving = false
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.bfPrimary)
                    }
                }
            }
            .toolbarBackground(Color.bfBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            draftName    = profile.fullName
            draftHandle  = profile.handle
            draftCompany = profile.company
        }
    }
}

private struct EditProfileField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.bfTextMuted)
                .textCase(.uppercase)
                .tracking(0.5)
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.bfBgRaised)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bfBorder, lineWidth: 0.5))
                .tint(.bfPrimary)
        }
    }
}

#Preview { ProfileView() }
