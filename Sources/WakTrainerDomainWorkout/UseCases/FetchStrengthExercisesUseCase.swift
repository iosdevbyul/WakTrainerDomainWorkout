public struct FetchStrengthExercisesUseCase:
    Sendable {

    private let repository:
        any StrengthExerciseCatalogRepository

    public init(
        repository:
            any StrengthExerciseCatalogRepository
    ) {
        self.repository = repository
    }

    public func execute() async throws
        -> [StrengthExerciseDefinition] {
        try await repository.fetchExercises()
    }
}
