import XCTest
@testable import MotoGuide

final class AnnouncementPolicyTests: XCTestCase {
    private let gloucester = Address(
        street: "High Street",
        town: "Stroud",
        county: "Gloucestershire",
        administrativeArea: "England",
        country: "United Kingdom"
    )

    private let stonehouse = Address(
        street: "Bristol Road",
        town: "Stonehouse",
        county: "Gloucestershire",
        administrativeArea: "England",
        country: "United Kingdom"
    )

    private let walesTown = Address(
        street: "High Street",
        town: "Chepstow",
        county: "Monmouthshire",
        administrativeArea: "Wales",
        country: "United Kingdom"
    )

    private let franceTown = Address(
        street: "Rue de la Gare",
        town: "Calais",
        county: "Pas-de-Calais",
        administrativeArea: "Hauts-de-France",
        country: "France"
    )

    private let ridingSettings = BoundaryAnnouncementSettings.ridingDefaults

    func testTownChangeUsesPlainNameInNaturalMode() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: stonehouse,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertEqual(plan?.text, "You are in Stonehouse, Gloucestershire")
        XCTAssertEqual(plan?.boundary, .town)
    }

    func testCountyChangeUsesWelcomePhrase() {
        let sameTownNewCounty = Address(
            street: "High Street",
            town: "Stroud",
            county: "South Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        )
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: sameTownNewCounty,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertEqual(plan?.text, "Welcome to South Gloucestershire. You are in Stroud, South Gloucestershire")
        XCTAssertEqual(plan?.boundary, .county)
    }

    func testNationAndCountyChangeUsesTwoSentenceWelcomePhrase() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: walesTown,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertEqual(plan?.text, "Welcome to Wales. You are in Chepstow, Monmouthshire")
        XCTAssertEqual(plan?.boundary, .nation)
    }

    func testCountryAndCountyChangeUsesTwoSentenceWelcomePhrase() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: franceTown,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertEqual(plan?.text, "Welcome to France. You are in Calais, Pas-de-Calais")
        XCTAssertEqual(plan?.boundary, .country)
    }

    func testNationChangeUsesWelcomePhrase() {
        let sameCountyNewNation = Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "Wales",
            country: "United Kingdom"
        )
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: sameCountyNewNation,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertEqual(plan?.text, "Welcome to Wales. You are in Stroud, Gloucestershire")
        XCTAssertEqual(plan?.boundary, .nation)
    }

    func testNamesOnlyModeUsesPlainHierarchy() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: walesTown,
            settings: ridingSettings,
            mode: .namesOnly
        )

        XCTAssertEqual(plan?.text, "Wales. Chepstow, Monmouthshire")
        XCTAssertEqual(plan?.boundary, .nation)
    }

    func testWelcomeBoundaryChangeIncludesTownInLocationPhrase() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: walesTown,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertTrue(plan?.text.contains("Chepstow") == true)
    }

    func testQuietModeProducesNoPlan() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: stonehouse,
            settings: ridingSettings,
            mode: .quiet
        )

        XCTAssertNil(plan)
    }

    func testNoPlanOnFirstAddress() {
        let plan = AnnouncementPolicy.plan(
            previous: nil,
            current: gloucester,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertNil(plan)
    }

    func testNoPlanWhenAddressUnchanged() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: gloucester,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertNil(plan)
    }

    func testDisabledTownAnnouncementsAreIgnored() {
        var settings = ridingSettings
        settings.announceTown = false

        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: stonehouse,
            settings: settings,
            mode: .natural
        )

        XCTAssertNil(plan)
    }
}

final class AnnouncementQueueTests: XCTestCase {
    func testReplacePendingKeepsOnlyLatestRequest() {
        var queue = AnnouncementQueue()
        let first = queue.replacePending(text: "You are in Stroud, Gloucestershire", boundary: .town)
        let second = queue.replacePending(text: "Welcome to Gloucestershire. You are in Stroud, Gloucestershire", boundary: .county)

        XCTAssertEqual(queue.pending?.id, second.id)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(queue.pending?.text, "Welcome to Gloucestershire. You are in Stroud, Gloucestershire")
    }

    func testShouldDropLowerPriorityWhileSpeaking() {
        XCTAssertTrue(
            AnnouncementQueue.shouldDropWhileSpeaking(
                newBoundary: .town,
                currentlySpeaking: .county
            )
        )
        XCTAssertFalse(
            AnnouncementQueue.shouldDropWhileSpeaking(
                newBoundary: .county,
                currentlySpeaking: .town
            )
        )
    }

    func testShouldInterruptForHigherPriorityBoundary() {
        XCTAssertTrue(
            AnnouncementQueue.shouldInterrupt(
                newBoundary: .nation,
                currentlySpeaking: .town
            )
        )
        XCTAssertFalse(
            AnnouncementQueue.shouldInterrupt(
                newBoundary: .town,
                currentlySpeaking: .nation
            )
        )
    }

    func testClearPendingOnlyClearsMatchingRequest() {
        var queue = AnnouncementQueue()
        let request = queue.replacePending(text: "Welcome to Wales. You are in Chepstow, Monmouthshire", boundary: .nation)

        queue.clearPending(id: UUID())
        XCTAssertEqual(queue.pending?.id, request.id)

        queue.clearPending(id: request.id)
        XCTAssertNil(queue.pending)
    }
}
