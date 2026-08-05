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

    func testPlacemarkFieldMappingRetainsSubLocalityAndEnclosingLocality() {
        let placemarkFields = Address.PlacemarkFields(
            name: "Claremont Gardens",
            thoroughfare: "Brighton Road",
            subThoroughfare: "12",
            subLocality: "Surbiton",
            locality: "Kingston upon Thames",
            subAdministrativeArea: "Greater London",
            administrativeArea: "England",
            postalCode: "KT6 5PL",
            isoCountryCode: "GB",
            country: "United Kingdom",
            inlandWater: "River Thames",
            ocean: "Atlantic Ocean",
            areasOfInterest: ["Claremont Gardens"],
            timeZoneIdentifier: "Europe/London",
            regionIdentifier: "Surbiton"
        )
        let address = Address(placemarkFields: placemarkFields)

        XCTAssertEqual(address.name, "Claremont Gardens")
        XCTAssertEqual(address.houseNumber, "12")
        XCTAssertEqual(address.street, "Brighton Road")
        XCTAssertEqual(address.subLocality, "Surbiton")
        XCTAssertEqual(address.locality, "Kingston upon Thames")
        XCTAssertEqual(address.town, "Surbiton")
        XCTAssertEqual(address.county, "Greater London")
        XCTAssertEqual(address.administrativeArea, "England")
        XCTAssertEqual(address.postalCode, "KT6 5PL")
        XCTAssertEqual(address.isoCountryCode, "GB")
        XCTAssertEqual(address.country, "United Kingdom")
        XCTAssertEqual(address.inlandWater, "River Thames")
        XCTAssertEqual(address.ocean, "Atlantic Ocean")
        XCTAssertEqual(address.areasOfInterest, ["Claremont Gardens"])
        XCTAssertEqual(address.timeZoneIdentifier, "Europe/London")
        XCTAssertEqual(address.regionIdentifier, "Surbiton")
    }

    func testSummaryKeepsAnOrdinaryLocalityOnOneLine() {
        let ordinaryAddress = Address(
            street: "High Street",
            town: "Weybridge",
            county: "Elmbridge",
            administrativeArea: "England",
            country: "United Kingdom",
            locality: "Weybridge"
        )
        let subLocalityAddress = Address(
            street: "Brighton Road",
            town: "Surbiton",
            county: "Greater London",
            administrativeArea: "England",
            country: "United Kingdom",
            subLocality: "Surbiton",
            locality: "Kingston upon Thames"
        )

        XCTAssertEqual(
            LocationSummaryFormatter.summaryLines(for: ordinaryAddress),
            ["High Street, Weybridge", "Elmbridge · England · United Kingdom"]
        )
        XCTAssertEqual(
            LocationSummaryFormatter.summaryLines(for: subLocalityAddress),
            ["Brighton Road, Surbiton", "Kingston upon Thames · Greater London · England · United Kingdom"]
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
