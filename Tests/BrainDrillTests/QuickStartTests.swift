import Foundation
import Testing
@testable import BrainDrill

@MainActor
struct QuickStartTests {
    @Test func quickStartNavigatesAndStartsEngine() {
        let store = InMemoryTrainingStore()
        let appModel = AppModel(store: store)

        #expect(appModel.selectedRoute == .home)
        #expect(!appModel.nBack.isActive)

        appModel.quickStartModule(.nBack)

        #expect(appModel.selectedRoute == .nBack)
        #expect(appModel.nBack.isActive)
    }

    @Test func quickStartNBack() {
        let store = InMemoryTrainingStore()
        let appModel = AppModel(store: store)

        appModel.quickStartModule(.nBack)

        #expect(appModel.selectedRoute == .nBack)
        #expect(appModel.nBack.isActive)
    }

    @Test func quickStartNonModuleRouteDoesNotCrash() {
        let store = InMemoryTrainingStore()
        let appModel = AppModel(store: store)

        appModel.quickStartModule(.home)

        #expect(appModel.selectedRoute == .home)
    }

    @Test func quickStartChangeDetection() {
        let store = InMemoryTrainingStore()
        let appModel = AppModel(store: store)

        appModel.quickStartModule(.changeDetection)

        #expect(appModel.selectedRoute == .changeDetection)
        #expect(appModel.changeDetection.isActive)
    }

    @Test func quickStartSchulte() {
        let store = InMemoryTrainingStore()
        let appModel = AppModel(store: store)

        appModel.quickStartModule(.schulte)

        #expect(appModel.selectedRoute == .schulte)
        #expect(appModel.schulte.isTrainingActive || appModel.schulte.isPreparing)
    }

    @Test func quickStartDigitSpan() {
        let store = InMemoryTrainingStore()
        let appModel = AppModel(store: store)

        appModel.quickStartModule(.digitSpan)

        #expect(appModel.selectedRoute == .digitSpan)
        #expect(appModel.digitSpan.isActive)
    }

    @Test func quickStartCorsiBlock() {
        let store = InMemoryTrainingStore()
        let appModel = AppModel(store: store)

        appModel.quickStartModule(.corsiBlock)

        #expect(appModel.selectedRoute == .corsiBlock)
        #expect(appModel.corsiBlock.isActive)
    }
}
