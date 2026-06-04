import Foundation
import Testing
@testable import BrainDrill

@MainActor
struct NavigationResetTests {
    // Regression: quick-starting a module from the console used to bounce the
    // route back to home, because syncSelection moved the sidebar onto the
    // module's category, which then cleared the active module. The sidebar
    // reflecting the active module's OWN category must not clear it.
    @Test func sidebarReflectingActiveModulesCategoryDoesNotClearIt() {
        // changeDetection lives in the "memory" (工作记忆) category.
        #expect(
            RootView.shouldClearActiveModule(
                activeRoute: .changeDetection,
                newSidebar: .category("memory")
            ) == false
        )
        #expect(
            RootView.shouldClearActiveModule(
                activeRoute: .corsiBlock,
                newSidebar: .category("memory")
            ) == false
        )
    }

    @Test func navigatingToDifferentCategoryClearsActiveModule() {
        // Active memory module, user clicks the reading category -> leave the module.
        #expect(
            RootView.shouldClearActiveModule(
                activeRoute: .nBack,
                newSidebar: .category("reading")
            ) == true
        )
    }

    @Test func navigatingToWorkspaceClearsActiveModule() {
        #expect(
            RootView.shouldClearActiveModule(
                activeRoute: .digitSpan,
                newSidebar: .workspace(.controlCenter)
            ) == true
        )
    }

    @Test func noActiveModuleNeverClears() {
        #expect(
            RootView.shouldClearActiveModule(
                activeRoute: .home,
                newSidebar: .workspace(.trainingLibrary)
            ) == false
        )
    }
}
