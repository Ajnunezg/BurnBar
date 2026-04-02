import XCTest
@testable import AgentLens

final class ClaudeCodeParserTests: XCTestCase {
    func testParseEmptyDirectory() async throws {
        let parser = ClaudeCodeParser()
        let result = try await parser.parse()
        XCTAssertTrue(result.usages.isEmpty)
        XCTAssertTrue(result.conversations.isEmpty)
    }
    
    func testProviderReturnsCorrectValue() {
        let parser = ClaudeCodeParser()
        XCTAssertEqual(parser.provider, .claudeCode)
    }
}
