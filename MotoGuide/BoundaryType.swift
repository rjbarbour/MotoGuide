import Foundation

enum BoundaryType: Int, CaseIterable, Comparable {
    case country = 0
    case nation = 1
    case county = 2
    case town = 3
    case street = 4

    static func < (lhs: BoundaryType, rhs: BoundaryType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum ContentMode: String, CaseIterable, Identifiable {
    case natural
    case namesOnly
    case shortFacts
    case longFacts
    case quiet

    var id: String { rawValue }

    var label: String {
        switch self {
        case .natural: return "Natural"
        case .namesOnly: return "Names Only"
        case .shortFacts: return "Short Facts"
        case .longFacts: return "Long Facts"
        case .quiet: return "Quiet"
        }
    }

    var factMode: FactMode? {
        switch self {
        case .shortFacts:
            return .shortFacts
        case .longFacts:
            return .longFacts
        case .natural, .namesOnly, .quiet:
            return nil
        }
    }
}

struct BoundaryAnnouncementSettings: Equatable {
    var announceCountry: Bool
    var announceNation: Bool
    var announceCounty: Bool
    var announceTown: Bool
    var announceStreet: Bool

    static let ridingDefaults = BoundaryAnnouncementSettings(
        announceCountry: true,
        announceNation: true,
        announceCounty: true,
        announceTown: true,
        announceStreet: false
    )
}

struct AnnouncementPlan: Equatable {
    let text: String
    let boundary: BoundaryType
}

extension BoundaryType {
    var factLabel: String {
        switch self {
        case .country: return "country"
        case .nation: return "nation"
        case .county: return "county"
        case .town: return "town"
        case .street: return "street"
        }
    }
}
