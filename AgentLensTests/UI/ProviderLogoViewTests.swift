import XCTest
import ViewInspector
@testable import BurnBar

// MARK: - ProviderLogoView

@MainActor
final class ProviderLogoViewTests: XCTestCase {

    func test_rendersForProviderWithLogoURL() throws {
        let providersWithURL = AgentProvider.allCases.filter { $0.logoURL != nil }
        XCTAssertFalse(providersWithURL.isEmpty, "At least some providers should have logo URLs")

        for provider in providersWithURL {
            let view = ProviderLogoView(provider: provider, size: 32)
            let sut = try view.inspect()
            XCTAssertNoThrow(try sut.find(Group.self), "Failed for \(provider.displayName)")
        }
    }

    func test_rendersForProviderWithoutLogoURL() throws {
        let providersWithoutURL = AgentProvider.allCases.filter { $0.logoURL == nil }
        XCTAssertFalse(providersWithoutURL.isEmpty, "At least some providers should lack logo URLs")

        for provider in providersWithoutURL {
            let view = ProviderLogoView(provider: provider, size: 32, useFallbackColor: true)
            let sut = try view.inspect()
            XCTAssertNoThrow(try sut.find(Group.self), "Failed for \(provider.displayName)")
        }
    }

    func test_respectsCustomSize() throws {
        let view = ProviderLogoView(provider: .aider, size: 48)
        let sut = try view.inspect()
        let frame = try sut.find(Group.self).frame()
        XCTAssertEqual(frame.width, 48)
        XCTAssertEqual(frame.height, 48)
    }

    func test_defaultSize() throws {
        let view = ProviderLogoView(provider: .aider)
        let sut = try view.inspect()
        let frame = try sut.find(Group.self).frame()
        XCTAssertEqual(frame.width, 24)
        XCTAssertEqual(frame.height, 24)
    }

    func test_allProvidersHaveIconNames() {
        for provider in AgentProvider.allCases {
            XCTAssertFalse(provider.iconName.isEmpty, "\(provider.displayName) has empty iconName")
        }
    }

    func test_allProvidersHaveDisplayNames() {
        for provider in AgentProvider.allCases {
            XCTAssertFalse(provider.displayName.isEmpty, "Provider has empty displayName")
        }
    }
}
