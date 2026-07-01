import Foundation
import CoreLocation

struct Address: Equatable {
    let street: String
    let town: String
    let county: String
    let administrativeArea: String
    let country: String

    init(
        street: String,
        town: String,
        county: String,
        administrativeArea: String,
        country: String = "N/A"
    ) {
        self.street = street
        self.town = town
        self.county = county
        self.administrativeArea = administrativeArea
        self.country = country
    }

    init(placemark: CLPlacemark) {
        self.init(
            street: placemark.thoroughfare ?? "N/A",
            town: placemark.locality ?? "N/A",
            county: placemark.subAdministrativeArea ?? "N/A",
            administrativeArea: placemark.administrativeArea ?? "N/A",
            country: placemark.country ?? "N/A"
        )
    }

    static func isValidPlaceName(_ value: String) -> Bool {
        !value.isEmpty && value != "N/A"
    }

    func toJSON() -> String? {
        let dict: [String: String] = [
            "street": street,
            "town": town,
            "county": county,
            "administrativeArea": administrativeArea,
            "country": country
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
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
