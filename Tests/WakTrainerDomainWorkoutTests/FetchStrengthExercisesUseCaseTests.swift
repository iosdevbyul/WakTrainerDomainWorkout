import Testing
import WakTrainerCoreModels

@testable import WakTrainerDomainWorkout

struct FetchStrengthExercisesUseCaseTests {

    @Test
    func executeReturnsStrengthExercisesFromRepository()
        async throws {
        let expected = [
            StrengthExerciseDefinition(
                id: "squat",
                name: "Squat",
                supportedEquipment: [
                    .barbell,
                    .dumbbell,
                    .bodyweight
                ]
            ),
            StrengthExerciseDefinition(
                id: "bench_press",
                name: "Bench Press",
                supportedEquipment: [
                    .barbell,
                    .dumbbell
                ]
            )
        ]

        let repository =
            MockStrengthExerciseCatalogRepository(
                exercises: expected
            )

        let useCase =
            FetchStrengthExercisesUseCase(
                repository: repository
            )

        let result =
            try await useCase.execute()

        #expect(result == expected)
    }
}

private struct MockStrengthExerciseCatalogRepository:
    StrengthExerciseCatalogRepository {

    let exercises:
        [StrengthExerciseDefinition]

    func fetchExercises() async throws
        -> [StrengthExerciseDefinition] {
        exercises
    }
}
