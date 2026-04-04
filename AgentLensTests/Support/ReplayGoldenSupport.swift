import XCTest
import GRDB
import OpenBurnBarCore
@testable import OpenBurnBar

struct RetrievalReplayGoldenSnapshot: Codable, Equatable {
    let scenario: String
    let query: String
    let resultSourceIDs: [String]
    let topResults: [ReplayResultShape]
}

struct ReplayResultShape: Codable, Equatable {
    let rank: Int
    let sourceID: String
    let sourceKind: String
    let title: String
    let hasLexicalSignal: Bool
    let hasSemanticSignal: Bool
}

struct RetrievalDegradedFallbackGoldenSnapshot: Codable, Equatable {
    let scenario: String
    let query: String
    let resultSourceIDs: [String]
    let lexicalHealthStatus: String?
    let lexicalErrorCode: String?
    let semanticHealthStatus: String?
    let semanticErrorCode: String?
    let degradedModes: [String]
}

struct RetrievalFilterGoldenSnapshot: Codable, Equatable {
    let scenario: String
    let query: String
    let cases: [RetrievalFilterCaseSnapshot]
}

struct RetrievalFilterCaseSnapshot: Codable, Equatable {
    let name: String
    let sourceIDs: [String]
}

struct RetrievalANNBaselineGoldenSnapshot: Codable, Equatable {
    let scenario: String
    let query: String
    let annTopCandidates: [SemanticCandidateSnapshot]
    let exactTopCandidates: [SemanticCandidateSnapshot]
}

struct SemanticCandidateSnapshot: Codable, Equatable {
    let sourceID: String
    let score: Double
}

struct AuthoringReplayGoldenSnapshot: Codable, Equatable {
    let scenario: String
    let cases: [AuthoringReplayCaseSnapshot]
}

struct AuthoringReplayCaseSnapshot: Codable, Equatable {
    let name: String
    let sourceKind: String
    let operation: String
    let retrievalQuery: String
    let referenceSourceIDs: [String]
    let referenceKinds: [String]
    let hasGroundingInstruction: Bool
    let hasReferenceLabel: Bool
    let includesExistingMarkdownBlock: Bool
    let generatedHasGroundingSection: Bool
    let generatedHasReferenceCitation: Bool
}

enum OpenBurnBarReplayGoldens {
    private static let updateEnvironmentKey = "BURNBAR_UPDATE_GOLDENS"

    static func assertGolden<T: Codable & Equatable>(
        _ actual: T,
        fixtureFile: String,
        sourceFilePath: StaticString = #filePath,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let fixtureURL = makeFixtureURL(fixtureFile: fixtureFile, sourceFilePath: sourceFilePath)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let actualData = try encoder.encode(actual)

        if ProcessInfo.processInfo.environment[updateEnvironmentKey] == "1" {
            try FileManager.default.createDirectory(
                at: fixtureURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try actualData.write(to: fixtureURL, options: .atomic)
            return
        }

        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            try FileManager.default.createDirectory(
                at: fixtureURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try actualData.write(to: fixtureURL, options: .atomic)
            XCTFail(
                "Missing golden fixture at \(fixtureURL.path). Wrote a candidate fixture; re-run tests to validate.",
                file: file,
                line: line
            )
            return
        }

        let expectedData = try Data(contentsOf: fixtureURL)
        let decoder = JSONDecoder()
        let expected = try decoder.decode(T.self, from: expectedData)
        guard expected == actual else {
            let actualJSON = String(data: actualData, encoding: .utf8) ?? "<unprintable>"
            XCTFail(
                "Golden mismatch for \(fixtureFile).\nActual payload:\n\(actualJSON)",
                file: file,
                line: line
            )
            return
        }
    }

    private static func makeFixtureURL(
        fixtureFile: String,
        sourceFilePath: StaticString
    ) -> URL {
        var sourceURL = URL(fileURLWithPath: sourceFilePath.description).deletingLastPathComponent()
        while sourceURL.lastPathComponent != "AgentLensTests", sourceURL.path != "/" {
            sourceURL.deleteLastPathComponent()
        }
        return sourceURL
            .appendingPathComponent("Fixtures/ReplayGoldens", isDirectory: true)
            .appendingPathComponent(fixtureFile, isDirectory: false)
    }
}

@MainActor
final class ReplayStubSemanticCandidateProvider: SemanticCandidateProviding {
    enum StubError: Error {
        case forced
    }

    var responses: [String: [SemanticCandidate]]
    var shouldThrow = false

    init(responses: [String: [SemanticCandidate]] = [:]) {
        self.responses = responses
    }

    func semanticCandidates(for query: String, filters _: RetrievalFilters, limit: Int) async throws -> [SemanticCandidate] {
        if shouldThrow {
            throw StubError.forced
        }
        return Array((responses[query] ?? []).prefix(max(0, limit)))
    }
}

@MainActor
final class ReplayStubArtifactAuthoringTextGenerator: ArtifactAuthoringTextGenerating {
    struct Call {
        let systemPrompt: String
        let userPrompt: String
    }

    private let responses: [String]
    private var responseIndex = 0
    private(set) var calls: [Call] = []

    init(responses: [String]) {
        self.responses = responses
    }

    func generate(systemPrompt: String, userPrompt: String) async throws -> String {
        calls.append(Call(systemPrompt: systemPrompt, userPrompt: userPrompt))
        guard responses.isEmpty == false else {
            return "# Empty\n\n## Grounding\n- [R1] No response fixture configured."
        }
        let index = min(responseIndex, responses.count - 1)
        responseIndex += 1
        return responses[index]
    }
}
