import Foundation

struct RepeatPreferences: Equatable {
    var repeatStreet: Bool
    var repeatTown: Bool
    var repeatCounty: Bool
    var repeatAdministrativeArea: Bool

    static let allRepeats = RepeatPreferences(
        repeatStreet: true,
        repeatTown: true,
        repeatCounty: true,
        repeatAdministrativeArea: true
    )
}

enum AnnouncementDecision {
    static func hasAddressChanged(previous: Address?, current: Address) -> Bool {
        previous != current
    }

    static func componentInclusion(
        previous: Address?,
        current: Address,
        preferences: RepeatPreferences
    ) -> AddressFormatter.Inclusion {
        var inclusion = AddressFormatter.Inclusion(
            includeStreet: preferences.repeatStreet,
            includeTown: preferences.repeatTown,
            includeCounty: preferences.repeatCounty,
            includeAdministrativeArea: preferences.repeatAdministrativeArea
        )

        guard let previous else {
            return inclusion
        }

        if !preferences.repeatStreet, previous.street != current.street {
            inclusion.includeStreet = true
        }
        if !preferences.repeatTown, previous.town != current.town {
            inclusion.includeTown = true
        }
        if !preferences.repeatCounty, previous.county != current.county {
            inclusion.includeCounty = true
        }
        if !preferences.repeatAdministrativeArea, previous.administrativeArea != current.administrativeArea {
            inclusion.includeAdministrativeArea = true
        }

        return inclusion
    }

    static func speechText(
        for address: Address,
        previous: Address?,
        preferences: RepeatPreferences,
        speakAfterEveryGeocode: Bool
    ) -> String? {
        if speakAfterEveryGeocode {
            let inclusion = AddressFormatter.Inclusion(
                includeStreet: preferences.repeatStreet,
                includeTown: preferences.repeatTown,
                includeCounty: preferences.repeatCounty,
                includeAdministrativeArea: preferences.repeatAdministrativeArea
            )
            return AddressFormatter.spokenText(for: address, inclusion: inclusion)
        }

        guard hasAddressChanged(previous: previous, current: address) else {
            return nil
        }

        let inclusion = componentInclusion(
            previous: previous,
            current: address,
            preferences: preferences
        )
        return AddressFormatter.spokenText(for: address, inclusion: inclusion)
    }

    static func repeatPreferences(
        repeatStreet: Bool,
        repeatTown: Bool,
        repeatCounty: Bool,
        repeatAdministrativeArea: Bool
    ) -> RepeatPreferences {
        RepeatPreferences(
            repeatStreet: repeatStreet,
            repeatTown: repeatTown,
            repeatCounty: repeatCounty,
            repeatAdministrativeArea: repeatAdministrativeArea
        )
    }
}
