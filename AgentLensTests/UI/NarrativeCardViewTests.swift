import XCTest
import ViewInspector
@testable import BurnBar

// MARK: - NarrativeCardView

@MainActor
final class NarrativeCardViewTests: XCTestCase {

    func test_emptyDataStore_rendersEmpty() throws {
        let store = DataStore()
        let view = NarrativeCardView(dataStore: store)
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(EmptyView.self))
    }

    func test_nonEmptyDataStore_rendersCard() throws {
        let store = DataStore()
        store.replaceUsages(ViewTestFixtures.makeWeekOfUsages())
        let view = NarrativeCardView(dataStore: store)
        let sut = try view.inspect()
        // Should not be EmptyView when usages exist
        let hasEmpty = (try? sut.find(EmptyView.self)) != nil
        XCTAssertFalse(hasEmpty, "Should not render EmptyView when usages exist")
    }
}

// MARK: - Insight Engine Logic Tests (exercised by NarrativeCardView)

@MainActor
final class InsightEngineLogicTests: XCTestCase {

    func test_emptyUsages_generatesNarrative() {
        let store = DataStore()
        let narrative = InsightEngine.generateNarrative(from: store)
        // Narrative should have at least an icon and headline
        XCTAssertFalse(narrative.icon.isEmpty)
        XCTAssertFalse(narrative.headline.isEmpty)
    }

    func test_usagesWithSpend_generatesNarrative() {
        let store = DataStore()
        store.replaceUsages(ViewTestFixtures.makeWeekOfUsages(baseCost: 2.0))
        let narrative = InsightEngine.generateNarrative(from: store)
        XCTAssertFalse(narrative.icon.isEmpty)
        XCTAssertFalse(narrative.headline.isEmpty)
    }
}
