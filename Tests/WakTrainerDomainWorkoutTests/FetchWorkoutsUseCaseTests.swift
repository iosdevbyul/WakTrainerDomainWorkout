//
//  FetchWorkoutsUseCaseTests.swift
//  WakTrainerDomainWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import Testing
import WakTrainerCoreModels

@testable import WakTrainerDomainWorkout

struct FetchWorkoutsUseCaseTests {

    @Test
    func executeReturnsWorkoutsFromRepository() async throws {
        let expected = [
            WorkoutDefinition(
                id: "running",
                name: "달리기",
                category: .cardio,
                type: .dynamicWorkout
            ),
            WorkoutDefinition(
                id: "squat",
                name: "스쿼트",
                category: .strength,
                type: .staticWorkout
            )
        ]

        let repository = MockWorkoutCatalogRepository(
            workouts: expected
        )

        let useCase = FetchWorkoutsUseCase(
            repository: repository
        )

        let result = try await useCase.execute()

        #expect(result == expected)
    }
}

private struct MockWorkoutCatalogRepository: WorkoutCatalogRepository {

    let workouts: [WorkoutDefinition]

    func fetchWorkouts() async throws -> [WorkoutDefinition] {
        workouts
    }
}
