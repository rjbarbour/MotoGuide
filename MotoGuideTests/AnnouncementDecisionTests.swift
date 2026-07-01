import XCTest
@testable import MotoGuide

final class AnnouncementDecisionTests: XCTestCase {
    private let stroud = Address(
        street: "High Street",
        town: "Stroud",
        county: "Gloucestershire",
        administrativeArea: "England"
    )

    private let stonehouse = Address(
        street: "Bristol Road",
        town: "Stonehouse",
        county: "Gloucestershire",
        administrativeArea: "England"
    )

    private let noRepeats = RepeatPreferences(
        repeatStreet: false,
        repeatTown: false,
        repeatCounty: false,
        repeatAdministrativeArea: false
    )

    func testHasAddressChangedDetectsAnyFieldChange() {
        XCTAssertFalse(AnnouncementDecision.hasAddressChanged(previous: stroud, current: stroud))
        XCTAssertTrue(AnnouncementDecision.hasAddressChanged(previous: stroud, current: stonehouse))
    }

    func testComponentInclusionAnnouncesOnlyChangedFieldsWhenRepeatsDisabled() {
        let inclusion = AnnouncementDecision.componentInclusion(
            previous: stroud,
            current: stonehouse,
            preferences: noRepeats
        )

        XCTAssertTrue(inclusion.includeStreet)
        XCTAssertTrue(inclusion.includeTown)
        XCTAssertFalse(inclusion.includeCounty)
        XCTAssertFalse(inclusion.includeAdministrativeArea)
    }

    func testComponentInclusionUsesRepeatPreferencesOnFirstAddress() {
        let preferences = RepeatPreferences(
            repeatStreet: false,
            repeatTown: true,
            repeatCounty: true,
            repeatAdministrativeArea: false
        )

        let inclusion = AnnouncementDecision.componentInclusion(
            previous: nil,
            current: stroud,
            preferences: preferences
        )

        XCTAssertFalse(inclusion.includeStreet)
        XCTAssertTrue(inclusion.includeTown)
        XCTAssertTrue(inclusion.includeCounty)
        XCTAssertFalse(inclusion.includeAdministrativeArea)
    }

    func testSpeechTextReturnsNilWhenAddressUnchanged() {
        let speechText = AnnouncementDecision.speechText(
            for: stroud,
            previous: stroud,
            preferences: RepeatPreferences.allRepeats,
            speakAfterEveryGeocode: false
        )

        XCTAssertNil(speechText)
    }

    func testSpeechTextAnnouncesChangedTownOnlyWhenCountyRepeats() {
        let preferences = RepeatPreferences(
            repeatStreet: false,
            repeatTown: false,
            repeatCounty: true,
            repeatAdministrativeArea: true
        )

        let speechText = AnnouncementDecision.speechText(
            for: stonehouse,
            previous: stroud,
            preferences: preferences,
            speakAfterEveryGeocode: false
        )

        XCTAssertEqual(speechText, "Bristol Road, Stonehouse, Gloucestershire, England")
    }

    func testSpeechTextSpeaksAfterEveryGeocodeEvenWhenUnchanged() {
        let preferences = RepeatPreferences(
            repeatStreet: false,
            repeatTown: true,
            repeatCounty: true,
            repeatAdministrativeArea: false
        )

        let speechText = AnnouncementDecision.speechText(
            for: stroud,
            previous: stroud,
            preferences: preferences,
            speakAfterEveryGeocode: true
        )

        XCTAssertEqual(speechText, "Stroud, Gloucestershire")
    }

    func testSpeechTextForTownChangeOnly() {
        let changedTown = Address(
            street: "High Street",
            town: "Nailsworth",
            county: "Gloucestershire",
            administrativeArea: "England"
        )
        let preferences = RepeatPreferences(
            repeatStreet: true,
            repeatTown: false,
            repeatCounty: true,
            repeatAdministrativeArea: true
        )

        let speechText = AnnouncementDecision.speechText(
            for: changedTown,
            previous: stroud,
            preferences: preferences,
            speakAfterEveryGeocode: false
        )

        XCTAssertEqual(
            speechText,
            "High Street, Nailsworth, Gloucestershire, England"
        )
    }
}
