import Foundation

struct PlaceFactRequest: Equatable {
    let boundary: BoundaryType
    let placeName: String
    let countryContext: String?

    var cacheKey: String {
        "\(boundary.rawValue):\(PlaceNameNormalizer.normalize(placeName))"
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
}

protocol PlaceFactGenerating {
    func fact(for request: PlaceFactRequest) async throws -> String
}
