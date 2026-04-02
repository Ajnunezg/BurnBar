import XCTest
import ViewInspector
@testable import BurnBar

// MARK: - MiniSparkline

@MainActor
final class MiniSparklineTests: XCTestCase {

    func test_rendersWithEmptyData() throws {
        let view = MiniSparkline(data: [])
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Chart.self))
    }

    func test_rendersWithSinglePoint() throws {
        let view = MiniSparkline(data: [1.0])
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Chart.self))
    }

    func test_rendersWithMultiplePoints() throws {
        let view = MiniSparkline(data: [1.0, 2.0, 3.0, 4.0, 5.0])
        let sut = try view.inspect()
        XCTAssertNoThrow(try sut.find(Chart.self))
    }

    func test_respectsCustomDimensions() throws {
        let view = MiniSparkline(data: [1.0], width: 100, height: 50)
        let sut = try view.inspect()
        let frame = try sut.find(Chart.self).frame()
        XCTAssertEqual(frame.width, 100)
        XCTAssertEqual(frame.height, 50)
    }

    func test_respectsDefaultDimensions() throws {
        let view = MiniSparkline(data: [1.0])
        let sut = try view.inspect()
        let frame = try sut.find(Chart.self).frame()
        XCTAssertEqual(frame.width, 60)
        XCTAssertEqual(frame.height, 20)
    }
}
