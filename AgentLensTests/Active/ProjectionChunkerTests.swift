import XCTest
import GRDB
import OpenBurnBarCore
@testable import OpenBurnBar
final class ProjectionChunkerTests: XCTestCase {
    func test_chunker_isDeterministicForSameInput() {
        let text = """
        # Title
        Intro paragraph.

        ## Section A
        \(String(repeating: "Alpha beta gamma. ", count: 120))

        ## Section B
        \(String(repeating: "Delta epsilon zeta. ", count: 120))
        """

        let chunker = ProjectionChunker(maxChunkCharacters: 280, minChunkCharacters: 160, overlapCharacters: 40, maxChunksPerDocument: 32)
        let createdAt = Date(timeIntervalSince1970: 1_742_600_000)
        let first = chunker.makeChunks(
            text: text,
            sourceKind: .agentDoc,
            sourceID: "artifact-1",
            sourceVersionID: "version-1",
            documentID: "doc-1",
            createdAt: createdAt
        )
        let second = chunker.makeChunks(
            text: text,
            sourceKind: .agentDoc,
            sourceID: "artifact-1",
            sourceVersionID: "version-1",
            documentID: "doc-1",
            createdAt: createdAt
        )

        XCTAssertEqual(first.count, second.count)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(first.map(\.startOffset), second.map(\.startOffset))
        XCTAssertEqual(first.map(\.endOffset), second.map(\.endOffset))
        XCTAssertEqual(first.map(\.sectionPath), second.map(\.sectionPath))
        XCTAssertEqual(first.map(\.text), second.map(\.text))
    }
}

