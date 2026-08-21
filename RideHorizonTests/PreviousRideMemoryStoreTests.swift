import XCTest
@testable import RideHorizon

final class PreviousRideMemoryStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "PreviousRideMemoryStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testCompletingFirstRidePersistsCompactDeliveredFactContent() throws {
        let store = PreviousRideMemoryStore(defaults: defaults)
        let endedAt = Date(timeIntervalSince1970: 1_787_310_000)

        store.completeRide(
            deliveredFacts: [
                "  The wool trade shaped the town's steep streets.  ",
                "Its canal once carried coal and cloth."
            ],
            endedAt: endedAt
        )

        let summary = try XCTUnwrap(store.summaries.first)
        XCTAssertEqual(store.summaries.count, 1)
        XCTAssertEqual(summary.endedAt, endedAt)
        XCTAssertEqual(
            summary.content,
            "The wool trade shaped the town's steep streets. Its canal once carried coal and cloth."
        )
    }

    func testCompletingFourthRideRetainsLatestThreeInOrder() {
        let store = PreviousRideMemoryStore(defaults: defaults)

        for index in 1...4 {
            store.completeRide(
                deliveredFacts: ["Delivered fact \(index)."],
                endedAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        XCTAssertEqual(store.summaries.map(\.content), [
            "Delivered fact 2.",
            "Delivered fact 3.",
            "Delivered fact 4."
        ])
    }

    func testInvalidStoredDataRecoversToEmptyAndRemovesCorruption() {
        let key = "invalid.previous.rides"
        defaults.set(Data("not-json".utf8), forKey: key)
        let store = PreviousRideMemoryStore(defaults: defaults, storageKey: key)

        XCTAssertEqual(store.summaries, [])
        XCTAssertNil(defaults.object(forKey: key))
    }

    func testClearRemovesAllSummaries() {
        let store = PreviousRideMemoryStore(defaults: defaults)
        store.completeRide(deliveredFacts: ["A delivered fact."], endedAt: Date())

        store.clear()

        XCTAssertEqual(store.summaries, [])
    }

    func testCompactionIsDeterministicDeduplicatedAndBounded() throws {
        let store = PreviousRideMemoryStore(defaults: defaults)
        let longFact = "The canal carried coal and cloth. " + String(repeating: "x", count: 400)

        store.completeRide(
            deliveredFacts: [longFact, longFact.uppercased(), String(repeating: "y", count: 800)],
            endedAt: Date(timeIntervalSince1970: 2)
        )

        let content = try XCTUnwrap(store.summaries.first?.content)
        XCTAssertLessThanOrEqual(content.count, PreviousRideMemoryStore.maximumSummaryCharacters)
        XCTAssertTrue(content.hasPrefix("The canal carried coal and cloth."))
        XCTAssertEqual(content.components(separatedBy: "The canal carried coal and cloth.").count - 1, 1)
    }
}
