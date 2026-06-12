// ============================================================
// C25KView.swift
// BetFit
// ============================================================
// Couch to 5K screen showing:
//   - Program progress (day dots + progress bar)
//   - Today's workout card (dark) with segment visualiser
//   - Interval breakdown list
//   - Coach tip card
//   - This week calendar
// ============================================================

import SwiftUI

// ============================================================
// MARK: - Models
// ============================================================

struct WorkoutSegment: Identifiable {
    let id = UUID()
    let type: SegmentType
    let distanceMeters: Int
    let note: String

    enum SegmentType: String {
        case walk = "Walk"
        case run  = "Run"
    }
}

struct C25KDay: Identifiable {
    let id = UUID()
    let dayNumber: Int
    let title: String
    let description: String
    let segments: [WorkoutSegment]
    let durationMinutes: Int

    var totalRunMeters: Int { segments.filter { $0.type == .run }.reduce(0) { $0 + $1.distanceMeters } }
    var totalDistanceMeters: Int { segments.reduce(0) { $0 + $1.distanceMeters } }
    var totalDistanceKm: Double { Double(totalDistanceMeters) / 1000.0 }
}

enum DayState {
    case done, today, upcoming, rest
}

// ============================================================
// MARK: - C25K View
// ============================================================

struct C25KView: View {

    // Mock — replace with Supabase c25k_days + c25k_progress later
    let currentDay: Int = 8
    let totalDays: Int  = 30

    let todayWorkout = C25KDay(
        dayNumber: 8,
        title: "Longer intervals",
        description: "Building real endurance now. Longer run bursts with active walk recovery.",
        segments: [
            WorkoutSegment(type: .walk, distanceMeters: 300, note: "warm-up"),
            WorkoutSegment(type: .run,  distanceMeters: 200, note: "easy pace"),
            WorkoutSegment(type: .walk, distanceMeters: 200, note: "recovery"),
            WorkoutSegment(type: .run,  distanceMeters: 200, note: "easy pace"),
            WorkoutSegment(type: .walk, distanceMeters: 200, note: "recovery"),
            WorkoutSegment(type: .run,  distanceMeters: 200, note: "easy pace"),
            WorkoutSegment(type: .walk, distanceMeters: 200, note: "cool-down"),
        ],
        durationMinutes: 28
    )

    let tips: [String] = [
        "Run slow enough to hold a conversation. If you can't, slow down.",
        "Walk briskly during recovery — don't stop completely.",
        "Every step counts toward your team challenge too.",
    ]

    // Week data — Mon to Sun
    let weekDays: [(label: String, state: DayState, dayNum: Int?)] = [
        ("Mon", .done,     6),
        ("Tue", .rest,     nil),
        ("Wed", .done,     7),
        ("Thu", .today,    8),
        ("Fri", .rest,     nil),
        ("Sat", .upcoming, 9),
        ("Sun", .rest,     nil),
    ]

