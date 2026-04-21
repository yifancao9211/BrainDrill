import Testing
@testable import BrainDrill

struct WorkbenchNavigationTests {
    @Test
    func workspaceDestinationsExposeStableWorkbenchMetadata() {
        let destinations = BDWorkspaceDestination.allCases

        #expect(destinations.count == 5)
        #expect(destinations.map(\.title) == ["控制台", "训练库", "分析", "素材", "设置"])
        #expect(destinations.map(\.route) == [.home, .mainIdea, .history, .materialsWorkbench, .settings])
    }

    @Test
    func workbenchRoutesResolveToExpectedNavigationTitles() {
        #expect(AppRoute.home.navigationTitle == "控制台")
        #expect(AppRoute.history.navigationTitle == "分析")
        #expect(AppRoute.materialsWorkbench.navigationTitle == "素材")
        #expect(AppRoute.settings.navigationTitle == "设置")
    }

    @Test
    func trainingCategoriesRemainGroupedUnderLibrary() {
        #expect(Set(AppRoute.readingModules) == Set([.mainIdea, .evidenceMap, .delayedRecall]))
        #expect(Set(AppRoute.logicModules) == Set([.syllogism, .logicArgument]))
        #expect(Set(AppRoute.attentionModules) == Set([.schulte, .visualSearch]))
        #expect(Set(AppRoute.inhibitionModules) == Set([.flanker, .goNoGo, .stopSignal]))
        #expect(Set(AppRoute.memoryModules) == Set([.nBack, .digitSpan, .corsiBlock, .changeDetection]))
        #expect(Set(AppRoute.speedModules) == Set([.choiceRT]))
    }
}
