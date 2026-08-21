import XCTest
@testable import RideHorizon

final class RideHorizonTests: XCTestCase {
    func testOnboardingSafetyCopyRequiresStoppedSetupAndNoInteractionWhileMoving() {
        let copy = RiderSafetyCopy.onboarding.lowercased()

        XCTAssertTrue(copy.contains("stopped"))
        XCTAssertTrue(copy.contains("do not interact"))
        XCTAssertTrue(copy.contains("moving"))
        XCTAssertTrue(copy.contains("distracting"))
    }

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

    func testLongFactsRemainCompatibleWithExistingAppBoundWithoutChangingShortOrNamesOnly() {
        XCTAssertEqual(FactMode.longFacts.maxFactLength, 1_500)
        XCTAssertEqual(FactMode.shortFacts.maxFactLength, 1_100)
        XCTAssertEqual(ContentMode.shortFacts.factMode, .shortFacts)
        XCTAssertNil(ContentMode.namesOnly.factMode)
    }
}
