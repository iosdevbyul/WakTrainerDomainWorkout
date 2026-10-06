import Foundation
import WakTrainerCoreModels

public struct WorkoutReport: Equatable, Sendable {
    public let sessionID: UUID
    public let workout: WorkoutIdentity
    public let summary: WorkoutReportSummary
    public let heart: WorkoutHeartReport
    public let strength: WorkoutStrengthReport?
    public let cardio: WorkoutCardioReport?

    public init(
        sessionID: UUID,
        workout: WorkoutIdentity,
        summary: WorkoutReportSummary,
        heart: WorkoutHeartReport,
        strength: WorkoutStrengthReport? = nil,
        cardio: WorkoutCardioReport? = nil
    ) {
        self.sessionID = sessionID
        self.workout = workout
        self.summary = summary
        self.heart = heart
        self.strength = strength
        self.cardio = cardio
    }
}

public struct WorkoutReportSummary: Equatable, Sendable {
    public let elapsedDuration: TimeInterval
    public let activeDuration: TimeInterval
    public let pausedDuration: TimeInterval
    public let activeCalories: Double?
    public let stepCount: Double?
    public let distanceMeters: Double?
    public let averageHeartRate: Double?
    public let minimumHeartRate: Double?
    public let maximumHeartRate: Double?

    public init(
        elapsedDuration: TimeInterval,
        activeDuration: TimeInterval,
        pausedDuration: TimeInterval,
        activeCalories: Double?,
        stepCount: Double?,
        distanceMeters: Double?,
        averageHeartRate: Double?,
        minimumHeartRate: Double?,
        maximumHeartRate: Double?
    ) {
        self.elapsedDuration = elapsedDuration
        self.activeDuration = activeDuration
        self.pausedDuration = pausedDuration
        self.activeCalories = activeCalories
        self.stepCount = stepCount
        self.distanceMeters = distanceMeters
        self.averageHeartRate = averageHeartRate
        self.minimumHeartRate = minimumHeartRate
        self.maximumHeartRate = maximumHeartRate
    }
}

public struct WorkoutHeartReport: Equatable, Sendable {
    public let averageHeartRate: Double?
    public let minimumHeartRate: Double?
    public let maximumHeartRate: Double?
    public let sampleCount: Int
    public let zones: [WorkoutHeartRateZone]

    public init(
        averageHeartRate: Double?,
        minimumHeartRate: Double?,
        maximumHeartRate: Double?,
        sampleCount: Int,
        zones: [WorkoutHeartRateZone] = []
    ) {
        self.averageHeartRate = averageHeartRate
        self.minimumHeartRate = minimumHeartRate
        self.maximumHeartRate = maximumHeartRate
        self.sampleCount = sampleCount
        self.zones = zones
    }
}

public enum WorkoutHeartRateZoneLevel: Int, CaseIterable, Equatable, Sendable {
    case zone1 = 1
    case zone2
    case zone3
    case zone4
    case zone5
}

public struct WorkoutHeartRateZone: Equatable, Sendable {
    public let level: WorkoutHeartRateZoneLevel
    public let lowerBoundBPM: Double
    public let upperBoundBPM: Double?
    public let sampleCount: Int
    public let samplePercentage: Double

    public init(
        level: WorkoutHeartRateZoneLevel,
        lowerBoundBPM: Double,
        upperBoundBPM: Double?,
        sampleCount: Int,
        samplePercentage: Double
    ) {
        self.level = level
        self.lowerBoundBPM = lowerBoundBPM
        self.upperBoundBPM = upperBoundBPM
        self.sampleCount = sampleCount
        self.samplePercentage = samplePercentage
    }
}

public struct WorkoutStrengthReport: Equatable, Sendable {
    public let totalSets: Int
    public let workingSets: Int
    public let warmupSets: Int
    public let totalRepetitions: Int
    public let totalVolumeKilograms: Double
    public let maximumWeightKilograms: Double?
    public let bestEstimatedOneRepMaxKilograms: Double?
    public let averageRestDuration: TimeInterval?
    public let volumePerActiveMinute: Double?

    public init(
        totalSets: Int,
        workingSets: Int,
        warmupSets: Int,
        totalRepetitions: Int,
        totalVolumeKilograms: Double,
        maximumWeightKilograms: Double?,
        bestEstimatedOneRepMaxKilograms: Double?,
        averageRestDuration: TimeInterval?,
        volumePerActiveMinute: Double?
    ) {
        self.totalSets = totalSets
        self.workingSets = workingSets
        self.warmupSets = warmupSets
        self.totalRepetitions = totalRepetitions
        self.totalVolumeKilograms = totalVolumeKilograms
        self.maximumWeightKilograms = maximumWeightKilograms
        self.bestEstimatedOneRepMaxKilograms = bestEstimatedOneRepMaxKilograms
        self.averageRestDuration = averageRestDuration
        self.volumePerActiveMinute = volumePerActiveMinute
    }
}

public struct WorkoutCardioReport: Equatable, Sendable {
    public let distanceMeters: Double?
    public let averageSpeedMetersPerSecond: Double?
    public let maximumSpeedMetersPerSecond: Double?
    public let averagePaceSecondsPerKilometer: TimeInterval?
    public let averageCadence: Double?
    public let averagePowerWatts: Double?
    public let elevationGainMeters: Double?
    public let routePointCount: Int

    public init(
        distanceMeters: Double?,
        averageSpeedMetersPerSecond: Double?,
        maximumSpeedMetersPerSecond: Double?,
        averagePaceSecondsPerKilometer: TimeInterval?,
        averageCadence: Double?,
        averagePowerWatts: Double?,
        elevationGainMeters: Double?,
        routePointCount: Int
    ) {
        self.distanceMeters = distanceMeters
        self.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond
        self.maximumSpeedMetersPerSecond = maximumSpeedMetersPerSecond
        self.averagePaceSecondsPerKilometer = averagePaceSecondsPerKilometer
        self.averageCadence = averageCadence
        self.averagePowerWatts = averagePowerWatts
        self.elevationGainMeters = elevationGainMeters
        self.routePointCount = routePointCount
    }
}
