import XCTest
@testable import RideHorizon

final class RideHorizonTests: XCTestCase {
    func testContentModesIncludeShortFactsLongFactsAndQuiet() {
        let modes = Set(ContentMode.allCases.map(\.rawValue))
        XCTAssertTrue(modes.contains("shortFacts"))
        XCTAssertTrue(modes.contains("longFacts"))
        XCTAssertTrue(modes.contains("quiet"))
        XCTAssertTrue(modes.contains("natural"))
    }

    func testOnlyFactModesCallProxy() {
        XCTAssertEqual(ContentMode.shortFacts.factMode, .shortFacts)
        XCTAssertEqual(ContentMode.longFacts.factMode, .longFacts)
        XCTAssertNil(ContentMode.natural.factMode)
        XCTAssertNil(ContentMode.namesOnly.factMode)
        XCTAssertNil(ContentMode.quiet.factMode)
    }
}
