import Foundation

/// Observable state object that drives the 3-2-1 pre-training countdown.
///
/// Usage:
/// 1. Create a `CountdownState` and set `onComplete` to your training start callback.
/// 2. Call `start()` to begin the countdown.
/// 3. The view layer uses `BDCountdownOverlay` which reads `isActive` and `remaining`.
@Observable
final class CountdownState {
    private(set) var remaining: Int = 0
    private(set) var isActive = false
    var onComplete: (() -> Void)?

    private let duration: Int
    private var timer: Timer?

    init(duration: Int = 3) {
        self.duration = max(1, duration)
    }

    func start() {
        cancel()
        remaining = duration
        isActive = true
        scheduleTimer()
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        isActive = false
    }

    /// Manually advance one tick (used in tests). The timer calls this automatically.
    func tick() {
        guard isActive else { return }
        remaining -= 1
        if remaining <= 0 {
            remaining = 0
            isActive = false
            timer?.invalidate()
            timer = nil
            onComplete?()
        }
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    deinit {
        timer?.invalidate()
    }
}
