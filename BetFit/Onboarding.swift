// ============================================================
// Onboarding.swift
// BetFit
// ============================================================
// Covers all 4 onboarding steps:
//   1. Welcome
//   2. Features (how it works)
//   3. Health permissions
//   4. Profile setup
//
// Usage: Present this as a full-screen sheet on first launch.
// Dismiss it by setting hasCompletedOnboarding = true in
// AppStorage, which hides it permanently.
// ============================================================

import SwiftUI
import PhotosUI

// ============================================================
// MARK: - Color Tokens
// ============================================================

// ============================================================
// MARK: - Root Onboarding Coordinator
// ============================================================

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentStep: Int = 0

    // Profile data collected across steps
    @State private var profileName: String = ""
    @State private var username: String = ""
    @State private var companyCode: String = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var avatarImage: Image? = nil

    var body: some View {
        ZStack {
            Color.bfBg.ignoresSafeArea()

            TabView(selection: $currentStep) {
                WelcomeStep(onNext: { advance() })
                    .tag(0)

                FeaturesStep(onNext: { advance() })
                    .tag(1)

                HealthPermissionsStep(onNext: { advance() }, onSkip: { advance() })
                    .tag(2)

                ProfileSetupStep(
                    name: $profileName,
                    username: $username,
                    companyCode: $companyCode,
                    selectedPhoto: $selectedPhoto,
                    avatarImage: $avatarImage,
                    onFinish: { finish() }
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
    }

    private func advance() {
        withAnimation { currentStep = min(currentStep + 1, 3) }
    }

    private func finish() {
        Task {
            // Save text fields
            try? await ProfileManager.shared.save(
                fullName: profileName,
                handle:   username.hasPrefix("@") ? username : "@\(username)",
                company:  companyCode
            )

            // Upload avatar if one was chosen
            if let item = selectedPhoto,
               let data = try? await item.loadTransferable(type: Data.self),
               let uiImg = UIImage(data: data),
               let jpeg = uiImg.jpegData(compressionQuality: 0.8) {
                _ = try? await ProfileManager.shared.uploadAvatar(imageData: jpeg)
            }

            withAnimation { hasCompletedOnboarding = true }
        }
    }
}

// ============================================================
// MARK: - Step Dots (progress indicator)
// ============================================================

struct StepDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                if i == current {
                    Capsule()
                        .fill(Color.bfPrimary)
                        .frame(width: 20, height: 6)
                        .overlay(Capsule().stroke(Color.bfBorder, lineWidth: 0.5))
                } else {
                    Circle()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .animation(.spring(response: 0.3), value: current)
    }
}

// ============================================================
// BFButton lives in Atoms.swift — usage below maps title: → label:

// ============================================================
// MARK: - Step 1: Welcome
// ============================================================

struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // ── Yellow hero
            ZStack(alignment: .bottom) {
                Color.bfPrimary.ignoresSafeArea(edges: .top)

                VStack(spacing: 8) {
                    Text("BetFit.")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.bfBlack)

                    Text("Walk more. Win together.")
                        .font(.system(size: 14))
                        .foregroundColor(.bfTextWeak)

                    // Illustration placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.07))
                            .frame(width: 200, height: 160)

                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                StatChip(value: "8.4k", label: "steps")
                                StatChip(value: "#2",   label: "rank")
                            }
                            Image(systemName: "figure.walk")
                                .font(.system(size: 40))
                                .foregroundColor(.bfBlack.opacity(0.6))
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .padding(.top, 60)
            }
            .frame(height: 380)

            // ── Bottom content
            VStack(alignment: .leading, spacing: 16) {
                Text("Your team's fitness,\ngamified.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.bfBlack)
                    .lineSpacing(2)

                Text("Pair up with a friend or colleague, track your steps, and climb the leaderboard — together.")
                    .font(.system(size: 14))
                    .foregroundColor(.bfTextWeak)
                    .lineSpacing(3)

                Spacer()

                VStack(spacing: 12) {
                    BFButton(label: "Get started", variant: .primary, fullWidth: true, height: 52, action: onNext)
                    BFButton(label: "I already have an account", variant: .secondary, fullWidth: true, height: 52, action: onNext)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .background(Color.bfBgRaised)
        }
        .ignoresSafeArea(edges: .top)
    }
}

