import Foundation
import CoreLocation
import AVFoundation

struct Address: Equatable {
    let street: String
    let town: String
    let county: String
    let administrativeArea: String
    
    func toJSON() -> String? {
        let dict = ["street": street, "town": town, "county": county, "administrativeArea": administrativeArea]
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8)
        }
        return nil
    }
    
    func toString(includeStreet: Bool = true, includeTown: Bool = true, includeCounty: Bool = true, includeAdministrativeArea: Bool = true) -> String {
        var addressComponents = [String]()
        if includeStreet {
            addressComponents.append(street)
        }
        if includeTown {
            addressComponents.append(town)
        }
        if includeCounty {
            addressComponents.append(county)
        }
        if includeAdministrativeArea {
            addressComponents.append(administrativeArea)
        }
        return addressComponents.joined(separator: ", ")
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var previousAddress: Address?
    private var lastUpdateTime: Date?
    private var testIndex = 0
    
    private let testCoordinates: [(latitude: Double, longitude: Double)] = [
        (51.697100524640355, -2.5829796037672668),
        (51.67516332778249, -2.62098520043736),
        (51.67516332778248, -2.62098520043735),
        (51.64924416101017, -2.6660494148164005),
        (51.645541521767775, -2.6659134575167327),
        (51.6441810900248, -2.6622519048050606),
        (51.644251133248034, -2.6658230544736745),
        (51.6434797750484, -2.6681738532921466),
        (51.645606290328224, -2.690032591865103),
        (51.645954265539636, -2.71116900134705),
        (51.64533789808418, -2.747411725394253)
    ]
    
    @Published var lastKnownLocation: CLLocationCoordinate2D?
    @Published var lastKnownAddress: Address?
    @Published var speakAfterEveryGeocode: Bool = false // Toggle for speaking after every reverse geocode
    @Published var locationCheckInterval: Int = 10 // Interval for location checks in seconds
    @Published var repeatStreet: Bool = true // Toggle for repeating the street
    @Published var repeatTown: Bool = true // Toggle for repeating the town
    @Published var repeatCounty: Bool = true // Toggle for repeating the county
    @Published var repeatAdministrativeArea: Bool = true // Toggle for repeating the administrative area (country)
    @Published var testMode: Bool = false // Toggle for test mode
    
    var onAddressChange: ((Address) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        
        // Enable background location updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Set up audio session for background playback
        setupAudioSession()
        
        // Observe interruptions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    func requestLocation() {
        locationManager.requestLocation()
    }

    private func checkForAddressChange() {
        guard let currentAddress = lastKnownAddress else { return }
        
        var includeStreet = repeatStreet
        var includeTown = repeatTown
        var includeCounty = repeatCounty
        var includeAdministrativeArea = repeatAdministrativeArea
        
        if let previousAddress = previousAddress {
            if !repeatStreet && previousAddress.street != currentAddress.street {
                includeStreet = true
            }
            if !repeatTown && previousAddress.town != currentAddress.town {
                includeTown = true
            }
            if !repeatCounty && previousAddress.county != currentAddress.county {
                includeCounty = true
            }
            if !repeatAdministrativeArea && previousAddress.administrativeArea != currentAddress.administrativeArea {
                includeAdministrativeArea = true
            }
        }
        
        if previousAddress != currentAddress {
            previousAddress = currentAddress
            let addressString = currentAddress.toString(includeStreet: includeStreet, includeTown: includeTown, includeCounty: includeCounty, includeAdministrativeArea: includeAdministrativeArea)
            onAddressChange?(currentAddress)
            speak(address: currentAddress, includeStreet: includeStreet, includeTown: includeTown, includeCounty: includeCounty, includeAdministrativeArea: includeAdministrativeArea)
        } else {
            print("Address has not changed.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if testMode { return } // Ignore real location updates in test mode
        
        if let location = locations.last {
            let currentTime = Date()
            if let lastTime = lastUpdateTime, currentTime.timeIntervalSince(lastTime) < TimeInterval(locationCheckInterval) {
                // Skip this update if it's within the selected interval of the last update
                return
            }
            lastUpdateTime = currentTime
            
            lastKnownLocation = location.coordinate
            print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            reverseGeocode(location: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get user location: \(error.localizedDescription)")
    }

    private func reverseGeocode(location: CLLocation, completion: (() -> Void)? = nil) {
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            if let error = error {
                print("Failed to reverse geocode location: \(error.localizedDescription)")
                return
            }
            
            guard let placemark = placemarks?.first else {
                print("No placemarks found")
                return
            }
            
            let county = placemark.subAdministrativeArea ?? "N/A"
            let town = placemark.locality ?? "N/A"
            let street = placemark.thoroughfare ?? "N/A"
            let administrativeArea = placemark.administrativeArea ?? "N/A"
            
            let address = Address(street: street, town: town, county: county, administrativeArea: administrativeArea)
            self?.lastKnownAddress = address
            if let addressJSON = self?.lastKnownAddress?.toJSON() {
                print("Resolved Address JSON: \(addressJSON)")
            }
            
            completion?()
            
            if self?.speakAfterEveryGeocode == true {
                self?.speak(address: address, includeStreet: self?.repeatStreet ?? true, includeTown: self?.repeatTown ?? true, includeCounty: self?.repeatCounty ?? true, includeAdministrativeArea: self?.repeatAdministrativeArea ?? true)
            } else {
                self?.checkForAddressChange()
            }
        }
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            print("Audio session activated for background playback.")
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        if interruptionType == .began {
            // Interruption began, pause speech if necessary
            if speechSynthesizer.isSpeaking {
                print("Speech interrupted, stopping immediately.")
                speechSynthesizer.stopSpeaking(at: .immediate)
            }
        } else if interruptionType == .ended {
            // Interruption ended, resume speech if necessary
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                print("Speech interruption ended, resuming.")
                if let address = lastKnownAddress {
                    speak(address: address, includeStreet: repeatStreet, includeTown: repeatTown, includeCounty: repeatCounty, includeAdministrativeArea: repeatAdministrativeArea)
                }
            }
        }
    }

    private func speak(address: Address, includeStreet: Bool = true, includeTown: Bool = true, includeCounty: Bool = true, includeAdministrativeArea: Bool = true) {
        guard AVSpeechSynthesisVoice.speechVoices().count > 0 else {
            print("No available voices.")
            return
        }
        let utterance = AVSpeechUtterance(string: address.toString(includeStreet: includeStreet, includeTown: includeTown, includeCounty: includeCounty, includeAdministrativeArea: includeAdministrativeArea))
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        print("Speaking address: \(address.toString(includeStreet: includeStreet, includeTown: includeTown, includeCounty: includeCounty, includeAdministrativeArea: includeAdministrativeArea))")
        speechSynthesizer.speak(utterance)
        print("Utterance spoken: \(utterance.speechString)")
    }
    
    func logTestLocation() {
        let testCoordinate = testCoordinates[testIndex]
        testIndex = (testIndex + 1) % testCoordinates.count
        
        lastKnownLocation = CLLocationCoordinate2D(latitude: testCoordinate.latitude, longitude: testCoordinate.longitude)
        print("Test location logged: \(testCoordinate.latitude), \(testCoordinate.longitude)")
        
        // Reverse geocode the test location without calling checkForAddressChange from reverseGeocode
        geocoder.reverseGeocodeLocation(CLLocation(latitude: testCoordinate.latitude, longitude: testCoordinate.longitude)) { [weak self] (placemarks, error) in
            if let error = error {
                print("Failed to reverse geocode test location: \(error.localizedDescription)")
                return
            }
            
            guard let placemark = placemarks?.first else {
                print("No placemarks found")
                return
            }
            
            let county = placemark.subAdministrativeArea ?? "N/A"
            let town = placemark.locality ?? "N/A"
            let street = placemark.thoroughfare ?? "N/A"
            let administrativeArea = placemark.administrativeArea ?? "N/A"
            
            let address = Address(street: street, town: town, county: county, administrativeArea: administrativeArea)
            self?.lastKnownAddress = address
            if let addressJSON = self?.lastKnownAddress?.toJSON() {
                print("Resolved Test Address JSON: \(addressJSON)")
            }
            
            self?.checkForAddressChange()
        }
    }
}
