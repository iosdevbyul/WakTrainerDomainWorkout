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
        let routeDistance = activeRouteDistance(
            from: session
        )

        let heart = activeHeartRateStatistics(from: session)
        let hasPauses = !session.timing.pauseIntervals.isEmpty
        let quantities = WorkoutActiveQuantityAllocator(
            pauseIntervals: session.timing.pauseIntervals
        )
        let activeCalories = hasPauses
            ? verifiedQuantity(.activeEnergyBurned, session: session, allocator: quantities)
            : health.activeCalories
        let activeSteps = hasPauses
            ? verifiedQuantity(.stepCount, session: session, allocator: quantities)
            : health.stepCount
        let activeDistance = hasPauses
            ? (verifiedDistance(session: session, allocator: quantities) ?? routeDistance)
            : (health.distanceMeters ?? routeDistance)

        return WorkoutReportSummary(
            elapsedDuration:
                session.timing.elapsedDuration,
            activeDuration:
                session.timing.activeDuration,
            pausedDuration:
                session.timing.pausedDuration,
            activeCalories:
                activeCalories,
            stepCount:
                activeSteps,
            distanceMeters:
                activeDistance,
            averageHeartRate:
                hasPauses ? heart?.average : health.averageHeartRate,
            minimumHeartRate:
                hasPauses ? heart?.minimum : health.minimumHeartRate,
            maximumHeartRate:
                hasPauses ? heart?.maximum : health.maximumHeartRate
        )
    }

    func verifiedQuantity(
        _ metric: WorkoutHealthMetric,
        session: WorkoutSession,
        allocator: WorkoutActiveQuantityAllocator
    ) -> Double? {
        guard let endDate = session.timing.endDate else { return nil }
        return allocator.verifiedActiveTotal(
            for: metric,
            in: session.health.samples,
            workoutStart: session.timing.startDate,
            workoutEnd: endDate
        )
    }

    func verifiedDistance(
        session: WorkoutSession,
        allocator: WorkoutActiveQuantityAllocator
    ) -> Double? {
        guard let endDate = session.timing.endDate else { return nil }
        return allocator.verifiedActiveDistance(
            in: session.health.samples,
            workoutStart: session.timing.startDate,
            workoutEnd: endDate
        )
    }

    func activeHeartRateSamples(
        from session: WorkoutSession
    ) -> [WorkoutHealthMetricSample] {
        let raw = session.health.samples(for: .heartRate)
        guard !session.timing.pauseIntervals.isEmpty else {
            return raw
        }
        return WorkoutActivitySamplePartition(
            pauseIntervals: session.timing.pauseIntervals
        ).activeHealthSamples(from: raw)
    }

    func activeHeartRateStatistics(
        from session: WorkoutSession
    ) -> (average: Double, minimum: Double, maximum: Double)? {
        let values = activeHeartRateSamples(from: session)
            .map(\.value)
            .filter { $0.isFinite && $0 > 0 }
        guard !values.isEmpty else { return nil }
        return (
            average: values.reduce(0, +) / Double(values.count),
            minimum: values.min()!,
            maximum: values.max()!
        )
    }

    func makeHeartReport(
        from session: WorkoutSession
    ) -> WorkoutHeartReport {
        let samples = activeHeartRateSamples(from: session)
        let hasPauses = !session.timing.pauseIntervals.isEmpty
        let statistics = hasPauses
            ? activeHeartRateStatistics(from: session)
            : nil

        return WorkoutHeartReport(
            averageHeartRate:
                hasPauses ? statistics?.average : session.health.summary.averageHeartRate,
            minimumHeartRate:
                hasPauses ? statistics?.minimum : session.health.summary.minimumHeartRate,
            maximumHeartRate:
                hasPauses ? statistics?.maximum : session.health.summary.maximumHeartRate,
            sampleCount: samples.count,
            zones: makeHeartRateZones(from: samples, session: session)
        )
    }

    func makeHeartRateZones(
        from samples: [WorkoutHealthMetricSample],
        session: WorkoutSession
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

        // A reading represents the interval until the next reading, limited
        // to 15 seconds to avoid inventing time during data collection gaps.
        // Paused intervals and time outside the session are excluded.
        let ordered = samples.filter { $0.value.isFinite && $0.value > 0 }
            .sorted { $0.startDate < $1.startDate }
        var durations = Array(repeating: 0.0, count: 5)
        let workoutEnd = session.timing.endDate ?? Date.distantPast
        let pauses = session.timing.pauseIntervals
        for index in ordered.indices {
            let sample = ordered[index]
            let start = max(sample.startDate, session.timing.startDate)
            let nextStart = index + 1 < ordered.count
                ? ordered[index + 1].startDate : sample.endDate
            let end = min(workoutEnd, nextStart, sample.startDate.addingTimeInterval(15))
            guard end > start else { continue }
            let overlaps = pauses.reduce(0.0) { total, pause in
                total + max(0, min(end, pause.endDate).timeIntervalSince(max(start, pause.startDate)))
            }
            let elapsed = max(0, end.timeIntervalSince(start) - overlaps)
            let zoneIndex: Int
            switch sample.value {
            case ..<boundaries[0]: zoneIndex = 0
            case ..<boundaries[1]: zoneIndex = 1
            case ..<boundaries[2]: zoneIndex = 2
            case ..<boundaries[3]: zoneIndex = 3
            default: zoneIndex = 4
            }
            durations[zoneIndex] += elapsed
        }
        let measuredDuration = durations.reduce(0, +)
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
                    Double(counts[index]) / total * 100,
                activeDuration: durations[index],
                activeDurationPercentage: measuredDuration > 0 ? durations[index] / measuredDuration * 100 : 0
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
        let routeDistance = activeRouteDistance(
            from: session
        )

        let quantities = WorkoutActiveQuantityAllocator(
            pauseIntervals: session.timing.pauseIntervals
        )
        let distance = session.timing.pauseIntervals.isEmpty
            ? (health.distanceMeters ?? routeDistance)
            : (verifiedDistance(session: session, allocator: quantities) ?? routeDistance)

        let averagePace: TimeInterval?

        // Near-zero GPS drift is not usable distance for a pace estimate.
        // Reject a pace above 60 min/km as non-representative rather than
        // displaying enormous values for an effectively stationary session.
        if let distance,
           distance.isFinite,
           distance >= 10,
           session.timing.activeDuration > 0 {
            let pace = session.timing.activeDuration / (distance / 1_000)
            averagePace = pace.isFinite && pace <= 3_600 ? pace : nil
        } else {
            averagePace = nil
        }

        let routeAverageSpeed: Double?

        if let routeDistance,
           routeDistance > 0,
           session.timing.activeDuration > 0 {
            routeAverageSpeed =
                routeDistance /
                session.timing.activeDuration
        } else {
            routeAverageSpeed = nil
        }

        return WorkoutCardioReport(
            distanceMeters:
                distance,
            routeDistanceMeters:
                routeDistance,
            averageSpeedMetersPerSecond:
                health.averageSpeedMetersPerSecond ??
                routeAverageSpeed,
            maximumSpeedMetersPerSecond:
                health.maximumSpeedMetersPerSecond ??
                activeRouteSegments(from: session)
                    .compactMap { maximumRouteSpeed(from: $0) }
                    .max(),
            averagePaceSecondsPerKilometer:
                averagePace,
            averageCadence:
                health.averageCadence,
            averagePowerWatts:
                health.averagePowerWatts,
            elevationGainMeters:
                health.elevationGainMeters ??
                activeElevationGain(from: session),
            routePointCount:
                activeRouteSegments(from: session)
                    .reduce(0) { $0 + $1.count },
            splits:
                activeCardioSplits(from: session)
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

    func activeRouteSegments(
        from session: WorkoutSession
    ) -> [[WorkoutRoutePoint]] {
        WorkoutActivitySamplePartition(
            pauseIntervals: session.timing.pauseIntervals
        ).activeRouteSegments(from: session.route)
    }

    func activeElevationGain(
        from session: WorkoutSession
    ) -> Double? {
        let gains = activeRouteSegments(from: session)
            .compactMap { elevationGain(from: $0) }
        guard !gains.isEmpty else { return nil }
        return gains.reduce(0, +)
    }

    func activeCardioSplits(
        from session: WorkoutSession
    ) -> [WorkoutCardioSplit] {
        let splits = activeRouteSegments(from: session)
            .flatMap { cardioSplits(from: $0) }
        return splits.enumerated().map { offset, split in
            WorkoutCardioSplit(
                index: offset + 1,
                distanceMeters: split.distanceMeters,
                duration: split.duration,
                paceSecondsPerKilometer: split.paceSecondsPerKilometer
            )
        }
    }

    func activeRouteDistance(
        from session: WorkoutSession
    ) -> Double? {
        let distances = activeRouteSegments(from: session)
            .compactMap { routeDistance(from: $0) }
        guard !distances.isEmpty else { return nil }
        return distances.reduce(0, +)
    }

    func routeDistance(
        from route: [WorkoutRoutePoint]
    ) -> Double? {
        let points = usableRoutePoints(
            from: route
        )

        guard points.count >= 2 else {
            return nil
        }

        var totalDistance: Double = 0

        for index in 1..<points.count {
            totalDistance += haversineDistance(
                from: points[index - 1],
                to: points[index]
            )
        }

        return totalDistance > 0
            ? totalDistance
            : nil
    }

    func maximumRouteSpeed(
        from route: [WorkoutRoutePoint]
    ) -> Double? {
        route
            .compactMap(\.speedMetersPerSecond)
            .filter { $0 >= 0 }
            .max()
    }

    func cardioSplits(
        from route: [WorkoutRoutePoint]
    ) -> [WorkoutCardioSplit] {
        let points = usableRoutePoints(
            from: route
        )

        guard points.count >= 2 else {
            return []
        }

        let splitTargetMeters = 1_000.0
        let minimumPartialSplitMeters = 100.0

        var result: [WorkoutCardioSplit] = []
        var splitIndex = 1
        var accumulatedDistance: Double = 0
        var accumulatedDuration: TimeInterval = 0

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]

            let segmentDistance = haversineDistance(
                from: previous,
                to: current
            )

            let segmentDuration =
                current.timestamp
                    .timeIntervalSince(
                        previous.timestamp
                    )

            guard segmentDistance > 0,
                  segmentDuration > 0 else {
                continue
            }

            var remainingDistance = segmentDistance
            var remainingDuration = segmentDuration

            while remainingDistance > 0 {
                let distanceNeeded =
                    splitTargetMeters -
                    accumulatedDistance

                if remainingDistance >= distanceNeeded {
                    let ratio =
                        distanceNeeded /
                        remainingDistance

                    let usedDuration =
                        remainingDuration *
                        ratio

                    accumulatedDistance +=
                        distanceNeeded
                    accumulatedDuration +=
                        usedDuration

                    result.append(
                        WorkoutCardioSplit(
                            index: splitIndex,
                            distanceMeters:
                                accumulatedDistance,
                            duration:
                                accumulatedDuration,
                            paceSecondsPerKilometer:
                                accumulatedDuration
                        )
                    )

                    splitIndex += 1
                    remainingDistance -=
                        distanceNeeded
                    remainingDuration -=
                        usedDuration
                    accumulatedDistance = 0
                    accumulatedDuration = 0
                } else {
                    accumulatedDistance +=
                        remainingDistance
                    accumulatedDuration +=
                        remainingDuration
                    remainingDistance = 0
                    remainingDuration = 0
                }
            }
        }

        if accumulatedDistance >=
            minimumPartialSplitMeters,
           accumulatedDuration > 0 {
            result.append(
                WorkoutCardioSplit(
                    index: splitIndex,
                    distanceMeters:
                        accumulatedDistance,
                    duration:
                        accumulatedDuration,
                    paceSecondsPerKilometer:
                        accumulatedDuration /
                        (accumulatedDistance / 1_000)
                )
            )
        }

        return result
    }

    func usableRoutePoints(
        from route: [WorkoutRoutePoint]
    ) -> [WorkoutRoutePoint] {
        route
            .filter(isUsableHorizontalLocation)
            .sorted {
                $0.timestamp < $1.timestamp
            }
    }

    func isUsableHorizontalLocation(
        _ point: WorkoutRoutePoint
    ) -> Bool {
        guard let accuracy =
                point.horizontalAccuracy else {
            return true
        }

        return accuracy >= 0 &&
        accuracy <= 50
    }

    func haversineDistance(
        from start: WorkoutRoutePoint,
        to end: WorkoutRoutePoint
    ) -> Double {
        let earthRadiusMeters = 6_371_000.0

        let startLatitude =
            start.latitude * .pi / 180
        let endLatitude =
            end.latitude * .pi / 180

        let latitudeDelta =
            (end.latitude - start.latitude) *
            .pi / 180

        let longitudeDelta =
            (end.longitude - start.longitude) *
            .pi / 180

        let a =
            sin(latitudeDelta / 2) *
            sin(latitudeDelta / 2) +
            cos(startLatitude) *
            cos(endLatitude) *
            sin(longitudeDelta / 2) *
            sin(longitudeDelta / 2)

        let c = 2 * atan2(
            sqrt(a),
            sqrt(1 - a)
        )

        return earthRadiusMeters * c
    }
}