// Small chip used in illustration
private struct StatChip: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(.bfBlack)
            Text(label).font(.system(size: 9)).foregroundColor(.bfTextWeak)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.bfBgRaised)
        .clipShape(Capsule())
    }
}

// ============================================================
// MARK: - Step 2: Features
// ============================================================

struct FeaturesStep: View {
    let onNext: () -> Void

    private let features: [(icon: String, title: String, desc: String)] = [
        ("person.2.fill",        "Pair up",              "Team up with a friend or colleague. Your steps add up together."),
        ("trophy.fill",          "Compete in challenges","Join company-wide competitions and watch your team rise the leaderboard."),
        ("heart.text.square.fill","Auto step sync",       "Pulls steps from Apple Health automatically, even in the background."),
    ]

    var body: some View {
        VStack(spacing: 0) {

            // ── Yellow header
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                Text("HOW IT WORKS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.bfBlack.opacity(0.5))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.10))
                    .clipShape(Capsule())

                Text("Walk, compete,\nget fit.")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.bfBlack)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 60)
            .background(Color.bfPrimary.ignoresSafeArea(edges: .top))

            StepDots(total: 4, current: 1)
                .padding(.top, 16)

            // ── Feature list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(features.indices, id: \.self) { i in
                        let f = features[i]
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.bfPrimary)
                                    .frame(width: 44, height: 44)
                                Image(systemName: f.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(.bfBlack)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(f.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.bfBlack)
                                Text(f.desc)
                                    .font(.system(size: 12))
                                    .foregroundColor(.bfTextWeak)
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)

                        if i < features.count - 1 {
                            Divider().padding(.horizontal, 20)
                        }
                    }
                }
                .background(Color.bfBgRaised)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }

            // ── CTA
            BFButton(label: "Continue", variant: .primary, fullWidth: true, height: 52, action: onNext)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .padding(.top, 16)
        }
        .background(Color.bfBg)
        .ignoresSafeArea(edges: .top)
    }
}

// ============================================================
// MARK: - Step 3: Health Permissions
// ============================================================

struct HealthPermissionsStep: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    private let permissions: [(icon: String, label: String, reason: String)] = [
        ("shoeprints.fill",      "Step count",       "To track your daily steps and score your team"),
        ("map.fill",             "Walking distance",  "To show how far you and your team have walked"),
        ("figure.run",           "Workout sessions",  "To log your Couch to 5K completions"),
    ]

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.bfPrimary)
                    .frame(width: 72, height: 72)
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.bfBlack)
            }

            Spacer().frame(height: 20)

            Text("Connect Apple Health")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.bfBlack)

            Spacer().frame(height: 8)

            Text("BetFit reads your steps and distance automatically.\nNo manual logging.")
                .font(.system(size: 14))
                .foregroundColor(.bfTextWeak)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 40)

            StepDots(total: 4, current: 2)
                .padding(.top, 20)

            Spacer().frame(height: 20)

            // ── Permission rows
            VStack(spacing: 0) {
                ForEach(permissions.indices, id: \.self) { i in
                    let p = permissions[i]
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.bfPrimary20)
                                .frame(width: 36, height: 36)
                            Image(systemName: p.icon)
                                .font(.system(size: 16))
                                .foregroundColor(.bfBlack)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.bfBlack)
                            Text(p.reason)
                                .font(.system(size: 11))
                                .foregroundColor(.bfTextMuted)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if i < permissions.count - 1 {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
            .background(Color.bfBgRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.bfBorderLight, lineWidth: 0.5)
            )
            .padding(.horizontal, 24)

            Spacer().frame(height: 12)

            Text("We never sell your health data. You can revoke access anytime in iOS Settings.")
                .font(.system(size: 11))
                .foregroundColor(.bfTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                BFButton(label: "Allow Health access", variant: .primary, fullWidth: true, height: 52, action: {
                    Task {
                        try? await HealthKitManager.shared.requestAuthorization()
                        onNext()
                    }
                })

                BFButton(label: "Skip for now", variant: .secondary, fullWidth: true, height: 52, action: onSkip)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.bfBg)
    }
}

