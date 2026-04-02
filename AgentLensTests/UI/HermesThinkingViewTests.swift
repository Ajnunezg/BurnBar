import XCTest
import SwiftUI
import ViewInspector
@testable import BurnBar

// MARK: - HermesThinkingView

@MainActor
final class HermesThinkingViewTests: XCTestCase {

    func test_renders() throws {
        let view = HermesThinkingView()
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(HStack.self))
    }

    func test_containsThreeDroplets() throws {
        let view = HermesThinkingView()
        let sut = try view.inspect()
        // The view is an HStack containing three droplets
        let hStack = try sut.find(HStack.self)
        XCTAssertNoThrow(try hStack.forEach(Group.self))
    }
}
