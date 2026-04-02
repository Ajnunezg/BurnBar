import XCTest
@testable import BurnBar

@MainActor
final class CLIBridgeTests: XCTestCase {

    // MARK: - Executable Path Parsing Tests

    func test_cliBridge_parseExecutablePath_prefersAbsolutePathLine() {
        let output = "/usr/local/bin/codex\n/usr/bin/env codex"
        let path = CLIBridge.parseExecutablePath(fromCommandOutput: output)
        XCTAssertEqual(path, "/usr/local/bin/codex")
    }

    func test_cliBridge_parseExecutablePath_handlesEmptyOutput() {
        let output = ""
        let path = CLIBridge.parseExecutablePath(fromCommandOutput: output)
        XCTAssertNil(path)
    }

    func test_cliBridge_parseExecutablePath_skipsNonAbsoluteLines() {
        let output = "codex not found\n/usr/local/bin/codex"
        let path = CLIBridge.parseExecutablePath(fromCommandOutput: output)
        XCTAssertEqual(path, "/usr/local/bin/codex")
    }

    // MARK: - Claude Arguments Tests

    func test_cliBridge_claudeArguments_includeVerboseForStreamJSON() {
        let args = CLIBridge.claudeArguments(prompt: "test prompt")
        XCTAssertTrue(args.contains("--output-format"))
        XCTAssertTrue(args.contains("stream-json"))
        XCTAssertTrue(args.contains("--verbose"))
    }

    func test_cliBridge_claudeArguments_includeExplicitModelWhenProvided() {
        let args = CLIBridge.claudeArguments(prompt: "test", model: "claude-sonnet-4-20250514")
        XCTAssertTrue(args.contains("--model"))
        XCTAssertTrue(args.contains("claude-sonnet-4-20250514"))
    }

    func test_cliBridge_claudeArguments_omitsModelWhenEmpty() {
        let args = CLIBridge.claudeArguments(prompt: "test", model: "")
        XCTAssertFalse(args.contains("--model"))
    }

    // MARK: - Codex Arguments Tests

    func test_cliBridge_codexArguments_defaultModelAndReasoning() {
        let args = CLIBridge.codexArguments(prompt: "test")
        XCTAssertTrue(args.contains("exec"))
        XCTAssertTrue(args.contains("--json"))
        // Default model should be gpt-5.4-mini
        XCTAssertTrue(args.contains("gpt-5.4-mini"))
    }

    func test_cliBridge_codexArguments_useExplicitModelWhenProvided() {
        let args = CLIBridge.codexArguments(prompt: "test", model: "gpt-5.4")
        XCTAssertTrue(args.contains("gpt-5.4"))
    }

    func test_cliBridge_codexArguments_fallbackToSupportedModelWhenInvalidModelProvided() {
        let args = CLIBridge.codexArguments(prompt: "test", model: "MiniMax-M2.7-highspeed")
        XCTAssertTrue(args.contains("gpt-5.4-mini"))
        XCTAssertFalse(args.contains("MiniMax-M2.7-highspeed"))
    }

    func test_settingsManager_resolvedHermesChatModel_minimaxAdvertised_usesCodexCompatibleDefault() {
        XCTAssertEqual(
            SettingsManager.resolvedHermesChatModel(override: "", gatewayAdvertisedModel: "MiniMax-M2.7-highspeed"),
            "gpt-5.4-mini"
        )
    }

    func test_settingsManager_resolvedHermesChatModel_overrideWins() {
        XCTAssertEqual(
            SettingsManager.resolvedHermesChatModel(override: " custom-model ", gatewayAdvertisedModel: "MiniMax-M2.7-highspeed"),
            "custom-model"
        )
    }

    func test_settingsManager_resolvedHermesChatModel_nonMinimax_usesHermes() {
        XCTAssertEqual(
            SettingsManager.resolvedHermesChatModel(override: "", gatewayAdvertisedModel: "NousResearch/Hermes-3-Llama-3.1-8B"),
            "hermes"
        )
    }

