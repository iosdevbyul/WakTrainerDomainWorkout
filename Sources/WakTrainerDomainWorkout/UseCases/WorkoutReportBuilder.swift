import Foundation
import WakTrainerCoreModels

public struct WorkoutReportBuilder: Sendable {

    private let maximumHeartRate: Double?

    public init(
        maximumHeartRate: Double? = nil
    ) {
        if let maximumHeartRate,
           maximumHeartRate > 0 {
            self.maximumHeartRate = maximumHeartRate
        } else {
            self.maximumHeartRate = nil
        }
    }

    public func makeReport(
        from session: WorkoutSession
    ) -> WorkoutReport {
        let summary = makeSummary(
            from: session
        )

        let heart = makeHeartReport(
            from: session
        )

        let strength = makeStrengthReport(
            from: session
        )

        let cardio = makeCardioReport(
            from: session
        )

        return WorkoutReport(
            sessionID: session.id,
            workout: session.workout,
            summary: summary,
            heart: heart,
            strength: strength,
            cardio: cardio
        )
    }
}

private extension WorkoutReportBuilder {

    func makeSummary(
        from session: WorkoutSession
    ) -> WorkoutReportSummary {
        let health = session.health.summary

        return WorkoutReportSummary(
            elapsedDuration:
                session.timing.elapsedDuration,
            activeDuration:
                session.timing.activeDuration,
            pausedDuration:
                session.timing.pausedDuration,
            activeCalories:
                health.activeCalories,
            stepCount:
                health.stepCount,
            distanceMeters:
                health.distanceMeters,
            averageHeartRate:
                health.averageHeartRate,
            minimumHeartRate:
                health.minimumHeartRate,
            maximumHeartRate:
                health.maximumHeartRate
        )
    }

    func makeHeartReport(
        from session: WorkoutSession
    ) -> WorkoutHeartReport {
        let heartRateSamples = session.health.samples(
            for: .heartRate
        )

        return WorkoutHeartReport(
            averageHeartRate:
                session.health.summary.averageHeartRate,
            minimumHeartRate:
                session.health.summary.minimumHeartRate,
            maximumHeartRate:
                session.health.summary.maximumHeartRate,
            sampleCount:
                heartRateSamples.count,
            zones:
                makeHeartRateZones(
                    from: heartRateSamples
                )
        )
    }

    func makeHeartRateZones(
        from samples: [WorkoutHealthMetricSample]
    ) -> [WorkoutHeartRateZone] {
        guard let maximumHeartRate,
              !samples.isEmpty else {
            return []
        }

        let boundaries = [
            maximumHeartRate * 0.60,
            maximumHeartRate * 0.70,
            maximumHeartRate * 0.80,
            maximumHeartRate * 0.90
        ]

        var counts = Array(
            repeating: 0,
            count: WorkoutHeartRateZoneLevel.allCases.count
        )

        for sample in samples {
            switch sample.value {
            case ..<boundaries[0]:
                counts[0] += 1
            case ..<boundaries[1]:
                counts[1] += 1
            case ..<boundaries[2]:
                counts[2] += 1
            case ..<boundaries[3]:
                counts[3] += 1
            default:
                counts[4] += 1
            }
        }

        let total = Double(samples.count)

        return WorkoutHeartRateZoneLevel.allCases.map {
            level in

            let index = level.rawValue - 1

            let lowerBound: Double
            let upperBound: Double?

            switch level {
            case .zone1:
                lowerBound = 0
                upperBound = boundaries[0]
            case .zone2:
                lowerBound = boundaries[0]
                upperBound = boundaries[1]
            case .zone3:
                lowerBound = boundaries[1]
                upperBound = boundaries[2]
            case .zone4:
                lowerBound = boundaries[2]
                upperBound = boundaries[3]
            case .zone5:
                lowerBound = boundaries[3]
                upperBound = nil
            }

            return WorkoutHeartRateZone(
                level: level,
                lowerBoundBPM: lowerBound,
                upperBoundBPM: upperBound,
                sampleCount: counts[index],
                samplePercentage:
                    Double(counts[index]) / total * 100
            )
        }
    }

