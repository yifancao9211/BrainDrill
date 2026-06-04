import Foundation
import Testing
@testable import BrainDrill

@MainActor
struct PhaseSchedulerTests {
    /// A synchronous fake that captures the scheduled `fire` closure so the test
    /// can decide exactly when (and whether) the "timer" fires.
    @MainActor
    private final class ManualClock {
        var pending: [@MainActor () -> Void] = []
        func sleep(_ ms: Int, _ fire: @escaping @MainActor () -> Void) {
            pending.append(fire)
        }
        func fire(_ index: Int) { pending[index]() }
    }

    @Test func actionFiresWhenNotCancelled() {
        let clock = ManualClock()
        let scheduler = PhaseScheduler(sleep: clock.sleep)
        var fired = 0
        scheduler.schedule(afterMilliseconds: 100) { fired += 1 }
        clock.fire(0)
        #expect(fired == 1)
    }

    @Test func cancelPreventsPendingAction() {
        let clock = ManualClock()
        let scheduler = PhaseScheduler(sleep: clock.sleep)
        var fired = 0
        scheduler.schedule(afterMilliseconds: 100) { fired += 1 }
        scheduler.cancel()
        clock.fire(0) // the timer "fires" after cancellation
        #expect(fired == 0)
    }

    @Test func reschedulingSupersedesPreviousAction() {
        let clock = ManualClock()
        let scheduler = PhaseScheduler(sleep: clock.sleep)
        var a = 0
        var b = 0
        scheduler.schedule(afterMilliseconds: 100) { a += 1 }
        scheduler.schedule(afterMilliseconds: 100) { b += 1 }
        clock.fire(0) // stale -> ignored
        clock.fire(1) // current -> runs
        #expect(a == 0)
        #expect(b == 1)
    }
}
