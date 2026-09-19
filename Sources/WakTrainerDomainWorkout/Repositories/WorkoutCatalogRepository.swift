//
//  WorkoutCatalogRepository.swift
//  WakTrainerDomainWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

public protocol WorkoutCatalogRepository: Sendable {
    func fetchWorkouts() async throws -> [WorkoutDefinition]
}
