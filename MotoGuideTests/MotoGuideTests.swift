import XCTest
@testable import MotoGuide

final class MotoGuideTests: XCTestCase {
    func testContentModesIncludeShortFactsAndQuiet() {
        let modes = Set(ContentMode.allCases.map(\.rawValue))
        XCTAssertTrue(modes.contains("shortFacts"))
        XCTAssertTrue(modes.contains("quiet"))
        XCTAssertTrue(modes.contains("natural"))
    }
}