// ============================================================
// MARK: - Step 4: Profile Setup
// ============================================================

struct ProfileSetupStep: View {
    @Binding var name: String
    @Binding var username: String
    @Binding var companyCode: String
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var avatarImage: Image?
    let onFinish: () -> Void

    @FocusState private var focusedField: Field?

    enum Field: Hashable { case name, username, company }

    var canContinue: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {

            // ── Yellow header
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text("Set up your profile")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.bfBlack)
                Text("Your teammates will see this on the leaderboard.")
                    .font(.system(size: 13))
                    .foregroundColor(.bfTextWeak)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 60)
            .background(Color.bfPrimary.ignoresSafeArea(edges: .top))

            StepDots(total: 4, current: 3)
                .padding(.top, 16)

            ScrollView {
                VStack(spacing: 20) {

                    // ── Avatar picker
                    VStack(spacing: 8) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(Color.bfPrimary20)
                                    .frame(width: 80, height: 80)
                                    .overlay(Circle().stroke(Color.bfBorder.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4])))

                                if let avatarImage {
                                    avatarImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.bfTextWeak)
                                }
                            }
                        }
                        .onChange(of: selectedPhoto) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let uiImg = UIImage(data: data) {
                                    avatarImage = Image(uiImage: uiImg)
                                }
                            }
                        }

                        Text("Add a photo")
                            .font(.system(size: 12))
                            .foregroundColor(.bfTextWeak)
                    }

                    // ── Form fields
                    VStack(spacing: 14) {
                        BFTextField(label: "Full name", placeholder: "e.g. Usain Bolt", text: $name, focused: $focusedField, field: .name)

                        BFTextField(label: "Username", placeholder: "@yourhandle", text: $username, focused: $focusedField, field: .username)

                        BFTextField(
                            label: "Company invite code",
                            sublabel: "optional",
                            placeholder: "e.g. ACME2024",
                            text: $companyCode,
                            focused: $focusedField,
                            field: .company,
                            isUppercase: true
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }

            // ── CTA
            Button(action: onFinish) {
                HStack(spacing: 6) {
                    Text("Let's go")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(canContinue ? .bfBlack : .bfTextMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canContinue ? Color.bfPrimary : Color.bfPrimaryDisabled)
                .clipShape(Capsule())
            }
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 12)
        }
        .background(Color.bfBg)
        .ignoresSafeArea(edges: .top)
    }
}

// ── Reusable text field
struct BFTextField: View {
    let label: String
    var sublabel: String? = nil
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<ProfileSetupStep.Field?>.Binding
    let field: ProfileSetupStep.Field
    var isUppercase: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.bfTextWeak)
                if let sub = sublabel {
                    Text("(\(sub))")
                        .font(.system(size: 12))
                        .foregroundColor(.bfTextMuted)
                }
            }

            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .foregroundColor(.bfBlack)
                .focused(focused, equals: field)
                .autocorrectionDisabled()
                .textInputAutocapitalization(isUppercase ? .characters : .never)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.bfBgRaised)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(focused.wrappedValue == field ? Color.bfBlack : Color.bfBorder, lineWidth: focused.wrappedValue == field ? 1 : 0.5)
                )
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview {
    OnboardingView()
}
