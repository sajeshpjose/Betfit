// ============================================================
// StepSyncManager.swift
// BetFit
// ============================================================
// Bridges HealthKit and Supabase:
//   - Reads steps + distance from HealthKit
//   - Upserts into step_logs table in Supabase
//   - Syncs today + last 7 days on first run
//   - Background sync via HealthKit observer query
// ============================================================

import Foundation
import HealthKit
import Combine

@MainActor
class StepSyncManager: ObservableObject {

    static let shared = StepSyncManager()

    @Published var todaySteps: Int       = 0
    @Published var todayDistanceKm: Double = 0.0
    @Published var isSyncing: Bool       = false
    @Published var lastSyncedAt: Date?   = nil
    @Published var errorMessage: String? = nil

    private let store = HKHealthStore()

    private let stepType     = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!

    private init() {}

    // ============================================================
    // MARK: - 1. Request HealthKit Permission
    // Call this from onboarding step 3 or on first dashboard load
    // ============================================================

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device."
            return false
        }

        let readTypes: Set<HKObjectType> = [stepType, distanceType]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // ============================================================
    // MARK: - 2. Fetch + Sync Today
    // Call this when dashboard loads and after background delivery
    // ============================================================

    func syncToday(challengeId: String) async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let steps    = try await fetchSteps(for: Date())
            let distance = try await fetchDistance(for: Date())

            todaySteps       = steps
            todayDistanceKm  = distance

            await upsertStepLog(
                date:        Date(),
                steps:       steps,
                distanceKm:  distance,
                challengeId: challengeId
            )

            lastSyncedAt = Date()

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // ============================================================
    // MARK: - 3. Backfill Last 7 Days
    // Call once after user first grants HealthKit permission
    // ============================================================

    func syncLastSevenDays(challengeId: String) async {
        let calendar = Calendar.current
        let today    = Date()

        for daysAgo in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }

            do {
                let steps    = try await fetchSteps(for: date)
                let distance = try await fetchDistance(for: date)

                await upsertStepLog(
                    date:        date,
                    steps:       steps,
                    distanceKm:  distance,
                    challengeId: challengeId
                )
            } catch {
                print("Failed to sync \(date): \(error)")
            }
        }

        lastSyncedAt = Date()
    }

    // ============================================================
    // MARK: - 4. Setup Background Delivery
    // iOS wakes the app hourly to sync new steps even when closed
    // ============================================================

    func setupBackgroundDelivery(challengeId: String) {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // Observer query fires when HealthKit has new step data
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, error in
            guard error == nil else { return }
            Task { @MainActor in
                await self?.syncToday(challengeId: challengeId)
            }
        }
        store.execute(query)

        // Enable hourly background delivery
        store.enableBackgroundDelivery(for: stepType, frequency: .hourly) { success, error in
            if let error = error {
                print("Background delivery setup failed: \(error)")
            }
        }
    }

    // ============================================================
    // MARK: - 5. Upsert to Supabase
    // Uses the onConflict duplicate key to safely re-sync
    // ============================================================

    private func upsertStepLog(
        date: Date,
        steps: Int,
        distanceKm: Double,
        challengeId: String
    ) async {
        guard let userId = AuthManager.shared.userId else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        let payload: [String: Any] = [
            "user_id":      userId,
            "challenge_id": challengeId,
            "log_date":     dateString,
            "step_count":   steps,
            "distance_km":  distanceKm,
            "synced_at":    ISO8601DateFormatter().string(from: Date())
        ]

        do {
            // POST with upsert — onConflict handles duplicate (user_id, challenge_id, log_date)
            _ = try await AuthManager.shared.post(
                path: "step_logs?on_conflict=user_id,challenge_id,log_date",
                body: payload,
                method: "POST"
            )
        } catch {
            print("Supabase upsert failed: \(error)")
        }
    }

    // ============================================================
    // MARK: - HealthKit Query Helpers
    // ============================================================

    func fetchSteps(for date: Date) async throws -> Int {
        let (start, end) = dayBounds(for: date)
        let predicate    = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType:            stepType,
                quantitySamplePredicate: predicate,
                options:                 .cumulativeSum
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

    func fetchDistance(for date: Date) async throws -> Double {
        let (start, end) = dayBounds(for: date)
        let predicate    = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType:            distanceType,
                quantitySamplePredicate: predicate,
                options:                 .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let meters = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: meters / 1000.0)
            }
            store.execute(query)
        }
    }

    private func dayBounds(for date: Date) -> (Date, Date) {
        let calendar = Calendar.current
        let start    = calendar.startOfDay(for: date)
        let end      = calendar.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }
}
