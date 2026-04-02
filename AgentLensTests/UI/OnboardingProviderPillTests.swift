import XCTest
import SwiftUI
import ViewInspector
@testable import BurnBar

// MARK: - OnboardingProviderPill

@MainActor
final class OnboardingProviderPillTests: XCTestCase {

    func test_rendersForFactory() throws {
        let view = OnboardingProviderPill(
            provider: .factory,
            isSelected: false,
            isDetected: false,
            onTap: {}
        )
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Button.self))
    }

    func test_rendersForClaudeCode() throws {
        let view = OnboardingProviderPill(
            provider: .claudeCode,
            isSelected: true,
            isDetected: true,
            onTap: {}
        )
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Button.self))
    }

    func test_showsProviderDisplayName() throws {
        let view = OnboardingProviderPill(
            provider: .hermes,
            isSelected: false,
            isDetected: false,
            onTap: {}
        )
        let sut = try view.inspect()
        let text = try sut.find(Text.self).string()
        XCTAssertEqual(text, "Hermes")
    }

    func test_rendersAllProviders() {
        for provider in AgentProvider.allCases {
            let view = OnboardingProviderPill(
                provider: provider,
                isSelected: false,
                isDetected: false,
                onTap: {}
            )
            XCTAssertNotNil(view, "Failed to create pill for \(provider.displayName)")
        }
    }
}
