import XCTest
@testable import BurnBar

@MainActor
final class CursorConnectorTests: XCTestCase {

    func test_connectorProvider_defaults_comeFromCatalog() {
        XCTAssertEqual(ConnectorProvider.zai.displayName, "Z.ai")
        XCTAssertEqual(ConnectorProvider.zai.defaultBaseURL, "https://api.z.ai/api/coding/paas/v4")
        XCTAssertEqual(ConnectorProvider.zai.suggestedModels, ["glm-5-turbo", "glm-5"])

        XCTAssertEqual(ConnectorProvider.minimax.displayName, "MiniMax")
        XCTAssertEqual(ConnectorProvider.minimax.defaultBaseURL, "https://api.minimax.io/v1")
        XCTAssertEqual(ConnectorProvider.minimax.suggestedModels, ["minimax-m2.7-highspeed"])
    }

    func test_supportedModel_allowsSupportedProvidersOnly() {
        XCTAssertTrue(CursorConnectorManager.supportedModel("glm-5"))
        XCTAssertTrue(CursorConnectorManager.supportedModel("MiniMax-M2.7-highspeed"))
        XCTAssertTrue(CursorConnectorManager.supportedModel("MiniMax-M3-pro"))
        XCTAssertFalse(CursorConnectorManager.supportedModel("kimi-for-coding"))
        XCTAssertFalse(CursorConnectorManager.supportedModel("pony-alpha-2"))
        XCTAssertFalse(CursorConnectorManager.supportedModel("claude-3-7-sonnet"))
        XCTAssertFalse(CursorConnectorManager.supportedModel(""))
    }

    func test_supportedModel_respectsProviderCatalogMatchers() {
        XCTAssertTrue(CursorConnectorManager.supportedModel("glm-5-plus", provider: .zai))
        XCTAssertTrue(CursorConnectorManager.supportedModel("MiniMax-M3-pro", provider: .minimax))
        XCTAssertFalse(CursorConnectorManager.supportedModel("MiniMax-M3-pro", provider: .zai))
    }

    func test_modelPricing_usesCatalogWithSharedFallback() {
        let zaiPricing = ModelPricing.lookup(model: "glm-5")
        XCTAssertEqual(zaiPricing.inputPerMToken, 0.07, accuracy: 0.001)
        XCTAssertEqual(zaiPricing.outputPerMToken, 0.07, accuracy: 0.001)

        let fallbackPricing = ModelPricing.lookup(model: "unknown-model")
        XCTAssertEqual(fallbackPricing.inputPerMToken, 2.5, accuracy: 0.001)
        XCTAssertEqual(fallbackPricing.outputPerMToken, 10, accuracy: 0.001)
        XCTAssertEqual(fallbackPricing.cacheReadPerMToken, 1.25, accuracy: 0.001)
    }

    func test_exposedModels_deduplicatesSelectionAndCustomValues() {
        let config = ConnectorProviderConfig(
            id: .zai,
            enabled: true,
            selectedModels: ["glm-5", "glm-5-turbo", "glm-5"],
            customModels: ["glm-5-turbo", "glm-5-plus"]
        )

        XCTAssertEqual(config.exposedModels, ["glm-5", "glm-5-turbo", "glm-5-plus"])
    }

    func test_cursorConnectorConfig_onlyIncludesEnabledProviders() {
        let config = CursorConnectorConfig(
            providerConfigs: [
                ConnectorProviderConfig(
                    id: .zai,
                    enabled: true,
                    selectedModels: ["glm-5"],
                    customModels: ["glm-5-turbo"]
                ),
                ConnectorProviderConfig(
                    id: .minimax,
                    enabled: false,
                    selectedModels: ["MiniMax-M2.7-highspeed"]
                )
            ]
        )

        XCTAssertEqual(config.exposedModels, ["glm-5", "glm-5-turbo"])
    }

    func test_normalizeUsageEvent_includesCacheCreationTokensInTotals() {
        let normalized = CursorConnectorManager.normalizeUsageEvent([
            "prompt_tokens": 120,
            "completion_tokens": 80,
            "cache_creation_input_tokens": 40,
            "cache_read_input_tokens": 20,
            "total_tokens": 260
        ])

        XCTAssertEqual(normalized.promptTokens, 120)
        XCTAssertEqual(normalized.completionTokens, 80)
        XCTAssertEqual(normalized.cacheCreationTokens, 40)
        XCTAssertEqual(normalized.cacheReadTokens, 20)
        XCTAssertEqual(normalized.totalTokens, 260)
    }

    func test_normalizeUsageEvent_backfillsPromptAndCompletionAfterCacheOverhead() {
        let normalized = CursorConnectorManager.normalizeUsageEvent([
            "cacheCreationTokens": 50,
            "cacheReadTokens": 25,
            "totalTokens": 275,
            "input_char_estimate": 620,
            "output_char_estimate": 310
        ])

        XCTAssertEqual(normalized.cacheCreationTokens, 50)
        XCTAssertEqual(normalized.cacheReadTokens, 25)
        XCTAssertEqual(normalized.promptTokens + normalized.completionTokens, 200)
        XCTAssertEqual(normalized.totalTokens, 275)
    }
}
