import Foundation
import Testing
import WakTrainerCoreModels

@testable import WakTrainerDomainWorkout

@Suite("Workout active and paused sample partition")
struct WorkoutActivitySamplePartitionTests {
    private let origin = Date(timeIntervalSince1970: 1_800_000_000)

    private func point(_ seconds: TimeInterval) -> WorkoutRoutePoint {
        WorkoutRoutePoint(
            timestamp: origin.addingTimeInterval(seconds),
            latitude: 37.0 + seconds / 100_000,
            longitude: 127.0,
            altitude: 10
        )
    }

    private func sample(
        _ start: TimeInterval,
        _ end: TimeInterval
    ) -> WorkoutHealthMetricSample {
        WorkoutHealthMetricSample(
            metric: .heartRate,
            startDate: origin.addingTimeInterval(start),
            endDate: origin.addingTimeInterval(end),
            value: 130,
            unit: "bpm"
        )
    }

    @Test("Paused GPS stays in raw history but is excluded from active segments")
    func pausedRouteIsSeparated() {
        let raw = [point(0), point(10), point(20), point(30), point(40), point(50)]
        let selector = WorkoutActivitySamplePartition(pauseIntervals: [
            WorkoutPauseInterval(
                startDate: origin.addingTimeInterval(15),
                endDate: origin.addingTimeInterval(35)
            )
        ])

        let active = selector.activeRouteSegments(from: raw)
        #expect(active.map { $0.map(\.timestamp) } == [
            [raw[0].timestamp, raw[1].timestamp],
            [raw[4].timestamp, raw[5].timestamp]
        ])
        #expect(selector.pausedRoutePoints(from: raw) == [raw[2], raw[3]])
        #expect(raw.count == 6)
    }

    @Test("Pause gap breaks GPS segments even with no point inside it")
    func pauseGapNeverCreatesArtificialRouteEdge() {
        let raw = [point(0), point(10), point(40), point(50)]
        let selector = WorkoutActivitySamplePartition(pauseIntervals: [
            WorkoutPauseInterval(
                startDate: origin.addingTimeInterval(15),
                endDate: origin.addingTimeInterval(35)
            )
        ])
        #expect(selector.activeRouteSegments(from: raw).map(\.count) == [2, 2])
        #expect(selector.pausedRoutePoints(from: raw).isEmpty)
    }

    @Test("Health sample overlap is conservative and boundaries are half open")
    func healthSampleBoundaries() {
        let selector = WorkoutActivitySamplePartition(pauseIntervals: [
            WorkoutPauseInterval(
                startDate: origin.addingTimeInterval(15),
                endDate: origin.addingTimeInterval(35)
            )
        ])
        let samples = [
            sample(0, 15),
            sample(10, 20),
            sample(20, 30),
            sample(35, 40),
            sample(35, 35)
        ]
        #expect(selector.activeHealthSamples(from: samples) == [
            samples[0], samples[3], samples[4]
        ])
        #expect(selector.pausedHealthSamples(from: samples) == [
            samples[1], samples[2]
        ])
        #expect(selector.isPaused(at: origin.addingTimeInterval(15)))
        #expect(!selector.isPaused(at: origin.addingTimeInterval(35)))
    }

    @Test("No pauses preserves all samples in one segment")
    func noPausesPreservesSamples() {
        let raw = [point(0), point(10), point(20)]
        let selector = WorkoutActivitySamplePartition(pauseIntervals: [])
        #expect(selector.activeRouteSegments(from: raw) == [raw])
        #expect(selector.pausedRoutePoints(from: raw).isEmpty)
        let health = sample(0, 10)
        #expect(selector.activeHealthSamples(from: [health]) == [health])
    }

    @Test("Invalid pause windows are ignored")
    func invalidPauseIsIgnored() {
        let selector = WorkoutActivitySamplePartition(pauseIntervals: [
            WorkoutPauseInterval(
                startDate: origin.addingTimeInterval(35),
                endDate: origin.addingTimeInterval(15)
            )
        ])
        #expect(selector.activeRouteSegments(from: [point(0), point(50)]).count == 1)
    }
}
