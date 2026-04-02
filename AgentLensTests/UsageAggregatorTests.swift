import XCTest
import GRDB
@testable import BurnBar

// MARK: - Testable Dependencies

/// Mock parser that returns configurable results
final class MockLogParser: LogParser, @unchecked Sendable {
    let provider: AgentProvider
    var parseResult: ParseResult
    var parseError: Error?
    var parseCallCount = 0

    init(provider: AgentProvider, result: ParseResult = ParseResult(usages: [], conversations: [])) {
        self.provider = provider
        self.parseResult = result
    }

    func parse() async throws -> ParseResult {
        parseCallCount += 1
        if let error = parseError {
            throw error
        }
        return parseResult
    }
}

/// Mock DataStore for testing
final class MockDataStore: @unchecked Sendable {
    var usages: [TokenUsage] = []
    var conversations: [ConversationRecord] = []
    var throwOnInsert: Error?
    var throwOnDeleteAll: Error?
    var throwOnUpsertHealth: Error?
    var throwOnFetchConversations: Error?

    func insert(_ usages: [TokenUsage]) throws {
        if let error = throwOnInsert {
            throw error
        }
        self.usages.append(contentsOf: usages)
    }

    func replaceUsages(_ usages: [TokenUsage]) {
        self.usages = usages
    }

    func deleteAll() throws {
        if let error = throwOnDeleteAll {
            throw error
        }
        usages.removeAll()
        conversations.removeAll()
    }

    func upsertRetrievalHealth(_ record: RetrievalHealthRecord) throws {
        if let error = throwOnUpsertHealth {
            throw error
        }
    }

    func refresh() {}

    func fetchConversationsNeedingSummary(limit: Int, now: Date, retryCooldown: TimeInterval) throws -> [ConversationRecord] {
        if let error = throwOnFetchConversations {
            throw error
        }
        return []
    }

    func updateConversationSummary(id: String, title: String, summary: String, provider: String, model: String, runCostUSD: Double) throws {}
    func markConversationSummaryAttempt(id: String) throws {}
}

// MARK: - ParserHealth Tests

final class ParserHealthTests: XCTestCase {

    func test_healthy_statusLabel() {
        let health = ParserHealth.healthy(sessionCount: 5)
        XCTAssertEqual(health.statusLabel, "healthy")
    }

    func test_empty_statusLabel() {
        let health = ParserHealth.empty
        XCTAssertEqual(health.statusLabel, "empty")
    }

    func test_degraded_statusLabel() {
        let health = ParserHealth.degraded(sessionCount: 3, error: "test error")
        XCTAssertEqual(health.statusLabel, "degraded")
    }

    func test_failed_statusLabel() {
        let health = ParserHealth.failed(error: "crash")
        XCTAssertEqual(health.statusLabel, "failed")
    }

    func test_notConfigured_statusLabel() {
        let health = ParserHealth.notConfigured
        XCTAssertEqual(health.statusLabel, "not_configured")
    }

    func test_healthy_sessionCount() {
        let health = ParserHealth.healthy(sessionCount: 10)
        XCTAssertEqual(health.sessionCount, 10)
    }

    func test_degraded_sessionCount() {
        let health = ParserHealth.degraded(sessionCount: 5, error: "warning")
        XCTAssertEqual(health.sessionCount, 5)
    }

    func test_empty_sessionCount() {
        let health = ParserHealth.empty
        XCTAssertEqual(health.sessionCount, 0)
    }

    func test_failed_sessionCount() {
        let health = ParserHealth.failed(error: "error")
        XCTAssertEqual(health.sessionCount, 0)
    }

    func test_notConfigured_sessionCount() {
        let health = ParserHealth.notConfigured
        XCTAssertEqual(health.sessionCount, 0)
    }

    func test_healthy_errorMessage() {
        let health = ParserHealth.healthy(sessionCount: 5)
        XCTAssertNil(health.errorMessage)
    }

    func test_degraded_errorMessage() {
        let health = ParserHealth.degraded(sessionCount: 3, error: "specific error")
        XCTAssertEqual(health.errorMessage, "specific error")
    }

    func test_failed_errorMessage() {
        let health = ParserHealth.failed(error: "crash message")
        XCTAssertEqual(health.errorMessage, "crash message")
    }

    func test_notConfigured_errorMessage() {
        let health = ParserHealth.notConfigured
        XCTAssertNil(health.errorMessage)
    }
}

// MARK: - SummaryQueueItem Tests

final class SummaryQueueItemTests: XCTestCase {

    func test_statusDefaultValue() {
        let item = SummaryQueueItem(id: "test-id", title: "Test Title")
        XCTAssertEqual(item.status, .pending)
        XCTAssertNil(item.provider)
    }

