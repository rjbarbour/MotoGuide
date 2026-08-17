@preconcurrency import CoreLocation
import Foundation

struct ProbeCoordinate: Codable {
    let latitude: Double
    let longitude: Double
}

struct ProbeAddress: Codable {
    let street: String
    let town: String
    let county: String
    let administrativeArea: String
    let country: String
}

struct PlacemarkCandidate: Codable {
    let coordinate: ProbeCoordinate
    let name: String?
    let thoroughfare: String?
    let subThoroughfare: String?
    let locality: String?
    let subLocality: String?
    let subAdministrativeArea: String?
    let administrativeArea: String?
    let postalCode: String?
    let country: String?
    let isoCountryCode: String?
    let areasOfInterest: [String]
    let rideHorizonAddress: ProbeAddress

    init(_ placemark: CLPlacemark) {
        coordinate = ProbeCoordinate(latitude: placemark.location?.coordinate.latitude ?? 0, longitude: placemark.location?.coordinate.longitude ?? 0)
        name = placemark.name
        thoroughfare = placemark.thoroughfare
        subThoroughfare = placemark.subThoroughfare
        locality = placemark.locality
        subLocality = placemark.subLocality
        subAdministrativeArea = placemark.subAdministrativeArea
        administrativeArea = placemark.administrativeArea
        postalCode = placemark.postalCode
        country = placemark.country
        isoCountryCode = placemark.isoCountryCode
        areasOfInterest = placemark.areasOfInterest ?? []
        let address = Address(placemark: placemark)
        rideHorizonAddress = ProbeAddress(street: address.street, town: address.town, county: address.county, administrativeArea: address.administrativeArea, country: address.country)
    }
}

struct ProbeResponse: Codable {
    let operation: String
    let requestedLocale: String
    let requestedAt: String
    let platform: String
    let deviceClass: String
    let outcome: String
    let candidateCount: Int
    let candidates: [PlacemarkCandidate]
    let errorCode: String?
    let errorMessage: String?
}

final class CompletionState: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false

    func markCompleted() {
        lock.lock()
        completed = true
        lock.unlock()
    }

    var isCompleted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return completed
    }
}

func isoNow() -> String {
    ISO8601DateFormatter().string(from: Date())
}

func emit(_ response: ProbeResponse) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try! encoder.encode(response)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func argument(_ name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name), CommandLine.arguments.indices.contains(index + 1) else { return nil }
    return CommandLine.arguments[index + 1]
}

@main
enum ApplePlaceProbe {
    static func main() {
        let operation = argument("--operation") ?? ""
        let localeIdentifier = argument("--locale") ?? "en_GB"
        let locale = Locale(identifier: localeIdentifier)
        let geocoder = CLGeocoder()
        let completionState = CompletionState()
        let platform = ProcessInfo.processInfo.operatingSystemVersionString

        let finish: @Sendable ([CLPlacemark]?, (any Error)?) -> Void = { placemarks, error in
            if let error {
                let nsError = error as NSError
                emit(ProbeResponse(operation: operation, requestedLocale: localeIdentifier, requestedAt: isoNow(), platform: platform, deviceClass: "macOS command-line", outcome: "failure", candidateCount: 0, candidates: [], errorCode: "\(nsError.domain):\(nsError.code)", errorMessage: nsError.localizedDescription))
            } else {
                let candidates = (placemarks ?? []).map(PlacemarkCandidate.init)
                emit(ProbeResponse(operation: operation, requestedLocale: localeIdentifier, requestedAt: isoNow(), platform: platform, deviceClass: "macOS command-line", outcome: "success", candidateCount: candidates.count, candidates: candidates, errorCode: nil, errorMessage: nil))
            }
            completionState.markCompleted()
        }

        switch operation {
        case "reverse":
            guard let latitudeText = argument("--latitude"), let longitudeText = argument("--longitude"), let latitude = Double(latitudeText), let longitude = Double(longitudeText), CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) else {
                emit(ProbeResponse(operation: operation, requestedLocale: localeIdentifier, requestedAt: isoNow(), platform: platform, deviceClass: "macOS command-line", outcome: "failure", candidateCount: 0, candidates: [], errorCode: "invalid_input", errorMessage: "Reverse geocoding needs valid numeric latitude and longitude."))
                return
            }
            geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude), preferredLocale: locale, completionHandler: finish)
        case "forward":
            guard let query = argument("--query"), !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                emit(ProbeResponse(operation: operation, requestedLocale: localeIdentifier, requestedAt: isoNow(), platform: platform, deviceClass: "macOS command-line", outcome: "failure", candidateCount: 0, candidates: [], errorCode: "invalid_input", errorMessage: "Forward geocoding needs a non-empty query."))
                return
            }
            geocoder.geocodeAddressString(query, in: nil, preferredLocale: locale, completionHandler: finish)
        default:
            emit(ProbeResponse(operation: operation, requestedLocale: localeIdentifier, requestedAt: isoNow(), platform: platform, deviceClass: "macOS command-line", outcome: "failure", candidateCount: 0, candidates: [], errorCode: "invalid_input", errorMessage: "Operation must be reverse or forward."))
            return
        }

        let deadline = Date().addingTimeInterval(90)
        while !completionState.isCompleted && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        if !completionState.isCompleted {
            emit(ProbeResponse(operation: operation, requestedLocale: localeIdentifier, requestedAt: isoNow(), platform: platform, deviceClass: "macOS command-line", outcome: "failure", candidateCount: 0, candidates: [], errorCode: "timeout", errorMessage: "The local CLGeocoder callback did not arrive within 90 seconds."))
        }
    }
}