    var progress: Double { Double(currentDay - 1) / Double(totalDays) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Couch to 5K")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Text("Week 2 · Building your base")
                            .font(.system(size: 13))
                            .foregroundColor(.bfTextWeak)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // ── Progress bar
                    ProgressSection(
                        currentDay: currentDay,
                        totalDays: totalDays,
                        progress: progress
                    )

                    // ── Day dots
                    DayDotsView(totalDays: totalDays, currentDay: currentDay)

                    // ── Today's workout card
                    TodayWorkoutCard(workout: todayWorkout)

                    // ── Interval breakdown
                    IntervalBreakdownCard(segments: todayWorkout.segments)

                    // ── Coach tip
                    CoachTipCard(tips: tips)

                    // ── This week
                    ThisWeekCard(days: weekDays)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.bfBg)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// ============================================================
// MARK: - Progress Section
// ============================================================

struct ProgressSection: View {
    let currentDay: Int
    let totalDays: Int
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Day **\(currentDay)** of \(totalDays)")
                    .font(.system(size: 11))
                    .foregroundColor(.bfTextWeak)
                Spacer()
                Text("**\(Int(progress * 100))%** complete")
                    .font(.system(size: 11))
                    .foregroundColor(.bfTextWeak)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.bfPrimary)
                        .frame(width: geo.size.width * progress, height: 6)
                        .overlay(Capsule().stroke(Color.bfBorder, lineWidth: 0.5))
                        .animation(.easeOut(duration: 0.8), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// ============================================================
// MARK: - Day Dots
// ============================================================

struct DayDotsView: View {
    let totalDays: Int
    let currentDay: Int

    func stateFor(_ day: Int) -> DayState {
        if day < currentDay { return .done }
        if day == currentDay { return .today }
        if day % 3 == 0 { return .rest }
        return .upcoming
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 15), spacing: 4) {
            ForEach(1...totalDays, id: \.self) { day in
                let state = stateFor(day)
                Circle()
                    .fill(dotColor(state))
                    .frame(width: 8, height: 8)
                    .overlay(
                        state == .rest
                            ? Circle().stroke(Color.black.opacity(0.2), style: StrokeStyle(lineWidth: 0.5, dash: [2]))
                            : nil
                    )
            }
        }
    }

    func dotColor(_ state: DayState) -> Color {
        switch state {
        case .done:     return .bfPrimary
        case .today:    return .bfBlack
        case .rest:     return Color.black.opacity(0.04)
        case .upcoming: return Color.black.opacity(0.08)
        }
    }
}

// ============================================================
// MARK: - Today's Workout Card
// ============================================================

struct TodayWorkoutCard: View {
    let workout: C25KDay
    @State private var isStarted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack {
                Text("Today · Day \(workout.dayNumber)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.bfBlack)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.bfPrimary)
                    .clipShape(Capsule())

                Spacer()

                Text(Date().formatted(.dateTime.weekday(.abbreviated).month().day()))
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#888888"))
            }

            // Title + description
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text(workout.description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#888888"))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Segment visualiser
            VStack(alignment: .leading, spacing: 8) {
                SegmentTrack(segments: workout.segments)

                HStack(spacing: 14) {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.bfPrimary.opacity(0.2))
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.bfPrimary.opacity(0.4), lineWidth: 0.5))
                            .frame(width: 10, height: 10)
                        Text("Walk").font(.system(size: 10)).foregroundColor(Color(hex: "#888888"))
                    }
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.bfPrimary)
                            .frame(width: 10, height: 10)
                        Text("Run").font(.system(size: 10)).foregroundColor(Color(hex: "#888888"))
                    }
                    Spacer()
                }
            }

            // Stats
            HStack {
                WorkoutStat(value: String(format: "%.1f km", workout.totalDistanceKm), label: "Distance")
                Divider().frame(height: 30).background(Color.white.opacity(0.1))
                WorkoutStat(value: "\(workout.durationMinutes) min", label: "Duration")
                Divider().frame(height: 30).background(Color.white.opacity(0.1))
                WorkoutStat(value: "\(workout.totalRunMeters) m", label: "Running")
            }

            // Start button
            Button(action: { isStarted = true }) {
                HStack(spacing: 6) {
                    Image(systemName: isStarted ? "checkmark" : "play.fill")
                    Text(isStarted ? "Session started!" : "Start workout")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.bfBlack)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.bfPrimary)
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color.bfBgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct SegmentTrack: View {
    let segments: [WorkoutSegment]

    var totalDistance: Int { segments.reduce(0) { $0 + $1.distanceMeters } }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(segments) { seg in
                    let ratio = CGFloat(seg.distanceMeters) / CGFloat(totalDistance)
                    let width = ratio * (geo.size.width - CGFloat(segments.count - 1) * 3)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(seg.type == .run ? Color.bfPrimary : Color.bfPrimary.opacity(0.15))
                        .frame(width: width, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(seg.type == .run ? Color.bfBorder : Color.bfPrimary.opacity(0.3), lineWidth: 0.5)
                        )
                        .overlay(
                            Text(seg.type == .run ? "R" : "W")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(seg.type == .run ? .bfBlack : Color.bfPrimary.opacity(0.6))
                        )
                }
            }
        }
        .frame(height: 22)
    }
}

