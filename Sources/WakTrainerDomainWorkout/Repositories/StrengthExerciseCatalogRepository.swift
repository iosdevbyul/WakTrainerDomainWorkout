public protocol StrengthExerciseCatalogRepository:
    Sendable {
    func fetchExercises() async throws
        -> [StrengthExerciseDefinition]
}
