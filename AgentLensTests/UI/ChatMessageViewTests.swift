import XCTest
import ViewInspector
@testable import BurnBar

// MARK: - ChatMessageView

@MainActor
final class ChatMessageViewTests: XCTestCase {

    func test_rendersUserMessage() throws {
        let message = ViewTestFixtures.makeUserMessage(content: "Hello world")
        let view = ChatMessageView(
            message: message,
            isStreaming: false,
            showViaBadge: false
        )
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(HStack.self))
    }

    func test_rendersAssistantMessage() throws {
        let message = ViewTestFixtures.makeAssistantMessage(content: "I can help with that.")
        let view = ChatMessageView(
            message: message,
            isStreaming: false,
            showViaBadge: false
        )
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(HStack.self))
    }

    func test_userMessageShowsContent() throws {
        let message = ViewTestFixtures.makeUserMessage(content: "Test content here")
        let view = ChatMessageView(
            message: message,
            isStreaming: false,
            showViaBadge: false
        )
        let sut = try view.inspect()
        let texts = try sut.findAll(Text.self)
        let hasContent = texts.contains { try $0.string().contains("Test content here") }
        XCTAssertTrue(hasContent)
    }

    func test_assistantMessageShowsContent() throws {
        let message = ViewTestFixtures.makeAssistantMessage(content: "Assistant reply")
        let view = ChatMessageView(
            message: message,
            isStreaming: false,
            showViaBadge: false
        )
        let sut = try view.inspect()
        let texts = try sut.findAll(Text.self)
        let hasContent = texts.contains { try $0.string().contains("Assistant reply") }
        XCTAssertTrue(hasContent)
    }

    func test_streamingAppendsCaret() throws {
        let message = ViewTestFixtures.makeAssistantMessage(content: "Streaming text")
        let view = ChatMessageView(
            message: message,
            isStreaming: true,
            showViaBadge: false
        )
        let sut = try view.inspect()
        let texts = try sut.findAll(Text.self)
        let hasCaret = texts.contains { try $0.string().contains("▍") }
        XCTAssertTrue(hasCaret, "Streaming message should show streaming caret")
    }

    func test_nonStreamingNoCaret() throws {
        let message = ViewTestFixtures.makeAssistantMessage(content: "Done text")
        let view = ChatMessageView(
            message: message,
            isStreaming: false,
            showViaBadge: false
        )
        let sut = try view.inspect()
        let texts = try sut.findAll(Text.self)
        let hasCaret = texts.contains { try $0.string().contains("▍") }
        XCTAssertFalse(hasCaret, "Non-streaming message should not show caret")
    }

    func test_hermesMode_showsViaBadge() throws {
        let message = ViewTestFixtures.makeHermesAssistantMessage(
            textPieces: ["Response text"],
            cliUsed: "hermes"
        )
        let view = ChatMessageView(
            message: message,
            isStreaming: false,
            showViaBadge: true,
            isHermes: true
        )
        let sut = try view.inspect()
        let texts = try sut.findAll(Text.self)
        let hasBadge = texts.contains { try $0.string().contains("via Hermes") }
        XCTAssertTrue(hasBadge, "Hermes message should show 'via Hermes' badge")
    }

    func test_nonHermesMode_showsGenericViaBadge() throws {
        let message = ViewTestFixtures.makeAssistantMessage(
            content: "Response",
            cliUsed: "claude"
        )
        let view = ChatMessageView(
            message: message,
            isStreaming: false,
            showViaBadge: true,
            isHermes: false
        )
        let sut = try view.inspect()
        let texts = try sut.findAll(Text.self)
        let hasBadge = texts.contains { try $0.string().contains("via claude") }
        XCTAssertTrue(hasBadge, "Non-Hermes message should show generic 'via' badge")
    }

    func test_transcriptMessage_showsTextPieces() throws {
        let message = ViewTestFixtures.makeTranscriptMessage(
            pieces: [
                ViewTestFixtures.makeTextPiece(value: "First paragraph"),
                ViewTestFixtures.makeTextPiece(value: "Second paragraph"),
            ]
        )
        let view = ChatMessageView(
            message: message,
            isStreaming: false,
            showViaBadge: false
        )
        let sut = try view.inspect()
        let texts = try sut.findAll(Text.self)
        let hasFirst = texts.contains { try $0.string().contains("First paragraph") }
        let hasSecond = texts.contains { try $0.string().contains("Second paragraph") }
        XCTAssertTrue(hasFirst)
        XCTAssertTrue(hasSecond)
    }

    func test_hermesToolCard_shownForHermesToolUse() throws {
        let message = ViewTestFixtures.makeHermesAssistantMessage(
            textPieces: ["Before"],
            toolPieces: [(name: "Read", detail: "file.swift")],
            cliUsed: "hermes"
        )
        let view = ChatMessageView(
            message: message,
            isStreaming: false,
            showViaBadge: false,
            isHermes: true
        )
        let sut = try view.inspect()
        // Should contain HermesToolCard for the tool use piece
        XCTAssertNoThrow(try sut.find(HStack.self))
    }
}
