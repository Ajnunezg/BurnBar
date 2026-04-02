import XCTest
import ViewInspector
@testable import BurnBar

// MARK: - ChatFAB

@MainActor
final class ChatFABTests: XCTestCase {

    func test_renders() throws {
        let view = ChatFAB(hasNewInsights: false, action: {})
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Button.self))
    }

    func test_rendersWithInsights() throws {
        let view = ChatFAB(hasNewInsights: true, action: {})
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Button.self))
    }

    func test_actionCallbackFires() throws {
        var actionFired = false
        let view = ChatFAB(hasNewInsights: false) {
            actionFired = true
        }
        let sut = try view.inspect()
        try sut.find(Button.self).tap()
        XCTAssertTrue(actionFired)
    }

    func test_showsSparklesIcon() throws {
        let view = ChatFAB(hasNewInsights: false, action: {})
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Image.self), "ChatFAB should contain sparkles icon")
    }
}
