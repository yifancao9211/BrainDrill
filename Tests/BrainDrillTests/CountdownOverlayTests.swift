import Foundation
import Testing
@testable import BrainDrill

@MainActor
struct CountdownOverlayTests {
    @Test func countdownStartsAtThree() {
        let countdown = CountdownState()
        countdown.start()

        #expect(countdown.remaining == 3)
        #expect(countdown.isActive)
    }

    @Test func countdownNotActiveByDefault() {
        let countdown = CountdownState()

        #expect(!countdown.isActive)
        #expect(countdown.remaining == 0)
    }

    @Test func cancelStopsCountdown() {
        let countdown = CountdownState()
        countdown.start()
        countdown.cancel()

        #expect(!countdown.isActive)
    }

    @Test func countdownWithCustomDuration() {
        let countdown = CountdownState(duration: 5)
        countdown.start()

        #expect(countdown.remaining == 5)
    }

    @Test func tickDecrementsRemaining() {
        let countdown = CountdownState()
        countdown.start()
        countdown.tick()

        #expect(countdown.remaining == 2)
        #expect(countdown.isActive)
    }

    @Test func tickToZeroCompletesCountdown() {
        let countdown = CountdownState()
        countdown.start()
        countdown.tick()
        countdown.tick()
        countdown.tick()

        #expect(countdown.remaining == 0)
        #expect(!countdown.isActive)
    }

    @Test func completionCallbackFires() {
        var didComplete = false
        let countdown = CountdownState()
        countdown.onComplete = { didComplete = true }
        countdown.start()
        countdown.tick()
        countdown.tick()
        countdown.tick()

        #expect(didComplete)
    }

    @Test func startResetsIfAlreadyActive() {
        let countdown = CountdownState()
        countdown.start()
        countdown.tick()
        #expect(countdown.remaining == 2)

        countdown.start()
        #expect(countdown.remaining == 3)
    }
}
