import Foundation
import WakTrainerCoreModels

/// Allocates additive HealthKit quantities to active time using sample intervals.
/// Assumes uniform accumulation within each sample; this is an estimate.
public struct WorkoutActiveQuantityAllocator: Sendable {
    private let pauses: [WorkoutPauseInterval]

    public init(pauseIntervals: [WorkoutPauseInterval]) {
        let valid = pauseIntervals.filter { $0.endDate > $0.startDate }
            .sorted { $0.startDate < $1.startDate }
        var merged: [WorkoutPauseInterval] = []
        for interval in valid {
            if let last = merged.last, interval.startDate <= last.endDate {
                merged[merged.count - 1] = WorkoutPauseInterval(
                    startDate: last.startDate,
                    endDate: max(last.endDate, interval.endDate)
                )
            } else {
                merged.append(interval)
            }
        }
        pauses = merged
    }

    /// Returns nil when no valid duration-bearing sample exists.
    /// Zero-duration quantities cannot be prorated reliably.
    public func activeTotal(
        for metric: WorkoutHealthMetric,
        in samples: [WorkoutHealthMetricSample]
    ) -> Double? {
        let relevant = samples.filter {
            $0.metric == metric &&
            $0.value.isFinite && $0.value >= 0 &&
            $0.endDate > $0.startDate
        }
        guard !relevant.isEmpty else { return nil }

        // Duplicate deliveries with the same HealthKit identity are harmless,
        // but conflicting payloads for that identity cannot be trusted.
        var byID: [UUID: WorkoutHealthMetricSample] = [:]
        for sample in relevant {
            if let previous = byID[sample.id], previous != sample {
                return nil
            }
            byID[sample.id] = sample
        }
        let unique = byID.values.sorted {
            if $0.startDate == $1.startDate {
                return $0.endDate < $1.endDate
            }
            return $0.startDate < $1.startDate
        }

        // Different IDs with overlapping collection windows may represent
        // duplicate sources. Do not silently double-count either source.
        // Adjacent intervals are safe; partial overlaps are not.
        var latestEnd: Date?
        for sample in unique {
            if let latestEnd, sample.startDate < latestEnd {
                return nil
            }
            latestEnd = sample.endDate
        }

        return unique.reduce(0.0) { total, sample in
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            let paused = pauses.reduce(0.0) { accumulated, pause in
                let start = max(sample.startDate, pause.startDate)
                let end = min(sample.endDate, pause.endDate)
                return accumulated + max(0, end.timeIntervalSince(start))
            }
            let activeFraction = max(0, min(1, (duration - paused) / duration))
            return total + sample.value * activeFraction
        }
    }

    /// Only use HealthKit distance when a single distance type is present.
    /// Different types may describe the same movement and must not be summed.
    public func unambiguousActiveDistance(
        in samples: [WorkoutHealthMetricSample]
    ) -> Double? {
        let types: [WorkoutHealthMetric] = [
            .distanceWalkingRunning, .distanceCycling, .distanceSwimming
        ]
        let present = types.compactMap { metric -> Double? in
            activeTotal(for: metric, in: samples)
        }
        guard present.count == 1 else { return nil }
        return present[0]
    }
}
