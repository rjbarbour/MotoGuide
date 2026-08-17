import Foundation
import CoreLocation

struct Address: Equatable {
    struct PlacemarkFields: Equatable {
        let name: String?
        let thoroughfare: String?
        let subThoroughfare: String?
        let subLocality: String?
        let locality: String?
        let subAdministrativeArea: String?
        let administrativeArea: String?
        let postalCode: String?
        let isoCountryCode: String?
        let country: String?
        let inlandWater: String?
        let ocean: String?
        let areasOfInterest: [String]
        let timeZoneIdentifier: String?
        let regionIdentifier: String?

        init(placemark: CLPlacemark) {
            self.init(
                name: placemark.name,
                thoroughfare: placemark.thoroughfare,
                subThoroughfare: placemark.subThoroughfare,
                subLocality: placemark.subLocality,
                locality: placemark.locality,
                subAdministrativeArea: placemark.subAdministrativeArea,
                administrativeArea: placemark.administrativeArea,
                postalCode: placemark.postalCode,
                isoCountryCode: placemark.isoCountryCode,
                country: placemark.country,
                inlandWater: placemark.inlandWater,
                ocean: placemark.ocean,
                areasOfInterest: placemark.areasOfInterest ?? [],
                timeZoneIdentifier: placemark.timeZone?.identifier,
                regionIdentifier: placemark.region?.identifier
            )
        }

        init(
            name: String? = nil,
            thoroughfare: String? = nil,
            subThoroughfare: String? = nil,
            subLocality: String? = nil,
            locality: String? = nil,
            subAdministrativeArea: String? = nil,
            administrativeArea: String? = nil,
            postalCode: String? = nil,
            isoCountryCode: String? = nil,
            country: String? = nil,
            inlandWater: String? = nil,
            ocean: String? = nil,
            areasOfInterest: [String] = [],
            timeZoneIdentifier: String? = nil,
            regionIdentifier: String? = nil
        ) {
            self.name = name
            self.thoroughfare = thoroughfare
            self.subThoroughfare = subThoroughfare
            self.subLocality = subLocality
            self.locality = locality
            self.subAdministrativeArea = subAdministrativeArea
            self.administrativeArea = administrativeArea
            self.postalCode = postalCode
            self.isoCountryCode = isoCountryCode
            self.country = country
            self.inlandWater = inlandWater
            self.ocean = ocean
            self.areasOfInterest = areasOfInterest
            self.timeZoneIdentifier = timeZoneIdentifier
            self.regionIdentifier = regionIdentifier
        }
    }

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
        self.init(placemarkFields: PlacemarkFields(placemark: placemark))
    }

    init(placemarkFields: PlacemarkFields) {
        let subLocality = Self.placemarkValue(placemarkFields.subLocality)
        let locality = Self.placemarkValue(placemarkFields.locality)
        self.init(
            street: Self.placemarkValue(placemarkFields.thoroughfare),
            town: Self.currentPlaceLabel(subLocality: subLocality, locality: locality),
            county: Self.placemarkValue(placemarkFields.subAdministrativeArea),
            administrativeArea: Self.placemarkValue(placemarkFields.administrativeArea),
            country: Self.placemarkValue(placemarkFields.country),
            name: Self.placemarkValue(placemarkFields.name),
            houseNumber: Self.placemarkValue(placemarkFields.subThoroughfare),
            subLocality: subLocality,
            locality: locality,
            postalCode: Self.placemarkValue(placemarkFields.postalCode),
            isoCountryCode: Self.placemarkValue(placemarkFields.isoCountryCode),
            inlandWater: Self.placemarkValue(placemarkFields.inlandWater),
            ocean: Self.placemarkValue(placemarkFields.ocean),
            areasOfInterest: placemarkFields.areasOfInterest.filter(Self.isValidPlaceName),
            timeZoneIdentifier: Self.placemarkValue(placemarkFields.timeZoneIdentifier),
            regionIdentifier: Self.placemarkValue(placemarkFields.regionIdentifier)
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
