import XCTest
import ViewInspector
@testable import BurnBar

// MARK: - AppLogoView

@MainActor
final class AppLogoViewTests: XCTestCase {

    func test_rendersWithDefaultSize() throws {
        let view = AppLogoView()
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Image.self))
    }

    func test_rendersWithCustomSize() throws {
        let view = AppLogoView(size: 48)
        let sut = try view.inspect()
        let frame = try sut.find(Image.self).frame()
        XCTAssertEqual(frame.width, 48)
        XCTAssertEqual(frame.height, 48)
    }

    func test_defaultSizeIs24() throws {
        let view = AppLogoView()
        let sut = try view.inspect()
        let frame = try sut.find(Image.self).frame()
        XCTAssertEqual(frame.width, 24)
        XCTAssertEqual(frame.height, 24)
    }
}
