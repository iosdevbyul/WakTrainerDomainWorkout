//
//  FetchWorkoutsUseCase.swift
//  WakTrainerDomainWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

public struct FetchWorkoutsUseCase: Sendable {

    private let repository: any WorkoutCatalogRepository

    public init(repository: any WorkoutCatalogRepository) {
        self.repository = repository
    }

    public func execute() async throws -> [WorkoutDefinition] {
        try await repository.fetchWorkouts()
    }
}
