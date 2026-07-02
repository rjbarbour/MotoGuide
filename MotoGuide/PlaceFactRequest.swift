import Foundation

enum FactMode: String, CaseIterable, Equatable {
    case shortFacts
    case longFacts

    var maxFactLength: Int {
        switch self {
        case .shortFacts: return 700
        case .longFacts: return 900
        }
    }
}

struct PlaceHierarchy: Equatable, Codable {
    let street: String?
    let town: String?
    let county: String?
    let region: String?
    let country: String?

    static let empty = PlaceHierarchy(
        street: nil,
        town: nil,
        county: nil,
        region: nil,
        country: nil
    )

    init(
        street: String?,
        town: String?,
        county: String?,
        region: String?,
        country: String?
    ) {
        self.street = Self.validValue(street)
        self.town = Self.validValue(town)
        self.county = Self.validValue(county)
        self.region = Self.validValue(region)
        self.country = Self.validValue(country)
    }

    init(address: Address) {
        self.init(
            street: address.street,
            town: address.town,
            county: address.county,
            region: address.administrativeArea,
            country: address.country
        )
    }

    private static func validValue(_ value: String?) -> String? {
        guard let value, Address.isValidPlaceName(value) else { return nil }
        return value
    }
}

struct RiderContext: Equatable, Codable {
    let homeCountry: String?
    let homeRegion: String?
    let familiarRegions: [String]

    static let empty = RiderContext(homeCountry: nil, homeRegion: nil, familiarRegions: [])

    init(
        homeCountry: String?,
        homeRegion: String?,
        familiarRegions: [String] = []
    ) {
        self.homeCountry = PlaceNameNormalizer.normalizeOptional(homeCountry)
        self.homeRegion = PlaceNameNormalizer.normalizeOptional(homeRegion)

        var normalizedRegions: [String] = []
        for region in familiarRegions {
            if let normalized = PlaceNameNormalizer.normalizeOptional(region),
               !normalizedRegions.contains(normalized) {
                normalizedRegions.append(normalized)
            }
        }
        self.familiarRegions = normalizedRegions
    }
}

struct PlaceFactRequest: Equatable {
    let boundary: BoundaryType
    let placeName: String
    let factMode: FactMode
    let countryContext: String?
    let placeHierarchy: PlaceHierarchy
    let riderContext: RiderContext

    var cacheKey: String {
        [
            factMode.rawValue,
            String(boundary.rawValue),
            PlaceNameNormalizer.normalize(placeName),
            PlaceNameNormalizer.normalize(countryContext ?? ""),
            PlaceNameNormalizer.normalize(placeHierarchy.street ?? ""),
            PlaceNameNormalizer.normalize(placeHierarchy.town ?? ""),
            PlaceNameNormalizer.normalize(placeHierarchy.county ?? ""),
            PlaceNameNormalizer.normalize(placeHierarchy.region ?? ""),
            PlaceNameNormalizer.normalize(placeHierarchy.country ?? ""),
            PlaceNameNormalizer.normalize(riderContext.homeCountry ?? ""),
            PlaceNameNormalizer.normalize(riderContext.homeRegion ?? ""),
            PlaceNameNormalizer.normalize(riderContext.familiarRegions.joined(separator: ","))
        ].joined(separator: ":")
    }

    init(
        boundary: BoundaryType,
        placeName: String,
        factMode: FactMode = .shortFacts,
        countryContext: String?,
        placeHierarchy: PlaceHierarchy = .empty,
        riderContext: RiderContext = .empty
    ) {
        self.boundary = boundary
        self.placeName = placeName
        self.factMode = factMode
        self.countryContext = countryContext
        self.placeHierarchy = placeHierarchy
        self.riderContext = riderContext
    }
}

enum PlaceFactError: Error, Equatable {
    case missingProxyToken
    case invalidResponse
    case httpError(Int)
}

enum PlaceNameNormalizer {
    static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizeOptional(_ name: String?) -> String? {
        guard let name, !name.isEmpty else { return nil }
        let normalized = normalize(name)
        return normalized.isEmpty ? nil : normalized
    }
}

protocol PlaceFactGenerating {
    func fact(for request: PlaceFactRequest) async throws -> String
}
