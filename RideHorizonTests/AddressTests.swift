import XCTest
@testable import RideHorizon

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

    func testSubLocalityIsPreferredAsTheCurrentPlaceLabel() {
        XCTAssertEqual(
            Address.currentPlaceLabel(subLocality: "Surbiton", locality: "Kingston upon Thames"),
            "Surbiton"
        )
        XCTAssertEqual(
            Address.currentPlaceLabel(subLocality: nil, locality: "Weybridge"),
            "Weybridge"
        )
    }

    func testRetainsApplePlaceMetadata() {
        let address = Address(
            street: "Brighton Road",
            town: "Surbiton",
            county: "Greater London",
            administrativeArea: "England",
            country: "United Kingdom",
            name: "Claremont Gardens",
            houseNumber: "12",
            subLocality: "Surbiton",
            locality: "Kingston upon Thames",
            postalCode: "KT6 5PL",
            isoCountryCode: "GB",
            inlandWater: "River Thames",
            ocean: "N/A",
            areasOfInterest: ["Claremont Gardens", "Surbiton Hill"],
            timeZoneIdentifier: "Europe/London",
            regionIdentifier: "Surbiton"
        )

        XCTAssertEqual(address.subLocality, "Surbiton")
        XCTAssertEqual(address.locality, "Kingston upon Thames")
        XCTAssertEqual(address.postalCode, "KT6 5PL")
        XCTAssertEqual(address.areasOfInterest, ["Claremont Gardens", "Surbiton Hill"])
        XCTAssertEqual(address.regionIdentifier, "Surbiton")
        XCTAssertTrue(address.toJSON()?.contains("subLocality") == true)
        XCTAssertTrue(address.toJSON()?.contains("areasOfInterest") == true)
    }
}
