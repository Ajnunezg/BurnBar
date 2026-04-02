import XCTest
@testable import AgentLens

final class FactoryDroidParserTests: XCTestCase {
    func testParseEmptyDirectory() async throws {
        let parser = FactoryDroidParser()
        let result = try await parser.parse()
        XCTAssertTrue(result.usages.isEmpty)
        XCTAssertTrue(result.conversations.isEmpty)
    }
    
    func testProviderReturnsCorrectValue() {
        let parser = FactoryDroidParser()
        XCTAssertEqual(parser.provider, .factory)
    }
}
