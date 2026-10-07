import Foundation
import WakTrainerCoreModels

public enum WorkoutSessionPersistenceState: String, Codable, Sendable {
    case inProgress
    case completed
}

public enum WorkoutSessionSyncState: String, Codable, Sendable {
    case pending
    case synced
    case failed
}

public struct StoredWorkoutSession: Equatable, Sendable {
    public let session: WorkoutSession
    public let persistenceState: WorkoutSessionPersistenceState
    public let syncState: WorkoutSessionSyncState
    public let updatedAt: Date

    public init(
        session: WorkoutSession,
        persistenceState: WorkoutSessionPersistenceState,
        syncState: WorkoutSessionSyncState,
        updatedAt: Date
    ) {
        self.session = session
        self.persistenceState = persistenceState
        self.syncState = syncState
        self.updatedAt = updatedAt
    }
}

@MainActor
public protocol WorkoutSessionRepository: AnyObject {
    func saveCheckpoint(_ session: WorkoutSession) async throws
    func saveCompleted(_ session: WorkoutSession) async throws
    func fetchSession(id: UUID) async throws -> StoredWorkoutSession?
    func fetchSessions() async throws -> [StoredWorkoutSession]
    func fetchIncompleteSessions() async throws -> [StoredWorkoutSession]
    func fetchCompletedSessions(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [StoredWorkoutSession]
    func deleteSession(id: UUID) async throws
    func deleteAllSessions() async throws
}
