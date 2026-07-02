import Foundation

enum FactMode: String, CaseIterable, Equatable {
    case shortFacts
    case longFacts

    var maxFactLength: Int {
        switch self {
        case .shortFacts: return 1100
        case .longFacts: return 1500
        }
    }
}

enum FactInterestCategory: String, CaseIterable, Identifiable, Codable, Equatable {
    case localRidingHints
    case geographyBasics
    case locationFacts
    case pointsOfInterest
    case history
    case culture
    case landmarks

    var id: String { rawValue }

    var label: String {
        switch self {
        case .localRidingHints: return "Local Riding Hints"
        case .geographyBasics: return "Geography and place identity"
        case .locationFacts: return "Location facts and local identity"
        case .pointsOfInterest: return "Points of interest"
        case .history: return "History and heritage"
        case .culture: return "Culture and character"
        case .landmarks: return "Landmarks and features"
        }
    }

    var prompt: String {
        switch self {
        case .localRidingHints: return "Local riding hints (brief, route-neutral)"
        case .geographyBasics: return "Geography and local identity"
        case .locationFacts: return "Location facts and what makes this place useful while riding"
        case .pointsOfInterest: return "Points of interest and named places"
        case .history: return "History and local context"
        case .culture: return "Culture and local character"
        case .landmarks: return "Landmarks and built environment"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)

        switch value {
        case "safetyAdvice", "localRidingHints":
            self = .localRidingHints
        case "geographyBasics":
            self = .geographyBasics
        case "locationFacts":
            self = .locationFacts
        case "pointsOfInterest":
            self = .pointsOfInterest
        case "history":
            self = .history
        case "culture":
            self = .culture
        case "landmarks":
            self = .landmarks
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown factInterestCategory value: \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static let defaultSelections: [FactInterestCategory] = [
        .geographyBasics,
        .locationFacts,
        .pointsOfInterest,
        .history,
        .culture,
        .landmarks
    ]
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
    let factInterestCategories: [FactInterestCategory]
    let customFactInstructions: String?

    static let empty = RiderContext(
        homeCountry: nil,
        homeRegion: nil,
        familiarRegions: [],
        factInterestCategories: FactInterestCategory.defaultSelections,
        customFactInstructions: nil
    )

    init(
        homeCountry: String?,
        homeRegion: String?,
        familiarRegions: [String] = [],
        factInterestCategories: [FactInterestCategory] = FactInterestCategory.defaultSelections,
        customFactInstructions: String? = nil
    ) {
        self.homeCountry = PlaceNameNormalizer.normalizeOptional(homeCountry)
        self.homeRegion = PlaceNameNormalizer.normalizeOptional(homeRegion)
        self.customFactInstructions = PlaceNameNormalizer.normalizeOptional(customFactInstructions)
        self.factInterestCategories = factInterestCategories.removingDuplicatesPreserveOrder()

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
            PlaceNameNormalizer.normalize(riderContext.familiarRegions.joined(separator: ",")),
            PlaceNameNormalizer.normalize(
                riderContext.factInterestCategories.map(\.rawValue).joined(separator: ",")
            ),
            PlaceNameNormalizer.normalize(riderContext.customFactInstructions ?? "")
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

private extension Array where Element == FactInterestCategory {
    func removingDuplicatesPreserveOrder() -> [FactInterestCategory] {
        var seen = Set<String>()
        var ordered: [FactInterestCategory] = []
        for element in self {
            if seen.insert(element.rawValue).inserted {
                ordered.append(element)
            }
        }
        return ordered
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
