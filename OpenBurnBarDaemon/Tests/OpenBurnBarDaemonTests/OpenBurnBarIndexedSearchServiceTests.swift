import OpenBurnBarCore
@testable import OpenBurnBarDaemon
import XCTest

final class BurnBarIndexedSearchServiceTests: XCTestCase {
    func test_shouldPerformSemanticSearch_skipsLookupPrecisionQueries() {
        let request = BurnBarSearchQueryRequest(
            query: "Xiomara",
            resultLimit: 5,
            queryEmbedding: [0.1, 0.2, 0.3],
            embeddingDimension: 3,
            embeddingDistanceMetric: .cosine
        )
        let plan = BurnBarSearchPlan.plan(userText: request.query)

        XCTAssertFalse(
            BurnBarIndexedSearchService.shouldPerformSemanticSearch(
                plan: plan,
                query: request,
                semanticEnabled: true
            )
        )
    }

    func test_shouldPerformSemanticSearch_allowsBroaderQueriesWithEmbeddings() {
        let request = BurnBarSearchQueryRequest(
            query: "employee onboarding playbook",
            resultLimit: 5,
            queryEmbedding: [0.1, 0.2, 0.3],
            embeddingDimension: 3,
            embeddingDistanceMetric: .cosine
        )
        let plan = BurnBarSearchPlan.plan(userText: request.query)

        XCTAssertTrue(
            BurnBarIndexedSearchService.shouldPerformSemanticSearch(
                plan: plan,
                query: request,
                semanticEnabled: true
            )
        )
    }
}
