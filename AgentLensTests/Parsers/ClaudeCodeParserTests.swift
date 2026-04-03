import XCTest
@testable import BurnBar

final class ClaudeCodeParserTests: XCTestCase {
    func testParseEmptyDirectory() async throws {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("burnbar-claude-parser-tests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let parser = TestableClaudeCodeParser(testProjectsPath: tempRoot)
        let result = try await parser.parse()
        XCTAssertTrue(result.usages.isEmpty)
        XCTAssertTrue(result.conversations.isEmpty)
    }
    
    func testProviderReturnsCorrectValue() {
        let parser = ClaudeCodeParser()
        XCTAssertEqual(parser.provider, .claudeCode)
    }
}
