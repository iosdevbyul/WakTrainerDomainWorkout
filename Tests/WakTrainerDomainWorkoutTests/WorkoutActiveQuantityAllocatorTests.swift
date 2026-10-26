import Foundation
import Testing
import WakTrainerCoreModels

@testable import WakTrainerDomainWorkout

@Suite("Pause-aware HealthKit quantity allocation")
struct WorkoutActiveQuantityAllocatorTests {
    let origin = Date(timeIntervalSince1970: 1_800_000_000)

    func sample(
        _ metric: WorkoutHealthMetric,
        start: Double,
        end: Double,
        value: Double
    ) -> WorkoutHealthMetricSample {
        WorkoutHealthMetricSample(
            metric: metric,
            startDate: origin.addingTimeInterval(start),
            endDate: origin.addingTimeInterval(end),
            value: value,
            unit: "count"
        )
    }

    func allocator(_ windows: [(Double, Double)]) -> WorkoutActiveQuantityAllocator {
        WorkoutActiveQuantityAllocator(pauseIntervals: windows.map {
            WorkoutPauseInterval(
                startDate: origin.addingTimeInterval($0.0),
                endDate: origin.addingTimeInterval($0.1)
            )
        })
    }

    @Test("Partial pause overlap prorates a cumulative sample")
    func proratesOverlap() {
        let total = allocator([(3, 7)]).activeTotal(
            for: .activeEnergyBurned,
            in: [sample(.activeEnergyBurned, start: 0, end: 10, value: 100)]
        )
        #expect(total == 60)
    }

    @Test("Overlapping pause windows are merged before allocation")
    func mergesOverlappingPauses() {
        let total = allocator([(2, 6), (4, 8)]).activeTotal(
            for: .stepCount,
            in: [sample(.stepCount, start: 0, end: 10, value: 100)]
        )
        #expect(total == 40)
    }

    @Test("Unavailable or zero-duration quantities are not fabricated")
    func missingQuantities() {
        let a = allocator([(2, 6)])
        #expect(a.activeTotal(for: .stepCount, in: []) == nil)
        #expect(a.activeTotal(
            for: .stepCount,
            in: [sample(.stepCount, start: 5, end: 5, value: 20)]
        ) == nil)
    }

    @Test("Mixed HealthKit distance types are not summed")
    func rejectsAmbiguousDistance() {
        let a = allocator([(2, 6)])
        let mixed = [
            sample(.distanceCycling, start: 0, end: 10, value: 100),
            sample(.distanceWalkingRunning, start: 0, end: 10, value: 100)
        ]
        #expect(a.unambiguousActiveDistance(in: mixed) == nil)
        #expect(a.unambiguousActiveDistance(in: [mixed[0]]) == 60)
    }

    @Test("Report uses prorated quantities without mutating raw data")
    func reportUsesActiveTotals() throws {
        let samples = [
            sample(.activeEnergyBurned, start: 0, end: 10, value: 100),
            sample(.stepCount, start: 0, end: 10, value: 200),
            sample(.distanceCycling, start: 0, end: 10, value: 1000)
        ]
        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "cycling",
                name: "Cycling",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: origin,
                endDate: origin.addingTimeInterval(10),
                elapsedDuration: 10,
                activeDuration: 6,
                pausedDuration: 4,
                pauseIntervals: [
                    WorkoutPauseInterval(
                        startDate: origin.addingTimeInterval(3),
                        endDate: origin.addingTimeInterval(7)
                    )
                ]
            ),
            health: WorkoutHealthData(
                summary: WorkoutHealthSummary(
                    activeCalories: 100,
                    stepCount: 200,
                    distanceMeters: 1000
                ),
                samples: samples
            )
        )
        let report = WorkoutReportBuilder().makeReport(from: session)
        #expect(report.summary.activeCalories == 60)
        #expect(report.summary.stepCount == 120)
        #expect(report.summary.distanceMeters == 600)
        #expect(report.cardio?.distanceMeters == 600)
        #expect(session.health.summary.activeCalories == 100)
        #expect(session.health.samples.count == 3)
    }

    @Test("Repeated delivery of the same sample ID counts once")
    func duplicateIdentityIsDeduplicated() {
        let original = sample(.stepCount, start: 0, end: 10, value: 100)
        let result = allocator([(3, 7)]).activeTotal(
            for: .stepCount,
            in: [original, original]
        )
        #expect(result == 60)
    }

    @Test("Overlapping different sample IDs fail closed instead of double counting")
    func overlappingDistinctSamplesAreAmbiguous() {
        let result = allocator([(3, 7)]).activeTotal(
            for: .stepCount,
            in: [
                sample(.stepCount, start: 0, end: 10, value: 100),
                sample(.stepCount, start: 5, end: 15, value: 100)
            ]
        )
        #expect(result == nil)
    }

    @Test("Adjacent distinct samples can be safely allocated")
    func adjacentSamplesAreAllowed() {
        let result = allocator([(3, 7)]).activeTotal(
            for: .stepCount,
            in: [
                sample(.stepCount, start: 0, end: 5, value: 50),
                sample(.stepCount, start: 5, end: 10, value: 50)
            ]
        )
        #expect(result == 60)
    }

    @Test("Overlapping samples do not silently override report aggregates")
    func ambiguousReportQuantityIsUnknown() {
        let raw = [
            sample(.activeEnergyBurned, start: 0, end: 10, value: 100),
            sample(.activeEnergyBurned, start: 5, end: 15, value: 100)
        ]
        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "cycling",
                name: "Cycling",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: origin,
                endDate: origin.addingTimeInterval(15),
                elapsedDuration: 15,
                activeDuration: 11,
                pausedDuration: 4,
                pauseIntervals: [
                    WorkoutPauseInterval(
                        startDate: origin.addingTimeInterval(3),
                        endDate: origin.addingTimeInterval(7)
                    )
                ]
            ),
            health: WorkoutHealthData(
                summary: WorkoutHealthSummary(activeCalories: 200),
                samples: raw
            )
        )
        let report = WorkoutReportBuilder().makeReport(from: session)
        #expect(report.summary.activeCalories == nil)
        #expect(session.health.summary.activeCalories == 200)
        #expect(session.health.samples.count == 2)
    }

    @Test("No pause retains existing aggregate reporting behavior")
    func noPauseRetainsAggregate() {
        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "cycling",
                name: "Cycling",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: origin,
                endDate: origin.addingTimeInterval(10),
                elapsedDuration: 10,
                activeDuration: 10,
                pausedDuration: 0
            ),
            health: WorkoutHealthData(
                summary: WorkoutHealthSummary(activeCalories: 95, stepCount: 210)
            )
        )
        let report = WorkoutReportBuilder().makeReport(from: session)
        #expect(report.summary.activeCalories == 95)
        #expect(report.summary.stepCount == 210)
    }
}
