import Foundation
import CoreLocation

struct Address: Equatable {
    let street: String
    let town: String
    let county: String
    let administrativeArea: String

    init(
        street: String,
        town: String,
        county: String,
        administrativeArea: String
    ) {
        self.street = street
        self.town = town
        self.county = county
        self.administrativeArea = administrativeArea
    }

    init(placemark: CLPlacemark) {
        self.init(
            street: placemark.thoroughfare ?? "N/A",
            town: placemark.locality ?? "N/A",
            county: placemark.subAdministrativeArea ?? "N/A",
            administrativeArea: placemark.administrativeArea ?? "N/A"
        )
    }

    func toJSON() -> String? {
        let dict: [String: String] = [
            "street": street,
            "town": town,
            "county": county,
            "administrativeArea": administrativeArea
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
        if inclusion.includeStreet {
            components.append(address.street)
        }
        if inclusion.includeTown {
            components.append(address.town)
        }
        if inclusion.includeCounty {
            components.append(address.county)
        }
        if inclusion.includeAdministrativeArea {
            components.append(address.administrativeArea)
        }
        return components.joined(separator: ", ")
    }
}
