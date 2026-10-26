import Foundation
import Testing
import WakTrainerCoreModels

@testable import WakTrainerDomainWorkout

@Suite("Partial workout pause restoration")
struct WorkoutPauseRestoreEngineTests {
    let origin = Date(timeIntervalSince1970: 1_800_000_000)

    func session() -> WorkoutSession {
        WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "cycling",
                name: "Cycling",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: origin,
                endDate: origin.addingTimeInterval(3600),
                elapsedDuration: 3600,
                activeDuration: 2700,
                pausedDuration: 900,
                pauseIntervals: [
                    WorkoutPauseInterval(
                        startDate: origin.addingTimeInterval(1200),
                        endDate: origin.addingTimeInterval(2100)
                    )
                ]
            ),
            health: WorkoutHealthData(
                samples: [
                    WorkoutHealthMetricSample(
                        metric: .heartRate,
                        startDate: origin.addingTimeInterval(1500),
                        endDate: origin.addingTimeInterval(1501),
                        value: 130,
                        unit: "bpm"
                    )
                ]
            )
        )
    }

    @Test("Restore ten of fifteen paused minutes and retain remaining pause")
    func restoresPartialInterval() throws {
        let original = session()
        let result = try WorkoutPauseRestoreEngine().restore(
            session: original,
            from: origin.addingTimeInterval(1200),
            to: origin.addingTimeInterval(1800)
        )
        #expect(result.restoredDuration == 600)
        #expect(result.updated.timing.activeDuration == 3300)
        #expect(result.updated.timing.pausedDuration == 300)
        #expect(result.updated.timing.elapsedDuration == 3600)
        #expect(result.updated.timing.pauseIntervals == [
            WorkoutPauseInterval(
                startDate: origin.addingTimeInterval(1800),
                endDate: origin.addingTimeInterval(2100)
            )
        ])
        #expect(result.updated.health == original.health)
        #expect(result.updated.route == original.route)
        #expect(result.undo() == original)
    }

    @Test("Restoring an interior subrange splits the remaining pause")
    func splitsPause() throws {
        let result = try WorkoutPauseRestoreEngine().restore(
            session: session(),
            from: origin.addingTimeInterval(1500),
            to: origin.addingTimeInterval(1800)
        )
        #expect(result.updated.timing.pauseIntervals.count == 2)
        #expect(result.updated.timing.pauseIntervals[0].endDate == origin.addingTimeInterval(1500))
        #expect(result.updated.timing.pauseIntervals[1].startDate == origin.addingTimeInterval(1800))
    }

    @Test("Already restored ranges cannot be counted twice")
    func rejectsDuplicateRestore() throws {
        let engine = WorkoutPauseRestoreEngine()
        let first = try engine.restore(
            session: session(),
            from: origin.addingTimeInterval(1200),
            to: origin.addingTimeInterval(1800)
        )
        #expect(throws: WorkoutPauseRestoreError.rangeNotPaused) {
            try engine.restore(
                session: first.updated,
                from: origin.addingTimeInterval(1200),
                to: origin.addingTimeInterval(1800)
            )
        }
    }

    @Test("Range spanning active and paused time is rejected")
    func rejectsOutsidePause() {
        #expect(throws: WorkoutPauseRestoreError.rangeNotPaused) {
            try WorkoutPauseRestoreEngine().restore(
                session: session(),
                from: origin.addingTimeInterval(1100),
                to: origin.addingTimeInterval(1300)
            )
        }
    }

    @Test("Zero-length and reversed ranges are rejected")
    func rejectsInvalidRange() {
        #expect(throws: WorkoutPauseRestoreError.invalidRange) {
            try WorkoutPauseRestoreEngine().restore(
                session: session(),
                from: origin.addingTimeInterval(1500),
                to: origin.addingTimeInterval(1500)
            )
        }
    }

    @Test("Restored health sample contributes to heart report")
    func reportReclassifiesRestoredSample() throws {
        let original = session()
        let before = WorkoutReportBuilder().makeReport(from: original)
        #expect(before.heart.sampleCount == 0)
        let restored = try WorkoutPauseRestoreEngine().restore(
            session: original,
            from: origin.addingTimeInterval(1200),
            to: origin.addingTimeInterval(1800)
        )
        let after = WorkoutReportBuilder().makeReport(from: restored.updated)
        #expect(after.heart.sampleCount == 1)
        #expect(after.heart.averageHeartRate == 130)
        let undone = WorkoutReportBuilder().makeReport(from: restored.undo())
        #expect(undone.heart.sampleCount == 0)
    }
}