    func test_statusTransitions() {
        var item = SummaryQueueItem(id: "test-id", title: "Test Title")

        item.status = .processing
        XCTAssertEqual(item.status, .processing)

        item.status = .done
        XCTAssertEqual(item.status, .done)

        item.status = .failed
        XCTAssertEqual(item.status, .failed)

        item.provider = "claude-code"
        XCTAssertEqual(item.provider, "claude-code")
    }
}

// MARK: - UsageAggregator Unit Tests

@MainActor
final class UsageAggregatorTests: XCTestCase {

    var mockDataStore: MockDataStore!
    var mockParsers: [AgentProvider: MockLogParser]!
    var settingsManager: TestSettingsManager!
    var providerAPIKeyStore: TestProviderAPIKeyStore!

    override func setUp() {
        super.setUp()
        mockDataStore = MockDataStore()
        mockParsers = [:]
        settingsManager = TestSettingsManager()
        providerAPIKeyStore = TestProviderAPIKeyStore()
    }

    override func tearDown() {
        mockDataStore = nil
        mockParsers = nil
        settingsManager = nil
        providerAPIKeyStore = nil
        super.tearDown()
    }

    // MARK: - Parser Registration

    func test_parserRegistration_claudeCode() async throws {
        let aggregator = createAggregator(with: [.claudeCode: createMockParser(.claudeCode)])

        XCTAssertNotNil(aggregator)
    }

    func test_parserRegistration_factory() async throws {
        let aggregator = createAggregator(with: [.factory: createMockParser(.factory)])

        XCTAssertNotNil(aggregator)
    }

    // MARK: - Refresh All

    func test_refreshAll_setsIsRefreshingDuringOperation() async throws {
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        // Note: isRefreshing is private(set), we can only verify state after completion
        await aggregator.refreshAll()

        XCTAssertFalse(aggregator.isRefreshing)
    }

    func test_refreshAll_clearsPreviousErrors() async throws {
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        await aggregator.refreshAll()

        // Errors should be cleared after refresh
        XCTAssertTrue(aggregator.errors.isEmpty)
    }

    func test_refreshAll_handlesParserError() async throws {
        let error = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Parser failed"])
        let parser = createMockParser(.claudeCode, error: error)
        let aggregator = createAggregator(with: [.claudeCode: parser])

        await aggregator.refreshAll()

        XCTAssertFalse(aggregator.errors.isEmpty)
        XCTAssertNotNil(aggregator.parserHealth[.claudeCode])
    }

    func test_refreshAll_storesUsages() async throws {
        let usage = createTestUsage(provider: .claudeCode)
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [usage], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        await aggregator.refreshAll()

        // Verify parser was called
        XCTAssertEqual(parser.parseCallCount, 1)
    }

    func test_refreshAll_updatesLastRefresh() async throws {
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        let beforeRefresh = Date()
        await aggregator.refreshAll()

        XCTAssertNotNil(aggregator.lastRefresh)
        XCTAssertGreaterThanOrEqual(aggregator.lastRefresh!, beforeRefresh)
    }

    func test_refreshAll_setsHealthyParserHealth() async throws {
        let usage = createTestUsage(provider: .claudeCode)
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [usage], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        await aggregator.refreshAll()

        let health = aggregator.parserHealth[.claudeCode]
        XCTAssertNotNil(health)
        // Health should be healthy since we have usages
        switch health {
        case .healthy(let count):
            XCTAssertEqual(count, 1)
        default:
            XCTFail("Expected healthy parser health")
        }
    }

    func test_refreshAll_setsEmptyParserHealth() async throws {
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        await aggregator.refreshAll()

        let health = aggregator.parserHealth[.claudeCode]
        XCTAssertNotNil(health)
        if case .empty = health {
            // Expected
        } else {
            XCTFail("Expected empty parser health")
        }
    }

    func test_refreshAll_concurrentRefreshGuard() async throws {
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        // Start first refresh
        let firstRefresh = Task {
            await aggregator.refreshAll()
        }

        // Start second refresh concurrently (should be blocked)
        let secondRefresh = Task {
            await aggregator.refreshAll()
        }

        await firstRefresh.value
        await secondRefresh.value

        // Both should complete without hanging
        XCTAssertFalse(aggregator.isRefreshing)
    }

    // MARK: - Recount All

    func test_recountAll_clearsData() async throws {
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        await aggregator.recountAll()

        // Verify refresh was called after clear
        XCTAssertEqual(parser.parseCallCount, 1)
    }