    func makeStrengthReport(
        from session: WorkoutSession
    ) -> WorkoutStrengthReport? {
        let completedSets = session.exerciseRecords
            .flatMap(\.strengthSets)
            .filter(\.isCompleted)

        guard !completedSets.isEmpty else {
            return nil
        }

        let workingSets = completedSets.filter {
            !$0.isWarmup
        }

        let performanceSets = workingSets.isEmpty
            ? completedSets
            : workingSets

        let restDurations = completedSets.compactMap(
            \.restDuration
        )

        let totalVolume = performanceSets.reduce(0.0) {
            partialResult,
            set in

            partialResult + (set.volumeKilograms ?? 0)
        }

        let totalRepetitions = performanceSets.reduce(0) {
            partialResult,
            set in

            partialResult + (set.repetitions ?? 0)
        }

        let bestEstimatedOneRepMax = performanceSets
            .compactMap { set -> Double? in
                guard let weight = set.weightKilograms,
                      let repetitions = set.repetitions,
                      weight > 0,
                      repetitions > 0 else {
                    return nil
                }

                return estimatedOneRepMax(
                    weightKilograms: weight,
                    repetitions: repetitions
                )
            }
            .max()

        let activeMinutes =
            session.timing.activeDuration / 60

        let volumePerActiveMinute: Double?

        if activeMinutes > 0 {
            volumePerActiveMinute =
                totalVolume / activeMinutes
        } else {
            volumePerActiveMinute = nil
        }

        return WorkoutStrengthReport(
            totalSets:
                completedSets.count,
            workingSets:
                workingSets.count,
            warmupSets:
                completedSets.filter(\.isWarmup).count,
            totalRepetitions:
                totalRepetitions,
            totalVolumeKilograms:
                totalVolume,
            maximumWeightKilograms:
                performanceSets
                    .compactMap(\.weightKilograms)
                    .max(),
            bestEstimatedOneRepMaxKilograms:
                bestEstimatedOneRepMax,
            averageRestDuration:
                average(restDurations),
            volumePerActiveMinute:
                volumePerActiveMinute
        )
    }

    func makeCardioReport(
        from session: WorkoutSession
    ) -> WorkoutCardioReport? {
        let isCardio =
            session.workout.category == "cardio" ||
            session.exerciseRecords.contains {
                $0.kind == .cardio
            }

        guard isCardio else {
            return nil
        }

        let health = session.health.summary
        let distance = health.distanceMeters

        let averagePace: TimeInterval?

        if let distance,
           distance > 0,
           session.timing.activeDuration > 0 {
            averagePace =
                session.timing.activeDuration /
                (distance / 1_000)
        } else {
            averagePace = nil
        }

        return WorkoutCardioReport(
            distanceMeters:
                distance,
            averageSpeedMetersPerSecond:
                health.averageSpeedMetersPerSecond,
            maximumSpeedMetersPerSecond:
                health.maximumSpeedMetersPerSecond,
            averagePaceSecondsPerKilometer:
                averagePace,
            averageCadence:
                health.averageCadence,
            averagePowerWatts:
                health.averagePowerWatts,
            elevationGainMeters:
                health.elevationGainMeters ??
                elevationGain(
                    from: session.route
                ),
            routePointCount:
                session.route.count
        )
    }

    func estimatedOneRepMax(
        weightKilograms: Double,
        repetitions: Int
    ) -> Double {
        weightKilograms *
        (1 + Double(repetitions) / 30)
    }

    func average(
        _ values: [Double]
    ) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) /
        Double(values.count)
    }

    func elevationGain(
        from route: [WorkoutRoutePoint]
    ) -> Double? {
        guard route.count >= 2 else {
            return nil
        }

        var gain: Double = 0
        var hasValidPair = false

        for index in 1..<route.count {
            let previous = route[index - 1]
            let current = route[index]

            guard let previousAltitude =
                    previous.altitude,
                  let currentAltitude =
                    current.altitude,
                  isUsableAltitude(
                    previous
                  ),
                  isUsableAltitude(
                    current
                  ) else {
                continue
            }

            hasValidPair = true

            let delta =
                currentAltitude -
                previousAltitude

            if delta > 0 {
                gain += delta
            }
        }

        return hasValidPair
            ? gain
            : nil
    }

    func isUsableAltitude(
        _ point: WorkoutRoutePoint
    ) -> Bool {
        guard let accuracy =
                point.verticalAccuracy else {
            return true
        }

        return accuracy >= 0 &&
        accuracy <= 20
    }
}