private struct WorkoutStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "#888888"))
        }
        .frame(maxWidth: .infinity)
    }
}

// ============================================================
// MARK: - Interval Breakdown Card
// ============================================================

struct IntervalBreakdownCard: View {
    let segments: [WorkoutSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Interval breakdown")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.bfBlack)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ForEach(Array(segments.enumerated()), id: \.element.id) { index, seg in
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        // Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(seg.type == .run ? Color.bfPrimary : Color.bfPrimary20)
                                .frame(width: 28, height: 28)
                            Text(seg.type == .run ? "R" : "W")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.bfBlack)
                        }

                        Text(seg.type.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.bfBlack)

                        Spacer()

                        Text("\(seg.distanceMeters) m")
                            .font(.system(size: 11))
                            .foregroundColor(.bfTextWeak)

                        Text(seg.note)
                            .font(.system(size: 10))
                            .foregroundColor(.bfTextMuted)
                            .frame(width: 64, alignment: .trailing)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)

                    if index < segments.count - 1 {
                        Divider().padding(.horizontal, 18)
                    }
                }
            }

            Spacer().frame(height: 16)
        }
        .background(Color.bfBgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.bfBorderLight, lineWidth: 0.5))
    }
}

// ============================================================
// MARK: - Coach Tip Card
// ============================================================

struct CoachTipCard: View {
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("💡")
                Text("Coach tip for today")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.bfBlack)
            }

            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 6) {
                    Text("→")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.bfTextWeak)
                    Text(tip)
                        .font(.system(size: 12))
                        .foregroundColor(.bfTextWeak)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(Color.bfPrimary20)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// ============================================================
// MARK: - This Week Card
// ============================================================

struct ThisWeekCard: View {
    let days: [(label: String, state: DayState, dayNum: Int?)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.bfBlack)

            HStack(spacing: 4) {
                ForEach(days.indices, id: \.self) { i in
                    let day = days[i]
                    VStack(spacing: 5) {
                        Text(day.label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.bfTextMuted)

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(blockFill(day.state))
                                .frame(height: 36)

                            switch day.state {
                            case .done:
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.bfBlack)
                            case .today:
                                Text("Day \(day.dayNum ?? 0)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.bfPrimary)
                            case .upcoming:
                                Text("Day \(day.dayNum ?? 0)")
                                    .font(.system(size: 8))
                                    .foregroundColor(.bfTextMuted)
                            case .rest:
                                Text("—")
                                    .font(.system(size: 11))
                                    .foregroundColor(.bfTextMuted)
                            }
                        }
                        .overlay(
                            day.state == .done
                                ? RoundedRectangle(cornerRadius: 8).stroke(Color.bfBorder, lineWidth: 0.5)
                                : nil
                        )

                        Text(stateLabel(day.state))
                            .font(.system(size: 9))
                            .foregroundColor(day.state == .today ? .bfBlack : .bfTextMuted)
                            .fontWeight(day.state == .today ? .semibold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(Color.bfBgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.bfBorderLight, lineWidth: 0.5))
    }

    func blockFill(_ state: DayState) -> Color {
        switch state {
        case .done:     return .bfPrimary
        case .today:    return .bfBlack
        case .rest:     return Color.black.opacity(0.04)
        case .upcoming: return Color.black.opacity(0.04)
        }
    }

    func stateLabel(_ state: DayState) -> String {
        switch state {
        case .done:     return "Done"
        case .today:    return "Today"
        case .rest:     return "Rest"
        case .upcoming: return "Next"
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview {
    C25KView()
}