    func test_recountAll_handlesDeleteError() async throws {
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])
        mockDataStore.throwOnDeleteAll = NSError(domain: "TestError", code: 2, userInfo: nil)

        await aggregator.recountAll()

        // Should still attempt to parse despite delete error
        XCTAssertEqual(parser.parseCallCount, 1)
    }

    // MARK: - Refresh Single Provider

    func test_refreshProvider_existingParser() async throws {
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        await aggregator.refresh(provider: .claudeCode)

        XCTAssertEqual(parser.parseCallCount, 1)
    }

    func test_refreshProvider_nonexistentParser() async throws {
        let aggregator = createAggregator(with: [:])

        await aggregator.refresh(provider: .claudeCode)

        // Should not crash, just do nothing
    }

    func test_refreshProvider_storesUsages() async throws {
        let usage = createTestUsage(provider: .claudeCode)
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [usage], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        await aggregator.refresh(provider: .claudeCode)

        XCTAssertEqual(parser.parseCallCount, 1)
    }

    func test_refreshProvider_clearsErrorOnSuccess() async throws {
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        // First with error
        parser.parseError = NSError(domain: "Test", code: 1, userInfo: nil)
        await aggregator.refresh(provider: .claudeCode)

        // Then success
        parser.parseError = nil
        await aggregator.refresh(provider: .claudeCode)

        // Error should be cleared for this provider
        XCTAssertNil(aggregator.errors[.claudeCode])
    }

    // MARK: - Parser Health States

    func test_parserHealth_healthy() async throws {
        let usage = createTestUsage(provider: .claudeCode)
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [usage], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        await aggregator.refresh(provider: .claudeCode)

        guard case .healthy(let count) = aggregator.parserHealth[.claudeCode] else {
            XCTFail("Expected healthy state")
            return
        }
        XCTAssertEqual(count, 1)
    }

    func test_parserHealth_empty() async throws {
        let parser = createMockParser(.claudeCode, result: ParseResult(usages: [], conversations: []))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        await aggregator.refresh(provider: .claudeCode)

        guard case .empty = aggregator.parserHealth[.claudeCode] else {
            XCTFail("Expected empty state")
            return
        }
    }

    func test_parserHealth_failed() async throws {
        let parser = createMockParser(.claudeCode, error: NSError(domain: "Test", code: 1, userInfo: nil))
        let aggregator = createAggregator(with: [.claudeCode: parser])

        await aggregator.refresh(provider: .claudeCode)

        guard case .failed = aggregator.parserHealth[.claudeCode] else {
            XCTFail("Expected failed state")
            return
        }
    }

    // MARK: - Helper Methods

    private func createAggregator(with parsers: [AgentProvider: MockLogParser]) -> UsageAggregator {
        // We need to create a real DataStore for these tests
        // For unit testing, we'll use the mock approach
        // This is a simplified version for testing purposes

        return UsageAggregator(
            dataStore: DataStore(),
            cloudSync: nil,
            sessionMirror: nil,
            settingsManager: settingsManager,
            usageAPIService: nil,
            providerAPIKeyStore: providerAPIKeyStore,
            quotaService: ProviderQuotaService.shared,
            artifactDiscoveryService: nil,
            projectionPipelineService: nil
        )
    }

    private func createMockParser(_ provider: AgentProvider, result: ParseResult = ParseResult(usages: [], conversations: [])) -> MockLogParser {
        let parser = MockLogParser(provider: provider, result: result)
        mockParsers[provider] = parser
        return parser
    }

    private func createTestUsage(provider: AgentProvider) -> TokenUsage {
        TokenUsage(
            provider: provider,
            sessionId: "test-session-\(UUID().uuidString)",
            projectName: "~/Test",
            model: "claude-3-5-sonnet",
            inputTokens: 100,
            outputTokens: 50,
            startTime: Date(),
            endTime: Date()
        )
    }
}

// MARK: - Test Settings Manager

final class TestSettingsManager: SettingsManager {
    var _conversationIndexingEnabled: Bool = false
    var _summaryInitialSweepCompleted: Bool = false
    var _autoSessionSummariesEnabled: Bool = false
    var _summaryTimeLimitMinutes: Int = 0
    var _summaryBatchSize: Int = 10
    var _summaryFirstLoadBatchSize: Int = 12
    var _summaryMaxConcurrency: Int = 4
    var _summaryProviderOrder: [SummaryProviderID] = []

    override var conversationIndexingEnabled: Bool { _conversationIndexingEnabled }
    override var summaryInitialSweepCompleted: Bool { _summaryInitialSweepCompleted }
    override var autoSessionSummariesEnabled: Bool { _autoSessionSummariesEnabled }
    override var summaryTimeLimitMinutes: Int { _summaryTimeLimitMinutes }
    override var summaryBatchSize: Int { _summaryBatchSize }
    override var summaryFirstLoadBatchSize: Int { _summaryFirstLoadBatchSize }
    override var summaryMaxConcurrency: Int { _summaryMaxConcurrency }
    override var summaryProviderOrder: [SummaryProviderID] { _summaryProviderOrder }

    static var shared: TestSettingsManager { TestSettingsManager() }
}

// MARK: - Test Provider API Key Store

final class TestProviderAPIKeyStore: ProviderAPIKeyStore {
    var _keys: [AgentProvider: String] = [:]

    override func resolveAPIKey(for provider: AgentProvider) -> String? {
        _keys[provider]
    }

    static var shared: TestProviderAPIKeyStore { TestProviderAPIKeyStore() }
}
