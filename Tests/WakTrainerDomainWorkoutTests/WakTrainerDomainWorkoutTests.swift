import Testing
import WakTrainerCoreModels
@testable import WakTrainerDomainWorkout

struct WorkoutDefinitionTests {

    @Test
    func dynamicWorkoutRequiresLocationTracking() {
        let workout = WorkoutDefinition(
            id: "running",
            name: "달리기",
            category: .cardio,
            type: .dynamicWorkout
        )

        #expect(workout.requiresLocationTracking)
    }

    @Test
    func staticWorkoutDoesNotRequireLocationTracking() {
        let workout = WorkoutDefinition(
            id: "squat",
            name: "스쿼트",
            category: .strength,
            type: .staticWorkout
        )

        #expect(workout.requiresLocationTracking == false)
    }
}
