import Foundation
import CoreLocation
import AVFoundation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var previousAddress: Address?
    private var lastUpdateTime: Date?
    private var testIndex = 0

    @Published var lastKnownLocation: CLLocationCoordinate2D?
    @Published var lastKnownAddress: Address?
    @Published var speakAfterEveryGeocode: Bool = false
    @Published var locationCheckInterval: Int = 10
    @Published var repeatStreet: Bool = true
    @Published var repeatTown: Bool = true
    @Published var repeatCounty: Bool = true
    @Published var repeatAdministrativeArea: Bool = true
    @Published var testMode: Bool = false

    var onAddressChange: ((Address) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()

        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

        setupAudioSession()

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

    private var repeatPreferences: RepeatPreferences {
        AnnouncementDecision.repeatPreferences(
            repeatStreet: repeatStreet,
            repeatTown: repeatTown,
            repeatCounty: repeatCounty,
            repeatAdministrativeArea: repeatAdministrativeArea
        )
    }

    private func checkForAddressChange() {
        guard let currentAddress = lastKnownAddress else { return }

        guard let speechText = AnnouncementDecision.speechText(
            for: currentAddress,
            previous: previousAddress,
            preferences: repeatPreferences,
            speakAfterEveryGeocode: false
        ) else {
            print("Address has not changed.")
            return
        }

        previousAddress = currentAddress
        onAddressChange?(currentAddress)
        speak(text: speechText)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if testMode { return }

        if let location = locations.last {
            let currentTime = Date()
            if let lastTime = lastUpdateTime,
               currentTime.timeIntervalSince(lastTime) < TimeInterval(locationCheckInterval) {
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
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let error = error {
                print("Failed to reverse geocode location: \(error.localizedDescription)")
                return
            }

            guard let placemark = placemarks?.first else {
                print("No placemarks found")
                return
            }

            let address = Address(placemark: placemark)
            self?.lastKnownAddress = address
            if let addressJSON = address.toJSON() {
                print("Resolved Address JSON: \(addressJSON)")
            }

            completion?()
            self?.handleResolvedAddress(address)
        }
    }

    private func handleResolvedAddress(_ address: Address) {
        if speakAfterEveryGeocode {
            if let speechText = AnnouncementDecision.speechText(
                for: address,
                previous: previousAddress,
                preferences: repeatPreferences,
                speakAfterEveryGeocode: true
            ) {
                speak(text: speechText)
            }
            return
        }

        checkForAddressChange()
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
            if speechSynthesizer.isSpeaking {
                print("Speech interrupted, stopping immediately.")
                speechSynthesizer.stopSpeaking(at: .immediate)
            }
        } else if interruptionType == .ended {
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume),
               let address = lastKnownAddress,
               let speechText = AnnouncementDecision.speechText(
                   for: address,
                   previous: previousAddress,
                   preferences: repeatPreferences,
                   speakAfterEveryGeocode: speakAfterEveryGeocode
               ) {
                print("Speech interruption ended, resuming.")
                speak(text: speechText)
            }
        }
    }

    private func speak(text: String) {
        guard AVSpeechSynthesisVoice.speechVoices().count > 0 else {
            print("No available voices.")
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        print("Speaking address: \(text)")
        speechSynthesizer.speak(utterance)
        print("Utterance spoken: \(utterance.speechString)")
    }

    func logTestLocation() {
        let waypoint = TestRouteFixture.waypoint(at: testIndex)
        testIndex = (testIndex + 1) % TestRouteFixture.waypoints.count

        lastKnownLocation = waypoint.coordinate
        print("Test location logged: \(waypoint.name) - \(waypoint.latitude), \(waypoint.longitude)")

        geocoder.reverseGeocodeLocation(CLLocation(latitude: waypoint.latitude, longitude: waypoint.longitude)) { [weak self] placemarks, error in
            if let error = error {
                print("Failed to reverse geocode test location: \(error.localizedDescription)")
                return
            }

            guard let placemark = placemarks?.first else {
                print("No placemarks found")
                return
            }

            let address = Address(placemark: placemark)
            self?.lastKnownAddress = address
            if let addressJSON = address.toJSON() {
                print("Resolved Test Address JSON: \(addressJSON)")
            }

            self?.checkForAddressChange()
        }
    }
}
