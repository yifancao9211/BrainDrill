import Foundation
import Testing
@testable import BrainDrill

@MainActor
struct CancelBehaviorTests {
    @Test func cancelNBackDoesNotSaveSession() {
        let store = InMemoryTrainingStore()
        let appModel = AppModel(store: store)

        appModel.startNBackSession()
        #expect(appModel.nBack.isActive)

        let countBefore = appModel.sessions.count
        appModel.cancelNBackSession()

        #expect(!appModel.nBack.isActive)
        #expect(appModel.sessions.count == countBefore)
    }

    @Test func cancelChangeDetectionDoesNotSaveSession() {
        let store = InMemoryTrainingStore()
        let appModel = AppModel(store: store)

        appModel.startChangeDetectionSession()
        #expect(appModel.changeDetection.isActive)

        let countBefore = appModel.sessions.count
        appModel.cancelChangeDetectionSession()

        #expect(!appModel.changeDetection.isActive)
        #expect(appModel.sessions.count == countBefore)
    }

    @Test func cancelSchulteDoesNotSaveSession() {
        let store = InMemoryTrainingStore()
        let appModel = AppModel(store: store)

        appModel.startSchulteSession()

        let countBefore = appModel.sessions.count
        appModel.cancelSchulteSession()

        #expect(!appModel.schulte.isTrainingActive)
        #expect(appModel.sessions.count == countBefore)
    }

    @Test func cancelDigitSpanDoesNotSaveSession() {
        let store = InMemoryTrainingStore()
        let appModel = AppModel(store: store)

        appModel.startDigitSpanSession()
        #expect(appModel.digitSpan.isActive)

        let countBefore = appModel.sessions.count
        appModel.cancelDigitSpanSession()

        #expect(!appModel.digitSpan.isActive)
        #expect(appModel.sessions.count == countBefore)
    }

    @Test func cancelCorsiBlockDoesNotSaveSession() {
        let store = InMemoryTrainingStore()
        let appModel = AppModel(store: store)

        appModel.startCorsiBlockSession()
        #expect(appModel.corsiBlock.isActive)

        let countBefore = appModel.sessions.count
        appModel.cancelCorsiBlockSession()

        #expect(!appModel.corsiBlock.isActive)
        #expect(appModel.sessions.count == countBefore)
    }
}
