import XCTest
import ViewInspector
@testable import BurnBar

// MARK: - OnboardingCompleteView

@MainActor
final class OnboardingCompleteViewTests: XCTestCase {

    func test_rendersWithEmptyDataStore() throws {
        let store = DataStore()
        let view = OnboardingCompleteView(
            dataStore: store,
            selectedProviders: [],
            onOpenDashboard: {},
            onDismiss: {}
        )
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(VStack.self))
    }

    func test_rendersWithSelectedProviders() throws {
        let store = DataStore()
        let view = OnboardingCompleteView(
            dataStore: store,
            selectedProviders: [.claudeCode, .factory],
            onOpenDashboard: {},
            onDismiss: {}
        )
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(VStack.self))
    }

    func test_showsYoureAllSetWhenNoSessions() throws {
        let store = DataStore()
        let view = OnboardingCompleteView(
            dataStore: store,
            selectedProviders: [],
            onOpenDashboard: {},
            onDismiss: {}
        )
        let sut = try view.inspect()
        let texts = try sut.findAll(Text.self)
        let hasSet = texts.contains { try $0.string() == "You're all set" }
        XCTAssertTrue(hasSet, "Should show 'You're all set' when no sessions found")
    }

    func test_showsSessionCountWhenSessionsExist() throws {
        let store = DataStore()
        let usages = ViewTestFixtures.makeWeekOfUsages()
        store.replaceUsages(usages)
        let view = OnboardingCompleteView(
            dataStore: store,
            selectedProviders: [.factory],
            onOpenDashboard: {},
            onDismiss: {}
        )
        let sut = try view.inspect()
        let texts = try sut.findAll(Text.self)
        let hasSessions = texts.contains { (try? $0.string())?.contains("session") == true }
        XCTAssertTrue(hasSessions, "Should mention sessions when usages exist")
    }

    func test_showsTrackingCountForSelectedProviders() throws {
        let store = DataStore()
        let view = OnboardingCompleteView(
            dataStore: store,
            selectedProviders: [.claudeCode, .factory, .hermes],
            onOpenDashboard: {},
            onDismiss: {}
        )
        let sut = try view.inspect()
        let texts = try sut.findAll(Text.self)
        let hasTracking = texts.contains { (try? $0.string())?.contains("3 agent") == true }
        XCTAssertTrue(hasTracking, "Should mention tracking 3 agents")
    }

    func test_openDashboardCallbackFires() throws {
        let store = DataStore()
        var dashboardFired = false
        let view = OnboardingCompleteView(
            dataStore: store,
            selectedProviders: [],
            onOpenDashboard: { dashboardFired = true },
            onDismiss: {}
        )
        let sut = try view.inspect()
        // Find the "Open Dashboard" button
        let buttons = try sut.findAll(Button.self)
        XCTAssertEqual(buttons.count, 2, "Should have Open Dashboard and Stay in menu bar buttons")

        try buttons[0].tap()
        XCTAssertTrue(dashboardFired, "Open Dashboard button should fire callback")
    }

    func test_dismissCallbackFires() throws {
        let store = DataStore()
        var dismissFired = false
        let view = OnboardingCompleteView(
            dataStore: store,
            selectedProviders: [],
            onOpenDashboard: {},
            onDismiss: { dismissFired = true }
        )
        let sut = try view.inspect()
        let buttons = try sut.findAll(Button.self)

        try buttons[1].tap()
        XCTAssertTrue(dismissFired, "Dismiss button should fire callback")
    }

    func test_showsCheckmarkIcon() throws {
        let store = DataStore()
        let view = OnboardingCompleteView(
            dataStore: store,
            selectedProviders: [],
            onOpenDashboard: {},
            onDismiss: {}
        )
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Image.self), "Should contain checkmark icon")
    }
}
