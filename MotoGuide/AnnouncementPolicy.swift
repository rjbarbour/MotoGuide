import Foundation

enum BoundaryChangeDetector {
    static func changedBoundaries(from previous: Address, to current: Address, settings: BoundaryAnnouncementSettings) -> [BoundaryType] {
        var changes = [BoundaryType]()

        if settings.announceCountry,
           previous.country != current.country,
           Address.isValidPlaceName(current.country) {
            changes.append(.country)
        }
        if settings.announceNation,
           previous.administrativeArea != current.administrativeArea,
           Address.isValidPlaceName(current.administrativeArea) {
            changes.append(.nation)
        }
        if settings.announceCounty,
           previous.county != current.county,
           Address.isValidPlaceName(current.county) {
            changes.append(.county)
        }
        if settings.announceTown,
           previous.town != current.town,
           Address.isValidPlaceName(current.town) {
            changes.append(.town)
        }
        if settings.announceStreet,
           previous.street != current.street,
           Address.isValidPlaceName(current.street) {
            changes.append(.street)
        }

        return changes
    }

    static func highestPriorityChange(
        from previous: Address?,
        to current: Address,
        settings: BoundaryAnnouncementSettings
    ) -> BoundaryType? {
        guard let previous else { return nil }
        return changedBoundaries(from: previous, to: current, settings: settings).min()
    }
}

enum AnnouncementPhraseBuilder {
    static func baseSpeechMode(for mode: ContentMode) -> ContentMode {
        switch mode {
        case .shortFacts, .longFacts:
            return .natural
        case .natural, .namesOnly, .quiet:
            return mode
        }
    }

    static func phrase(
        for changes: [BoundaryType],
        address: Address,
        mode: ContentMode
    ) -> (text: String, boundary: BoundaryType)? {
        let speechMode = baseSpeechMode(for: mode)
        guard speechMode != .quiet, !changes.isEmpty else { return nil }
        guard let boundary = changes.min() else { return nil }

        guard let text = phrase(for: boundary, changes: changes, address: address, mode: speechMode) else {
            return nil
        }
        return (text, boundary)
    }

    static func phrase(
        for boundary: BoundaryType,
        changes: [BoundaryType],
        address: Address,
        mode: ContentMode
    ) -> String? {
        guard mode != .quiet else { return nil }

        if boundary == .street {
            let name = placeName(for: .street, in: address)
            guard Address.isValidPlaceName(name) else { return nil }
            return mode == .namesOnly ? name : name
        }

        let welcomeName = welcomeName(for: changes, in: address)
        let location = locationPhrase(in: address, mode: mode)

        switch mode {
        case .quiet:
            return nil
        case .namesOnly:
            return namesOnlyPhrase(welcomeName: welcomeName, location: location)
        case .natural, .shortFacts, .longFacts:
            return naturalPhrase(welcomeName: welcomeName, location: location)
        }
    }

    static func phrase(for boundary: BoundaryType, address: Address, mode: ContentMode) -> String? {
        phrase(for: boundary, changes: [boundary], address: address, mode: mode)
    }

    static func placeName(for boundary: BoundaryType, in address: Address) -> String {
        switch boundary {
        case .country: return address.country
        case .nation: return address.administrativeArea
        case .county: return address.county
        case .town: return address.town
        case .street: return address.street
        }
    }

    /// Nation/country for UK home nations; country when crossing an international border.
    private static func welcomeName(for changes: [BoundaryType], in address: Address) -> String? {
        if changes.contains(.country) {
            let country = address.country
            return Address.isValidPlaceName(country) ? country : nil
        }
        if changes.contains(.nation) {
            let nation = address.administrativeArea
            return Address.isValidPlaceName(nation) ? nation : nil
        }
        if changes.contains(.county) {
            let county = address.county
            return Address.isValidPlaceName(county) ? county : nil
        }
        return nil
    }

    static func locationPhrase(in address: Address, mode: ContentMode) -> String? {
        let town = Address.isValidPlaceName(address.town) ? address.town : nil
        let county = Address.isValidPlaceName(address.county) ? address.county : nil

        switch mode {
        case .quiet:
            return nil
        case .namesOnly:
            if let town, let county { return "\(town), \(county)" }
            if let town { return town }
            if let county { return county }
            return nil
        case .natural, .shortFacts, .longFacts:
            if let town, let county { return "You are in \(town), \(county)" }
            if let town { return "You are in \(town)" }
            if let county { return "You are in \(county)" }
            return nil
        }
    }

    private static func naturalPhrase(welcomeName: String?, location: String?) -> String? {
        switch (welcomeName, location) {
        case let (welcome?, location?):
            return "Welcome to \(welcome). \(location)"
        case let (welcome?, nil):
            return "Welcome to \(welcome)"
        case let (nil, location?):
            return location
        case (nil, nil):
            return nil
        }
    }

    private static func namesOnlyPhrase(welcomeName: String?, location: String?) -> String? {
        switch (welcomeName, location) {
        case let (welcome?, location?):
            return "\(welcome). \(location)"
        case let (welcome?, nil):
            return welcome
        case let (nil, location?):
            return location
        case (nil, nil):
            return nil
        }
    }
}

enum AnnouncementPolicy {
    static func plan(
        previous: Address?,
        current: Address,
        settings: BoundaryAnnouncementSettings,
        mode: ContentMode
    ) -> AnnouncementPlan? {
        guard mode != .quiet else { return nil }
        guard let previous else { return nil }

        let changes = BoundaryChangeDetector.changedBoundaries(
            from: previous,
            to: current,
            settings: settings
        )
        guard !changes.isEmpty else { return nil }

        guard let result = AnnouncementPhraseBuilder.phrase(
            for: changes,
            address: current,
            mode: mode
        ) else {
            return nil
        }
        return AnnouncementPlan(text: result.text, boundary: result.boundary)
    }

    static func factRequest(
        for plan: AnnouncementPlan,
        address: Address,
        mode: FactMode = .shortFacts,
        riderContext: RiderContext = .empty
    ) -> PlaceFactRequest {
        PlaceFactRequest(
            boundary: plan.boundary,
            placeName: AnnouncementPhraseBuilder.placeName(for: plan.boundary, in: address),
            factMode: mode,
            countryContext: Address.isValidPlaceName(address.country) ? address.country : nil,
            placeHierarchy: PlaceHierarchy(address: address),
            riderContext: riderContext
        )
    }
}

struct AnnouncementRequest: Equatable {
    let id: UUID
    let text: String
    let boundary: BoundaryType
}

struct AnnouncementQueue {
    private(set) var pending: AnnouncementRequest?

    mutating func replacePending(text: String, boundary: BoundaryType) -> AnnouncementRequest {
        let request = AnnouncementRequest(id: UUID(), text: text, boundary: boundary)
        pending = request
        return request
    }

    mutating func clearPending(id: UUID) {
        if pending?.id == id {
            pending = nil
        }
    }

    mutating func clearPending() {
        pending = nil
    }

    static func shouldDropWhileSpeaking(
        newBoundary: BoundaryType,
        currentlySpeaking: BoundaryType?
    ) -> Bool {
        guard let currentlySpeaking else { return false }
        return newBoundary > currentlySpeaking
    }

    static func shouldInterrupt(
        newBoundary: BoundaryType,
        currentlySpeaking: BoundaryType
    ) -> Bool {
        newBoundary < currentlySpeaking
    }
}
