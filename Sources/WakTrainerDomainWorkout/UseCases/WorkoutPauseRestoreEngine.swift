import Foundation
import WakTrainerCoreModels

public enum WorkoutPauseRestoreError: Error, Equatable, Sendable {
    case unfinishedWorkout
    case invalidRange
    case outsideWorkout
    case rangeNotPaused
    case inconsistentTiming
}

/// Pure, deterministic partial restore of a previously paused workout window.
/// The original session is returned for an explicit undo; callers must persist
/// the returned updated session atomically with any undo state they need.
public struct WorkoutPauseRestoreEngine: Sendable {
    public init() {}

    public func restore(
        session: WorkoutSession,
        from start: Date,
        to end: Date
    ) throws -> WorkoutPauseRestoreResult {
        guard let workoutEnd = session.timing.endDate else {
            throw WorkoutPauseRestoreError.unfinishedWorkout
        }
        guard end > start else {
            throw WorkoutPauseRestoreError.invalidRange
        }
        guard start >= session.timing.startDate, end <= workoutEnd else {
            throw WorkoutPauseRestoreError.outsideWorkout
        }
        guard session.timing.activeDuration.isFinite,
              session.timing.pausedDuration.isFinite,
              session.timing.activeDuration >= 0,
              session.timing.pausedDuration >= 0 else {
            throw WorkoutPauseRestoreError.inconsistentTiming
        }

        // Restore must be wholly inside one remaining paused window. This
        // prevents counting an already-restored interval a second time.
        let matching = session.timing.pauseIntervals.filter {
            $0.startDate <= start && end <= $0.endDate &&
            $0.startDate < $0.endDate
        }
        guard matching.count == 1 else {
            throw WorkoutPauseRestoreError.rangeNotPaused
        }
        let duration = end.timeIntervalSince(start)
        guard session.timing.pausedDuration >= duration else {
            throw WorkoutPauseRestoreError.inconsistentTiming
        }

        var updated = session
        let target = matching[0]
        var remaining: [WorkoutPauseInterval] = []
        var removed = false
        for interval in session.timing.pauseIntervals {
            if !removed && interval == target {
                removed = true
                if interval.startDate < start {
                    remaining.append(WorkoutPauseInterval(
                        startDate: interval.startDate,
                        endDate: start
                    ))
                }
                if end < interval.endDate {
                    remaining.append(WorkoutPauseInterval(
                        startDate: end,
                        endDate: interval.endDate
                    ))
                }
            } else {
                remaining.append(interval)
            }
        }
        updated.timing.pauseIntervals = remaining
            .sorted { $0.startDate < $1.startDate }
        updated.timing.activeDuration += duration
        updated.timing.pausedDuration -= duration

        return WorkoutPauseRestoreResult(
            original: session,
            updated: updated,
            restoredDuration: duration
        )
    }
}

public struct WorkoutPauseRestoreResult: Sendable {
    public let original: WorkoutSession
    public let updated: WorkoutSession
    public let restoredDuration: TimeInterval

    public init(
        original: WorkoutSession,
        updated: WorkoutSession,
        restoredDuration: TimeInterval
    ) {
        self.original = original
        self.updated = updated
        self.restoredDuration = restoredDuration
    }

    /// Undo is valid for the exact update returned by this operation.
    /// Persistence and concurrent-edit conflict detection belong to callers.
    public func undo() -> WorkoutSession {
        original
    }
}
