//
//  WorkoutDefinition.swift
//  WakTrainerDomainWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import WakTrainerCoreModels

public struct WorkoutDefinition: Identifiable, Codable, Sendable, Equatable {

    public let id: String
    public let name: String
    public let category: WorkoutCategory
    public let type: WorkoutType

    public init(
        id: String,
        name: String,
        category: WorkoutCategory,
        type: WorkoutType
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.type = type
    }

    public var requiresLocationTracking: Bool {
        type == .dynamicWorkout
    }
}