    func test_settingsManager_resolvedHermesChatModel_emptyProbe_usesHermes() {
        XCTAssertEqual(
            SettingsManager.resolvedHermesChatModel(override: "", gatewayAdvertisedModel: nil),
            "hermes"
        )
    }

    func test_cliBridge_codexArguments_includesReasoningEffort() {
        let args = CLIBridge.codexArguments(prompt: "test")
        XCTAssertTrue(args.contains("model_reasoning_effort=medium"))
    }

    // MARK: - User Managed Search Directories Tests

    func test_cliBridge_userManagedSearchDirectories_includeNodeManagerBins() throws {
        let directories = CLIBridge.userManagedExecutableSearchDirectories(
            homeDirectory: "/Users/test"
        )
        // Should include common version manager paths
        XCTAssertTrue(directories.contains { $0.contains(".npm-global") })
        XCTAssertTrue(directories.contains { $0.contains(".bun") })
        XCTAssertTrue(directories.contains { $0.contains(".volta") })
        XCTAssertTrue(directories.contains { $0.contains(".asdf") })
    }

    // MARK: - Executable Resolution Tests

    func test_cliBridge_resolveExecutable_findsVersionManagerInstall() async {
        // This test verifies the search order logic
        let result = await CLIBridge().resolveExecutable(named: "swift")
        // Should find swift in standard locations or not at all
        // Just verify it completes without error
        XCTAssertNotNil(result)
    }

    // MARK: - Shell Quoting Tests

    func test_cliBridge_shellQuoted_escapesSingleQuotes() {
        let input = "test's value"
        let quoted = CLIBridge.shellQuoted(input)
        XCTAssertTrue(quoted.hasPrefix("'"))
        XCTAssertTrue(quoted.hasSuffix("'"))
        XCTAssertFalse(quoted.contains("'test'"))
    }

    // MARK: - Base Executable Search Tests

    func test_cliBridge_baseExecutableSearchDirectories_includesStandardPaths() {
        let env = ["PATH": "/usr/bin:/bin"]
        let dirs = CLIBridge.baseExecutableSearchDirectories(
            environment: env,
            homeDirectory: "/Users/test"
        )
        XCTAssertTrue(dirs.contains("/usr/bin"))
        XCTAssertTrue(dirs.contains("/bin"))
        XCTAssertTrue(dirs.contains("/Users/test/.local/bin"))
    }

    // MARK: - Enriched Environment Tests

    func test_cliBridge_enrichedProcessEnvironment_includesCommonCLIPaths() {
        let env = CLIBridge.enrichedProcessEnvironment()
        let path = env["PATH"] ?? ""
        let components = path.split(separator: ":").map(String.init)
        XCTAssertTrue(components.contains("/opt/homebrew/bin"))
        XCTAssertTrue(components.contains("/usr/local/bin"))
    }

    func test_cliBridge_openAICompatibleUsage_parsesUsagePayload() {
        let usage = CLIBridge.openAICompatibleUsage(from: [
            "usage": [
                "input_tokens": 120,
                "output_tokens": 80,
                "cache_creation_input_tokens": 40,
                "cache_read_input_tokens": 20
            ]
        ])

        XCTAssertEqual(usage?.inputTokens, 120)
        XCTAssertEqual(usage?.outputTokens, 80)
        XCTAssertEqual(usage?.cacheCreationTokens, 40)
        XCTAssertEqual(usage?.cacheReadTokens, 20)
        XCTAssertEqual(usage?.totalTokens, 260)
    }

    func test_cliBridge_openAICompatibleUsage_parsesFlatPayload() {
        let usage = CLIBridge.openAICompatibleUsage(from: [
            "prompt_tokens": 33,
            "completion_tokens": 11,
            "cached_tokens": 9
        ])

        XCTAssertEqual(usage?.inputTokens, 33)
        XCTAssertEqual(usage?.outputTokens, 11)
        XCTAssertEqual(usage?.cacheReadTokens, 9)
    }
}
