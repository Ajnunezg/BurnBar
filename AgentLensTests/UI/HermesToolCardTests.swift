import XCTest
import SwiftUI
import ViewInspector
@testable import BurnBar

// MARK: - HermesToolCard

@MainActor
final class HermesToolCardTests: XCTestCase {

    func test_rendersWithToolName() throws {
        let view = HermesToolCard(toolName: "Read", detail: nil, isRunning: false)
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(VStack.self))
    }

    func test_showsToolNameText() throws {
        let view = HermesToolCard(toolName: "Bash", detail: nil, isRunning: false)
        let sut = try view.inspect()
        let texts = try sut.findAll(Text.self)
        let hasToolName = texts.contains { try $0.string() == "Bash" }
        XCTAssertTrue(hasToolName, "Tool name 'Bash' should be displayed")
    }

    func test_runningState_showsRunningText() throws {
        let view = HermesToolCard(toolName: "Read", detail: "file.swift", isRunning: true)
        let sut = try view.inspect()
        let texts = try sut.findAll(Text.self)
        let hasRunning = texts.contains { try $0.string() == "Running..." }
        XCTAssertTrue(hasRunning, "Should show 'Running...' when tool is active")
    }

    func test_notRunning_hidesRunningText() throws {
        let view = HermesToolCard(toolName: "Read", detail: nil, isRunning: false)
        let sut = try view.inspect()
        let texts = try sut.findAll(Text.self)
        let hasRunning = texts.contains { try $0.string() == "Running..." }
        XCTAssertFalse(hasRunning, "Should not show 'Running...' when tool is inactive")
    }

    func test_capabilityIcon_forFileTools() throws {
        let view = HermesToolCard(toolName: "Read", detail: nil, isRunning: false)
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Image.self), "Should render a capability icon")
    }

    func test_capabilityIcon_forTerminalTools() throws {
        let view = HermesToolCard(toolName: "Bash", detail: nil, isRunning: false)
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Image.self))
    }

    func test_capabilityIcon_forSearchTools() throws {
        let view = HermesToolCard(toolName: "Grep", detail: nil, isRunning: false)
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Image.self))
    }

    func test_capabilityIcon_forWebTools() throws {
        let view = HermesToolCard(toolName: "WebFetch", detail: nil, isRunning: false)
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Image.self))
    }

    func test_capabilityIcon_forEditTools() throws {
        let view = HermesToolCard(toolName: "Edit", detail: nil, isRunning: false)
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Image.self))
    }

    func test_capabilityIcon_forMemoryTools() throws {
        let view = HermesToolCard(toolName: "Memory", detail: nil, isRunning: false)
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Image.self))
    }

    func test_rendersWithEmptyDetail() throws {
        let view = HermesToolCard(toolName: "Read", detail: "", isRunning: false)
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(VStack.self))
    }
}
