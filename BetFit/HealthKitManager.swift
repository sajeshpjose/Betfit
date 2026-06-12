// ============================================================
// HealthKitManager.swift
// Step Challenge App
// ============================================================
// Handles all HealthKit interactions:
//   - Permission requests
//   - Step count queries (daily + range)
//   - Distance walked queries
//   - Background delivery (syncs steps even when app is closed)
//   - Supabase sync
// ============================================================

import HealthKit
import Foundation
import Combine

// ============================================================
// MARK: - Models
// ============================================================

struct DailyActivity {
    let date: Date
    let stepCount: Int
    let distanceKm: Double
}

// ============================================================
// MARK: - HealthKitManager
// ============================================================

@MainActor
class HealthKitManager: ObservableObject {

    // Singleton — one instance used across the whole app
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    // Published so SwiftUI views can react to permission state
    @Published var isAuthorized = false
    @Published var todaySteps: Int = 0
    @Published var todayDistanceKm: Double = 0.0

    // The data types we need to read from HealthKit
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
    ]

    private init() {}


    // ============================================================
    // MARK: - 1. Permission Request
    // Call this on first launch or from the onboarding screen.
    // ============================================================

    func requestAuthorization() async throws {
        // HealthKit is not available on iPad or simulator
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        try await store.requestAuthorization(toShare: [], read: readTypes)

        // Check if user actually granted access
        let status = store.authorizationStatus(
            for: HKObjectType.quantityType(forIdentifier: .stepCount)!
        )
        isAuthorized = (status == .sharingAuthorized)

        if isAuthorized {
            await setupBackgroundDelivery()
        }
    }


    // ============================================================
    // MARK: - 2. Query Today's Steps
    // Fetches step count and distance for the current calendar day.
    // ============================================================

    func fetchTodayActivity() async throws -> DailyActivity {
        let steps    = try await fetchSteps(for: Date())
        let distance = try await fetchDistance(for: Date())

        await MainActor.run {
            self.todaySteps      = steps
            self.todayDistanceKm = distance
        }

        return DailyActivity(date: Date(), stepCount: steps, distanceKm: distance)
    }


    // ============================================================
    // MARK: - 3. Query a Date Range
    // Used when syncing historical data to Supabase (e.g. past 7 days).
    // ============================================================

    func fetchActivity(from startDate: Date, to endDate: Date) async throws -> [DailyActivity] {
        var activities: [DailyActivity] = []

        // Iterate day by day across the range
        let calendar = Calendar.current
        var current  = calendar.startOfDay(for: startDate)
        let end      = calendar.startOfDay(for: endDate)

        while current <= end {
            let steps    = try await fetchSteps(for: current)
            let distance = try await fetchDistance(for: current)

            activities.append(DailyActivity(
                date:        current,
                stepCount:   steps,
                distanceKm:  distance
            ))

            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return activities
    }


    // ============================================================
    // MARK: - 4. Background Delivery
    // iOS will wake the app periodically to sync new step data
    // even when the app is in the background or closed.
    // ============================================================

    private func setupBackgroundDelivery() async {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }

        // Ask HealthKit to notify us hourly when new steps are recorded
        do {
            try await store.enableBackgroundDelivery(for: stepType, frequency: .hourly)

            // Set up an observer query — fires whenever HealthKit has new step data
            let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, error in
                guard error == nil else { return }
                Task {
                    await self?.syncToSupabase()
                }
            }
            store.execute(query)
        } catch {
            print("Background delivery setup failed: \(error)")
        }
    }


    // ============================================================
    // MARK: - 5. Supabase Sync
    // Upserts today's step log into Supabase.
    // The unique constraint (user_id, challenge_id, log_date)
    // ensures no duplicate rows — safe to call repeatedly.
    // ============================================================

    func syncToSupabase(challengeId: String? = nil) async {
        do {
            let activity = try await fetchTodayActivity()

            // Format date as YYYY-MM-DD for Supabase
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: activity.date)

            // Build the upsert payload
            var payload: [String: Any] = [
                "log_date":    dateString,
                "step_count":  activity.stepCount,
                "distance_km": activity.distanceKm,
                "synced_at":   ISO8601DateFormatter().string(from: Date())
            ]

            // Include challenge_id if provided
            if let challengeId = challengeId {
                payload["challenge_id"] = challengeId
            }

            // Call Supabase REST API — upsert on conflict
            try await SupabaseClient.shared.upsertStepLog(payload: payload)

        } catch {
            print("Sync failed: \(error)")
        }
    }


    // ============================================================
    // MARK: - Private Helpers
    // ============================================================

    // Fetch total steps for a single calendar day
    private func fetchSteps(for date: Date) async throws -> Int {
        let (start, end) = dayBounds(for: date)

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start, end: end, options: .strictStartDate
            )

            let query = HKStatisticsQuery(
                quantityType:    HKQuantityType.quantityType(forIdentifier: .stepCount)!,
                quantitySamplePredicate: predicate,
                options:         .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }

            store.execute(query)
        }
    }

    // Fetch total walking/running distance for a single calendar day
    private func fetchDistance(for date: Date) async throws -> Double {
        let (start, end) = dayBounds(for: date)

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start, end: end, options: .strictStartDate
            )

            let query = HKStatisticsQuery(
                quantityType:    HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                quantitySamplePredicate: predicate,
                options:         .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let meters = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: meters / 1000.0) // convert to km
            }

            store.execute(query)
        }
    }

    // Returns midnight-to-midnight bounds for a given date
    private func dayBounds(for date: Date) -> (Date, Date) {
        let calendar = Calendar.current
        let start    = calendar.startOfDay(for: date)
        let end      = calendar.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }
}


// ============================================================
// MARK: - HealthKit Errors
// ============================================================

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:       return "HealthKit is not available on this device."
        case .notAuthorized:      return "HealthKit access was not granted."
        case .queryFailed(let m): return "HealthKit query failed: \(m)"
        }
    }
}


// ============================================================
// MARK: - Supabase Client (stub)
// Replace with actual Supabase Swift SDK calls.
// Add package: https://github.com/supabase/supabase-swift
// ============================================================

class SupabaseClient {
    static let shared = SupabaseClient()
    private init() {}

    func upsertStepLog(payload: [String: Any]) async throws {
        // Replace this with the real Supabase Swift SDK:
        //
        // try await supabase
        //   .from("step_logs")
        //   .upsert(payload, onConflict: "user_id,challenge_id,log_date")
        //   .execute()
        //
        print("Upserting step log: \(payload)")
    }
}
