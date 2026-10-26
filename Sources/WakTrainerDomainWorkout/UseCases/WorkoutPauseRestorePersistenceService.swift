import Foundation
import WakTrainerCoreModels

/// Implementations must compare and replace in one indivisible storage operation.
/// A fetch followed by an ordinary save does NOT satisfy this contract.
@MainActor
public protocol WorkoutPauseRestoreStorage: AnyObject {
    func fetchCompletedSession(id: UUID) async throws -> WorkoutSession?

    /// Atomically replace only when the persisted session exactly equals expected.
    /// Return false on a stale snapshot, deletion, or changed completion state.
    func compareAndReplaceCompleted(
        expected: WorkoutSession,
        replacement: WorkoutSession
    ) async throws -> Bool
}

public enum WorkoutPauseRestorePersistenceError: Error, Equatable, Sendable {
    case sessionUnavailable
    case concurrentModification
    case mismatchedSession
}

public struct WorkoutPauseRestoreUndoToken: Sendable {
    public let before: WorkoutSession
    public let after: WorkoutSession

    public init(before: WorkoutSession, after: WorkoutSession) {
        self.before = before
        self.after = after
    }
}

/// Coordinates domain restore with an atomic compare-and-replace storage boundary.
/// Does not assume an ordinary WorkoutSessionRepository.saveCompleted is atomic.
@MainActor
public final class WorkoutPauseRestorePersistenceService {
    private let storage: any WorkoutPauseRestoreStorage
    private let engine: WorkoutPauseRestoreEngine

    public init(
        storage: any WorkoutPauseRestoreStorage,
        engine: WorkoutPauseRestoreEngine = WorkoutPauseRestoreEngine()
    ) {
        self.storage = storage
        self.engine = engine
    }

    @discardableResult
    public func restore(
        sessionID: UUID,
        from start: Date,
        to end: Date
    ) async throws -> WorkoutPauseRestoreUndoToken {
        guard let current = try await storage.fetchCompletedSession(id: sessionID) else {
            throw WorkoutPauseRestorePersistenceError.sessionUnavailable
        }
        let result = try engine.restore(session: current, from: start, to: end)
        guard try await storage.compareAndReplaceCompleted(
            expected: current,
            replacement: result.updated
        ) else {
            throw WorkoutPauseRestorePersistenceError.concurrentModification
        }
        return WorkoutPauseRestoreUndoToken(
            before: current,
            after: result.updated
        )
    }

    public func undo(_ token: WorkoutPauseRestoreUndoToken) async throws {
        guard token.before.id == token.after.id else {
            throw WorkoutPauseRestorePersistenceError.mismatchedSession
        }
        guard try await storage.compareAndReplaceCompleted(
            expected: token.after,
            replacement: token.before
        ) else {
            throw WorkoutPauseRestorePersistenceError.concurrentModification
        }
    }
}
