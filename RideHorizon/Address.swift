import Foundation
import CoreLocation

struct Address: Equatable {
    let street: String
    let town: String
    let county: String
    let administrativeArea: String
    let country: String
    let name: String
    let houseNumber: String
    let subLocality: String
    let locality: String
    let postalCode: String
    let isoCountryCode: String
    let inlandWater: String
    let ocean: String
    let areasOfInterest: [String]
    let timeZoneIdentifier: String
    let regionIdentifier: String

    init(
        street: String,
        town: String,
        county: String,
        administrativeArea: String,
        country: String = "N/A",
        name: String = "N/A",
        houseNumber: String = "N/A",
        subLocality: String = "N/A",
        locality: String = "N/A",
        postalCode: String = "N/A",
        isoCountryCode: String = "N/A",
        inlandWater: String = "N/A",
        ocean: String = "N/A",
        areasOfInterest: [String] = [],
        timeZoneIdentifier: String = "N/A",
        regionIdentifier: String = "N/A"
    ) {
        self.street = street
        self.town = town
        self.county = county
        self.administrativeArea = administrativeArea
        self.country = country
        self.name = name
        self.houseNumber = houseNumber
        self.subLocality = subLocality
        self.locality = locality
        self.postalCode = postalCode
        self.isoCountryCode = isoCountryCode
        self.inlandWater = inlandWater
        self.ocean = ocean
        self.areasOfInterest = areasOfInterest
        self.timeZoneIdentifier = timeZoneIdentifier
        self.regionIdentifier = regionIdentifier
    }

    init(placemark: CLPlacemark) {
        let subLocality = Self.placemarkValue(placemark.subLocality)
        let locality = Self.placemarkValue(placemark.locality)
        self.init(
            street: Self.placemarkValue(placemark.thoroughfare),
            town: Self.currentPlaceLabel(subLocality: subLocality, locality: locality),
            county: Self.placemarkValue(placemark.subAdministrativeArea),
            administrativeArea: Self.placemarkValue(placemark.administrativeArea),
            country: Self.placemarkValue(placemark.country),
            name: Self.placemarkValue(placemark.name),
            houseNumber: Self.placemarkValue(placemark.subThoroughfare),
            subLocality: subLocality,
            locality: locality,
            postalCode: Self.placemarkValue(placemark.postalCode),
            isoCountryCode: Self.placemarkValue(placemark.isoCountryCode),
            inlandWater: Self.placemarkValue(placemark.inlandWater),
            ocean: Self.placemarkValue(placemark.ocean),
            areasOfInterest: (placemark.areasOfInterest ?? []).filter(Self.isValidPlaceName),
            timeZoneIdentifier: Self.placemarkValue(placemark.timeZone?.identifier),
            regionIdentifier: Self.placemarkValue(placemark.region?.identifier)
        )
    }

    static func currentPlaceLabel(subLocality: String?, locality: String?) -> String {
        let subLocality = placemarkValue(subLocality)
        if isValidPlaceName(subLocality) {
            return subLocality
        }
        return placemarkValue(locality)
    }

    static func isValidPlaceName(_ value: String) -> Bool {
        !value.isEmpty && value != "N/A"
    }

    func toJSON() -> String? {
        let dict: [String: Any] = [
            "street": street,
            "town": town,
            "county": county,
            "administrativeArea": administrativeArea,
            "country": country,
            "name": name,
            "houseNumber": houseNumber,
            "subLocality": subLocality,
            "locality": locality,
            "postalCode": postalCode,
            "isoCountryCode": isoCountryCode,
            "inlandWater": inlandWater,
            "ocean": ocean,
            "areasOfInterest": areasOfInterest,
            "timeZoneIdentifier": timeZoneIdentifier,
            "regionIdentifier": regionIdentifier
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }

    private static func placemarkValue(_ value: String?) -> String {
        guard let value else { return "N/A" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "N/A" : trimmed
    }
}

struct AddressFormatter {
    struct Inclusion: Equatable {
        var includeStreet: Bool
        var includeTown: Bool
        var includeCounty: Bool
        var includeAdministrativeArea: Bool

        static let all = Inclusion(
            includeStreet: true,
            includeTown: true,
            includeCounty: true,
            includeAdministrativeArea: true
        )
    }

    static func spokenText(for address: Address, inclusion: Inclusion) -> String {
        var components = [String]()
        if inclusion.includeStreet, Address.isValidPlaceName(address.street) {
            components.append(address.street)
        }
        if inclusion.includeTown, Address.isValidPlaceName(address.town) {
            components.append(address.town)
        }
        if inclusion.includeCounty, Address.isValidPlaceName(address.county) {
            components.append(address.county)
        }
        if inclusion.includeAdministrativeArea, Address.isValidPlaceName(address.administrativeArea) {
            components.append(address.administrativeArea)
        }
        return components.joined(separator: ", ")
    }
}
