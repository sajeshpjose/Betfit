# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
# Build for generic iOS device (no simulator required)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme BetFit -destination generic/platform=iOS build

# Open in Xcode to run on simulator or device
open BetFit.xcodeproj
```

There are no automated tests. Verification is done by building and running on device/simulator.

## Architecture

### Stack
- **SwiftUI** — all UI, always-dark (`preferredColorScheme(.dark)` enforced in `BetFitApp`)
- **Supabase** — backend via raw REST/URLSession (no SDK). Base URL and publishable key are hardcoded in `SupabaseManager.swift` and `ProfileManager.swift`
- **HealthKit** — step count + walking distance via `StepSyncManager`
- **Authentication** — `ASWebAuthenticationSession` for in-app OAuth (Apple + Google), managed by `AuthManager`

### App entry point & navigation
`BetFitApp.swift` controls the root view state machine:
1. `SplashView` while `AuthManager.isLoading`
2. `AuthView` if not signed in
3. `OnboardingView` if signed in but `hasCompletedOnboarding == false` (AppStorage)
4. `MainTabView` otherwise — four tabs: **Home · Challenges · Team · Profile**

`LeaderboardView` and `C25KView` exist but are **not in the tab bar** — `LeaderboardView` is embedded inside `ChallengeDetailView`; `C25KView` is intended to surface as a challenge type.

### Design system (Atomic Design)
All shared UI primitives live in two files — use these instead of writing inline styles:

- **`Atoms.swift`** — `BFCard` (`.bfCard()` / `.bfElevatedCard()` view modifiers), `BFAvatar`, `BFBadge` (6 variants via `BFBadgeVariant`), `BFButton` (4 variants via `BFButtonVariant`), `BFStatBox`, `BFProgressBar`, `BFToast`, `BFSectionLabel`, `BFNavBarTitle`
- **`Molecules.swift`** — `BFLeaderboardRow` (full + `compact: true`), `BFFilterTabBar<T>` (generic over any `RawRepresentable & CaseIterable` with `String` raw value), `BFSettingRow`, `BFInfoRow`, `BFMemberRow`
- **`Colors.swift`** — all semantic color tokens as `Color` extensions (e.g. `Color.bfPrimary`, `Color.bfBg`, `Color.bfBgRaised`, `Color.bfTextWeak`). Never use raw hex in views.

### Backend layer
- **`SupabaseManager.swift`** — `AuthManager` singleton. Handles sign-in/out, session restore, token persistence (UserDefaults), and generic `get(path:)` / `post(path:body:method:)` helpers used by all other managers.
- **`ProfileManager.swift`** — loads/saves `profiles` table row; `uploadAvatar(imageData:)` uploads JPEG to Supabase Storage `avatars` bucket and stores the public URL.
- **`StepSyncManager.swift`** — bridges HealthKit → Supabase `step_logs` table. Exposes `todaySteps`, `todayDistanceKm`, `weeklySteps` (for the profile chart). Call `syncToday(challengeId:)` on dashboard load; `setupBackgroundDelivery` enables hourly HealthKit observer.

### Data that is currently hardcoded (not yet from Supabase)
- Leaderboard teams/members in `LeaderboardView` and `DashboardView`
- Team members and challenge info in `TeamView`
- Challenge list in `ChallengesView` (uses `BFChallenge.samples`)
- Profile stats: challenges count, streak days, best finish (`ProfileView`)
- The `challengeId` in `DashboardView` is a hardcoded UUID placeholder

### Challenges feature
`ChallengeModels.swift` defines `BFChallenge`, `BFChallengeTeam`, `ChallengeLeaderboardEntry`, and `ChallengeType` (`.steps`, `.distance`, `.c25k`). The required Supabase SQL schema (tables + RLS policies) is documented in comments at the top of that file. `EnrollSheet` in `ChallengeDetailView.swift` has a `// TODO` stub where the `challenge_teams` POST should go.

### Onboarding
`OnboardingView` collects name, username, company code, and an optional avatar across 4 steps. `finish()` saves to `ProfileManager` and uploads avatar before setting `hasCompletedOnboarding = true`.

### Page title convention
Page titles are **not** in the navigation toolbar — they are the first element inside each `ScrollView` `VStack` to avoid UIKit's `.inline` mode clipping. Toolbar items are action-only (e.g. gear icon, days-left pill).

### Supabase tables in use
| Table | Purpose |
|---|---|
| `profiles` | User display name, handle, company, avatar URL |
| `step_logs` | Daily steps + distance per user per challenge |
| `challenges` | Admin-created challenges (schema in `ChallengeModels.swift`) |
| `challenge_teams` | Teams enrolled in a challenge |
| `challenge_team_members` | Members of each team |

All tables have RLS enabled. Users can only read/write their own rows.
