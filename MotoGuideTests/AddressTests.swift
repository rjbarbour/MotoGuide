import XCTest
@testable import MotoGuide

final class AddressTests: XCTestCase {
    func testEquality() {
        let first = Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England"
        )
        let second = Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England"
        )
        let different = Address(
            street: "Other Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England"
        )

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, different)
    }

    func testSpokenTextIncludesSelectedComponents() {
        let address = Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England"
        )
        let inclusion = AddressFormatter.Inclusion(
            includeStreet: false,
            includeTown: true,
            includeCounty: true,
            includeAdministrativeArea: false
        )

        XCTAssertEqual(
            AddressFormatter.spokenText(for: address, inclusion: inclusion),
            "Stroud, Gloucestershire"
        )
    }

    func testSpokenTextWithAllComponents() {
        let address = Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England"
        )

        XCTAssertEqual(
            AddressFormatter.spokenText(for: address, inclusion: .all),
            "High Street, Stroud, Gloucestershire, England"
        )
    }

    func testSpokenTextSkipsPlaceholderComponents() {
        let address = Address(
            street: "N/A",
            town: "Stroud",
            county: "",
            administrativeArea: "England"
        )

        XCTAssertEqual(
            AddressFormatter.spokenText(for: address, inclusion: .all),
            "Stroud, England"
        )
    }

    func testToJSONContainsAddressFields() {
        let address = Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England"
        )

        let json = address.toJSON()
        XCTAssertNotNil(json)
        XCTAssertTrue(json?.contains("Stroud") == true)
        XCTAssertTrue(json?.contains("Gloucestershire") == true)
    }
}
