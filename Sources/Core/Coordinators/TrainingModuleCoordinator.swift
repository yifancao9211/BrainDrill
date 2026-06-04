import Foundation

/// The uniform surface every per-module training coordinator exposes.
///
/// Conforming coordinators can be held in a `[TrainingModule: any
/// TrainingModuleCoordinator]` registry so `AppModel` can answer "is this module
/// active?", "what's its status line?", and "cancel it" without a per-module
/// `switch`. Adding or removing a module then only means updating the registry.
protocol TrainingModuleCoordinator: AnyObject {
    /// Whether a session for this module is currently in progress.
    var isActive: Bool { get }
    /// Short status line shown in the module header.
    var statusMessage: String { get }
    /// Abort the active session without recording a result.
    func cancelSession()
}
