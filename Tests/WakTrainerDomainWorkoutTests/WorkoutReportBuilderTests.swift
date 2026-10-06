import Foundation
import Testing
import WakTrainerCoreModels

@testable import WakTrainerDomainWorkout

@Suite("WorkoutReportBuilder")
struct WorkoutReportBuilderTests {

    @Test("근력 리포트는 워밍업을 분리하고 작업 세트 성과를 계산한다")
    func strengthReportCalculatesWorkingSetPerformance() throws {
        let start = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "bench_press",
                name: "벤치프레스",
                category: "strength",
                type: .staticWorkout
            ),
            timing: WorkoutTiming(
                startDate: start,
                endDate: start.addingTimeInterval(1_800),
                elapsedDuration: 1_800,
                activeDuration: 1_500,
                pausedDuration: 300
            ),
            exerciseRecords: [
                WorkoutExerciseRecord(
                    exerciseID: "bench_press",
                    name: "벤치프레스",
                    kind: .strength,
                    startDate: start,
                    endDate: start.addingTimeInterval(1_800),
                    strengthSets: [
                        StrengthSetRecord(
                            setNumber: 1,
                            weightKilograms: 40,
                            repetitions: 10,
                            restDuration: 60,
                            isWarmup: true,
                            isCompleted: true
                        ),
                        StrengthSetRecord(
                            setNumber: 2,
                            weightKilograms: 80,
                            repetitions: 8,
                            restDuration: 90,
                            isWarmup: false,
                            isCompleted: true
                        ),
                        StrengthSetRecord(
                            setNumber: 3,
                            weightKilograms: 85,
                            repetitions: 6,
                            restDuration: 120,
                            isWarmup: false,
                            isCompleted: true
                        )
                    ]
                )
            ],
            health: WorkoutHealthData(
                summary: WorkoutHealthSummary(
                    averageHeartRate: 128,
                    minimumHeartRate: 92,
                    maximumHeartRate: 166,
                    activeCalories: 240
                )
            )
        )

        let report = WorkoutReportBuilder()
            .makeReport(from: session)

        let strength = try #require(report.strength)

        #expect(strength.totalSets == 3)
        #expect(strength.workingSets == 2)
        #expect(strength.warmupSets == 1)
        #expect(strength.totalRepetitions == 14)
        #expect(strength.totalVolumeKilograms == 1_150)
        #expect(strength.maximumWeightKilograms == 85)
        #expect(strength.averageRestDuration == 90)

        let expectedOneRepMax =
            85 * (1 + 6.0 / 30.0)

        #expect(
            strength.bestEstimatedOneRepMaxKilograms
                == expectedOneRepMax
        )

        #expect(
            strength.volumePerActiveMinute
                == 46
        )

        #expect(report.cardio == nil)
        #expect(report.summary.activeCalories == 240)
    }

    @Test("유산소 리포트는 거리와 active duration으로 평균 pace를 계산한다")
    func cardioReportCalculatesPaceAndElevation() throws {
        let start = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        let route = [
            routePoint(
                timestamp: start,
                altitude: 10,
                verticalAccuracy: 5
            ),
            routePoint(
                timestamp: start.addingTimeInterval(60),
                altitude: 14,
                verticalAccuracy: 5
            ),
            routePoint(
                timestamp: start.addingTimeInterval(120),
                altitude: 12,
                verticalAccuracy: 5
            ),
            routePoint(
                timestamp: start.addingTimeInterval(180),
                altitude: 20,
                verticalAccuracy: 5
            )
        ]

        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "running",
                name: "달리기",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: start,
                endDate: start.addingTimeInterval(1_500),
                elapsedDuration: 1_500,
                activeDuration: 1_500,
                pausedDuration: 0
            ),
            exerciseRecords: [
                WorkoutExerciseRecord(
                    exerciseID: "running",
                    name: "달리기",
                    kind: .cardio,
                    startDate: start,
                    endDate: start.addingTimeInterval(1_500)
                )
            ],
            health: WorkoutHealthData(
                summary: WorkoutHealthSummary(
                    activeCalories: 310,
                    distanceMeters: 5_000,
                    averageSpeedMetersPerSecond: 3.33,
                    maximumSpeedMetersPerSecond: 4.2,
                    averageCadence: 172,
                    averagePowerWatts: 285
                )
            ),
            route: route
        )

        let report = WorkoutReportBuilder()
            .makeReport(from: session)

        let cardio = try #require(report.cardio)

        #expect(cardio.distanceMeters == 5_000)
        #expect(
            cardio.averagePaceSecondsPerKilometer
                == 300
        )
        #expect(
            cardio.averageSpeedMetersPerSecond
                == 3.33
        )
        #expect(
            cardio.maximumSpeedMetersPerSecond
                == 4.2
        )
        #expect(cardio.averageCadence == 172)
        #expect(cardio.averagePowerWatts == 285)
        #expect(cardio.elevationGainMeters == 12)
        #expect(cardio.routePointCount == 4)
        #expect(report.strength == nil)
    }


    @Test("HealthKit 거리가 없으면 GPS route 거리와 1km split을 사용한다")
    func cardioReportFallsBackToRouteDistanceAndBuildsSplits() throws {
        let start = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        let route = [
            routePoint(
                timestamp: start,
                latitude: 37.5000,
                longitude: 127.0000,
                altitude: 10,
                verticalAccuracy: 5
            ),
            routePoint(
                timestamp: start.addingTimeInterval(300),
                latitude: 37.5090,
                longitude: 127.0000,
                altitude: 12,
                verticalAccuracy: 5
            ),
            routePoint(
                timestamp: start.addingTimeInterval(600),
                latitude: 37.5180,
                longitude: 127.0000,
                altitude: 14,
                verticalAccuracy: 5
            )
        ]

        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "running",
                name: "달리기",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: start,
                endDate: start.addingTimeInterval(600),
                elapsedDuration: 600,
                activeDuration: 600,
                pausedDuration: 0
            ),
            exerciseRecords: [
                WorkoutExerciseRecord(
                    exerciseID: "running",
                    name: "달리기",
                    kind: .cardio,
                    startDate: start,
                    endDate: start.addingTimeInterval(600)
                )
            ],
            route: route
        )

        let report = WorkoutReportBuilder()
            .makeReport(from: session)

        let cardio = try #require(report.cardio)
        let distance = try #require(
            cardio.distanceMeters
        )
        let routeDistance = try #require(
            cardio.routeDistanceMeters
        )
        let pace = try #require(
            cardio.averagePaceSecondsPerKilometer
        )
        let speed = try #require(
            cardio.averageSpeedMetersPerSecond
        )

        #expect(abs(distance - 2_000) < 20)
        #expect(abs(routeDistance - distance) < 0.001)
        #expect(abs(pace - 300) < 5)
        #expect(abs(speed - 3.33) < 0.1)
        #expect(cardio.splits.count == 2)
        #expect(
            cardio.splits.allSatisfy {
                abs($0.distanceMeters - 1_000) < 0.001
            }
        )
        #expect(
            cardio.splits.allSatisfy {
                abs($0.paceSecondsPerKilometer - 300) < 5
            }
        )
        #expect(
            report.summary.distanceMeters
                == cardio.distanceMeters
        )
    }

    @Test("수직 정확도가 나쁜 route point는 고도 상승 계산에서 제외한다")
    func cardioElevationIgnoresPoorAltitudeAccuracy() throws {
        let start = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "running",
                name: "달리기",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: start,
                endDate: start.addingTimeInterval(600),
                elapsedDuration: 600,
                activeDuration: 600,
                pausedDuration: 0
            ),
            route: [
                routePoint(
                    timestamp: start,
                    altitude: 10,
                    verticalAccuracy: 5
                ),
                routePoint(
                    timestamp: start.addingTimeInterval(60),
                    altitude: 50,
                    verticalAccuracy: 50
                ),
                routePoint(
                    timestamp: start.addingTimeInterval(120),
                    altitude: 14,
                    verticalAccuracy: 5
                )
            ]
        )

        let cardio = try #require(
            WorkoutReportBuilder()
                .makeReport(from: session)
                .cardio
        )

        #expect(cardio.elevationGainMeters == nil)
    }

    @Test("최대 심박이 제공되면 심박 샘플 분포를 zone으로 계산한다")
    func heartRateZonesUseConfiguredMaximumHeartRate() {
        let start = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        let values: [Double] = [
            100,
            125,
            145,
            165,
            185
        ]

        let samples = values.enumerated().map {
            index,
            value in

            WorkoutHealthMetricSample(
                metric: .heartRate,
                startDate:
                    start.addingTimeInterval(
                        Double(index * 5)
                    ),
                endDate:
                    start.addingTimeInterval(
                        Double(index * 5 + 1)
                    ),
                value: value,
                unit: "bpm"
            )
        }

        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "running",
                name: "달리기",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: start,
                endDate: start.addingTimeInterval(60),
                elapsedDuration: 60,
                activeDuration: 60,
                pausedDuration: 0
            ),
            health: WorkoutHealthData(
                summary: WorkoutHealthSummary(
                    averageHeartRate: 144,
                    minimumHeartRate: 100,
                    maximumHeartRate: 185
                ),
                samples: samples
            )
        )

        let report = WorkoutReportBuilder(
            maximumHeartRate: 200
        )
        .makeReport(from: session)

        #expect(report.heart.sampleCount == 5)
        #expect(report.heart.zones.count == 5)
        #expect(
            report.heart.zones.map(\.sampleCount)
                == [1, 1, 1, 1, 1]
        )
        #expect(
            report.heart.zones.allSatisfy {
                $0.samplePercentage == 20
            }
        )
    }

    @Test("최대 심박이 없으면 zone을 추정하지 않는다")
    func heartRateZonesRemainEmptyWithoutMaximumHeartRate() {
        let start = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "running",
                name: "달리기",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: start,
                endDate: start.addingTimeInterval(60),
                elapsedDuration: 60,
                activeDuration: 60,
                pausedDuration: 0
            ),
            health: WorkoutHealthData(
                samples: [
                    WorkoutHealthMetricSample(
                        metric: .heartRate,
                        startDate: start,
                        endDate: start,
                        value: 150,
                        unit: "bpm"
                    )
                ]
            )
        )

        let report = WorkoutReportBuilder()
            .makeReport(from: session)

        #expect(report.heart.zones.isEmpty)
    }
}

private extension WorkoutReportBuilderTests {

    func routePoint(
        timestamp: Date,
        latitude: Double = 37.5,
        longitude: Double = 127,
        altitude: Double,
        horizontalAccuracy: Double = 5,
        verticalAccuracy: Double
    ) -> WorkoutRoutePoint {
        WorkoutRoutePoint(
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            speedMetersPerSecond: nil,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: nil
        )
    }
}
