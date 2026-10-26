import Foundation
import Testing
import WakTrainerCoreModels

@testable import WakTrainerDomainWorkout

@MainActor
@Suite("Atomic pause restore persistence")
struct WorkoutPauseRestorePersistenceServiceTests {
    private let origin = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeSession() -> WorkoutSession {
        WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "cycling",
                name: "Cycling",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: origin,
                endDate: origin.addingTimeInterval(3600),
                elapsedDuration: 3600,
                activeDuration: 2700,
                pausedDuration: 900,
                pauseIntervals: [
                    WorkoutPauseInterval(
                        startDate: origin.addingTimeInterval(1200),
                        endDate: origin.addingTimeInterval(2100)
                    )
                ]
            )
        )
    }

    @Test("Restore commits atomically and undo restores the exact original")
    func restoreAndUndo() async throws {
        let original = makeSession()
        let storage = FakeRestoreStorage(session: original)
        let service = WorkoutPauseRestorePersistenceService(storage: storage)
        let token = try await service.restore(
            sessionID: original.id,
            from: origin.addingTimeInterval(1200),
            to: origin.addingTimeInterval(1800)
        )
        #expect(storage.session == token.after)
        #expect(storage.session?.timing.activeDuration == 3300)
        try await service.undo(token)
        #expect(storage.session == original)
    }

    @Test("Concurrent write before compare-and-replace rejects stale restore")
    func staleRestoreIsRejected() async throws {
        let original = makeSession()
        let storage = FakeRestoreStorage(session: original)
        storage.mutateBeforeNextCompare = true
        let service = WorkoutPauseRestorePersistenceService(storage: storage)
        await #expect(throws: WorkoutPauseRestorePersistenceError.concurrentModification) {
            try await service.restore(
                sessionID: original.id,
                from: origin.addingTimeInterval(1200),
                to: origin.addingTimeInterval(1800)
            )
        }
        #expect(storage.session?.timing.activeDuration == 2701)
    }

    @Test("Undo cannot overwrite a subsequent session edit")
    func staleUndoIsRejected() async throws {
        let original = makeSession()
        let storage = FakeRestoreStorage(session: original)
        let service = WorkoutPauseRestorePersistenceService(storage: storage)
        let token = try await service.restore(
            sessionID: original.id,
            from: origin.addingTimeInterval(1200),
            to: origin.addingTimeInterval(1800)
        )
        storage.mutateBeforeNextCompare = true
        await #expect(throws: WorkoutPauseRestorePersistenceError.concurrentModification) {
            try await service.undo(token)
        }
        #expect(storage.session != original)
    }

    @Test("Missing session cannot be restored")
    func missingSessionIsRejected() async {
        let storage = FakeRestoreStorage(session: nil)
        let service = WorkoutPauseRestorePersistenceService(storage: storage)
        await #expect(throws: WorkoutPauseRestorePersistenceError.sessionUnavailable) {
            try await service.restore(
                sessionID: UUID(),
                from: origin,
                to: origin.addingTimeInterval(1)
            )
        }
    }
}

@MainActor
private final class FakeRestoreStorage: WorkoutPauseRestoreStorage {
    var session: WorkoutSession?
    var mutateBeforeNextCompare = false

    init(session: WorkoutSession?) {
        self.session = session
    }

    func fetchCompletedSession(id: UUID) async throws -> WorkoutSession? {
        guard session?.id == id else { return nil }
        return session
    }

    func compareAndReplaceCompleted(
        expected: WorkoutSession,
        replacement: WorkoutSession
    ) async throws -> Bool {
        if mutateBeforeNextCompare {
            mutateBeforeNextCompare = false
            session?.timing.activeDuration += 1
        }
        guard session == expected, expected.id == replacement.id else {
            return false
        }
        session = replacement
        return true
    }
}
