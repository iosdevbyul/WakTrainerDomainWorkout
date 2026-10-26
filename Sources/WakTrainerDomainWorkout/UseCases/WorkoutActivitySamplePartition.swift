import Foundation
import WakTrainerCoreModels

/// Selects report-eligible samples without modifying the original workout.
public struct WorkoutActivitySamplePartition: Sendable {
    private let pauses: [WorkoutPauseInterval]

    public init(pauseIntervals: [WorkoutPauseInterval]) {
        self.pauses = pauseIntervals
            .filter { $0.endDate > $0.startDate }
            .sorted { $0.startDate < $1.startDate }
    }

    /// A pause includes its start and excludes its end.
    public func isPaused(at date: Date) -> Bool {
        pauses.contains { date >= $0.startDate && date < $0.endDate }
    }

    public func pausedRoutePoints(
        from route: [WorkoutRoutePoint]
    ) -> [WorkoutRoutePoint] {
        route.filter { isPaused(at: $0.timestamp) }
    }

    /// Active GPS points are kept in separate segments so route calculations
    /// never draw an artificial line across a paused interval.
    public func activeRouteSegments(
        from route: [WorkoutRoutePoint]
    ) -> [[WorkoutRoutePoint]] {
        let sorted = route.sorted { $0.timestamp < $1.timestamp }
        var segments: [[WorkoutRoutePoint]] = []
        var current: [WorkoutRoutePoint] = []

        for point in sorted {
            if isPaused(at: point.timestamp) {
                if !current.isEmpty {
                    segments.append(current)
                    current = []
                }
                continue
            }

            if let previous = current.last,
               pauses.contains(where: {
                   $0.startDate < point.timestamp &&
                   $0.endDate > previous.timestamp
               }) {
                segments.append(current)
                current = []
            }
            current.append(point)
        }

        if !current.isEmpty {
            segments.append(current)
        }
        return segments
    }

    /// A measurement overlapping a pause is excluded from active reporting.
    /// Interval-spanning quantities require explicit prorating in a later step.
    public func isPaused(
        sample: WorkoutHealthMetricSample
    ) -> Bool {
        if sample.endDate <= sample.startDate {
            return isPaused(at: sample.endDate)
        }
        return pauses.contains {
            sample.startDate < $0.endDate &&
            sample.endDate > $0.startDate
        }
    }

    public func activeHealthSamples(
        from samples: [WorkoutHealthMetricSample]
    ) -> [WorkoutHealthMetricSample] {
        samples.filter { !isPaused(sample: $0) }
    }

    public func pausedHealthSamples(
        from samples: [WorkoutHealthMetricSample]
    ) -> [WorkoutHealthMetricSample] {
        samples.filter { isPaused(sample: $0) }
    }
}
