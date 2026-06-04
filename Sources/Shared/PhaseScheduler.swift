import Foundation

/// A single-slot, cancellable timer used to drive auto-paced training phases from
/// a SwiftUI view.
///
/// It replaces raw `DispatchQueue.main.asyncAfter` calls scattered across the
/// training views. Those calls could not be cancelled, so a pending closure would
/// still fire after the user cancelled a session or navigated away (firing against
/// a stale/orphaned engine). `PhaseScheduler` guarantees that:
///   - scheduling a new action supersedes any previously pending one, and
///   - `cancel()` (e.g. from `.onDisappear`) prevents a pending action from running.
///
/// Cancellation is implemented with a monotonically increasing generation token
/// rather than `DispatchWorkItem.cancel()`, which makes the contract trivially
/// testable by injecting a synchronous `sleep`.
///
/// Main-actor isolated: it is held as view `@State` and only ever touched on the
/// main thread.
@MainActor
final class PhaseScheduler {
    private var generation = 0
    private let sleep: (_ milliseconds: Int, _ fire: @escaping @MainActor () -> Void) -> Void

    /// - Parameter sleep: how a delayed `fire` is scheduled. Defaults to the main
    ///   dispatch queue; tests inject a synchronous implementation.
    init(sleep: @escaping (_ milliseconds: Int, _ fire: @escaping @MainActor () -> Void) -> Void = PhaseScheduler.dispatchSleep) {
        self.sleep = sleep
    }

    nonisolated static func dispatchSleep(_ milliseconds: Int, _ fire: @escaping @MainActor () -> Void) {
        // A `@MainActor` closure is `Sendable`, so it crosses the async boundary
        // cleanly; the queue guarantees we resume on the main thread.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds)) {
            MainActor.assumeIsolated { fire() }
        }
    }

    /// Run `action` after `milliseconds`, unless superseded by another `schedule`
    /// or a `cancel` in the meantime.
    func schedule(afterMilliseconds milliseconds: Int, _ action: @escaping @MainActor () -> Void) {
        generation += 1
        let scheduled = generation
        sleep(milliseconds) { [weak self] in
            guard let self, self.generation == scheduled else { return }
            action()
        }
    }

    /// Cancel any pending action. Safe to call repeatedly.
    func cancel() {
        generation += 1
    }
}
