import Foundation
import CoreLocation
import AVFoundation

@MainActor
class LocationManager: NSObject, ObservableObject, @MainActor CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let speechDelegate = SpeechSynthesizerDelegateBridge()
    private var previousAddress: Address?
    private var lastUpdateTime: Date?
    private var testIndex = 0
    private var announcementQueue = AnnouncementQueue()
    private var delayWorkItem: DispatchWorkItem?
    private var currentlySpeakingBoundary: BoundaryType?
    private let factGenerator: PlaceFactGenerating
    private var inFlightFactTask: Task<Void, Never>?
    private var activeAnnouncementToken = UUID()
    private var wantsRideTracking = false

    @Published var lastKnownLocation: CLLocationCoordinate2D?
    @Published var lastKnownAddress: Address?
    @Published var speakAfterEveryGeocode: Bool = false
    @Published var locationCheckInterval: Int = 10
    @Published var announceStreet: Bool = false
    @Published var announceTown: Bool = true
    @Published var announceCounty: Bool = true
    @Published var announceNation: Bool = true
    @Published var announceCountry: Bool = true
    @Published var contentMode: ContentMode = .natural
    @Published var bluetoothDelaySeconds: Double = 0.5
    @Published var testMode: Bool = false
    @Published private(set) var isTracking = false

    var onAddressChange: ((Address) -> Void)?
    var onRideLog: ((CLLocationCoordinate2D, Address, String?) -> Void)?

    init(factGenerator: PlaceFactGenerating? = nil) {
        self.factGenerator = factGenerator ?? Self.makeDefaultFactGenerator()
        super.init()
        speechDelegate.onFinish = { [weak self] in
            Task { @MainActor in
                self?.currentlySpeakingBoundary = nil
            }
        }
        speechDelegate.onCancel = { [weak self] in
            Task { @MainActor in
                self?.currentlySpeakingBoundary = nil
            }
        }
        speechSynthesizer.delegate = speechDelegate
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.pausesLocationUpdatesAutomatically = false

        setupAudioSession()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    private static func makeDefaultFactGenerator() -> PlaceFactGenerating {
        CachedPlaceFactGenerator(generator: ProxyFactGenerator())
    }

    func requestLocation() {
        locationManager.requestLocation()
    }

    /// Requests location permission and starts ride tracking. Call after onboarding completes.
    func beginRideTracking() {
        wantsRideTracking = true
        startRideTrackingIfAuthorized()
    }

    func pauseRideTracking() {
        wantsRideTracking = false
        locationManager.stopUpdatingLocation()
        isTracking = false
    }

    private func startRideTrackingIfAuthorized() {
        guard wantsRideTracking else { return }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
            isTracking = false
        case .authorizedAlways:
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.startUpdatingLocation()
            isTracking = true
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
            locationManager.allowsBackgroundLocationUpdates = false
            locationManager.startUpdatingLocation()
            isTracking = true
        case .denied, .restricted:
            locationManager.stopUpdatingLocation()
            isTracking = false
        @unknown default:
            locationManager.stopUpdatingLocation()
            isTracking = false
        }
    }

    private var boundarySettings: BoundaryAnnouncementSettings {
        BoundaryAnnouncementSettings(
            announceCountry: announceCountry,
            announceNation: announceNation,
            announceCounty: announceCounty,
            announceTown: announceTown,
            announceStreet: announceStreet
        )
    }

    private var legacyRepeatPreferences: RepeatPreferences {
        RepeatPreferences(
            repeatStreet: announceStreet,
            repeatTown: announceTown,
            repeatCounty: announceCounty,
            repeatAdministrativeArea: announceNation
        )
    }

    private func checkForAddressChange() {
        guard let currentAddress = lastKnownAddress else { return }
        processResolvedAddress(currentAddress)
    }

    private func processResolvedAddress(_ address: Address) {
        if speakAfterEveryGeocode {
            handleDebugSpeech(for: address)
            return
        }

        guard let plan = AnnouncementPolicy.plan(
            previous: previousAddress,
            current: address,
            settings: boundarySettings,
            mode: contentMode
        ) else {
            if previousAddress != address {
                previousAddress = address
            }
            if testMode {
                recordTestLog(utteredPhrase: nil)
            }
            print("No announcement required.")
            return
        }

        previousAddress = address
        if !testMode {
            onAddressChange?(address)
        }

        if contentMode == .shortFacts {
            fetchFactAndEnqueue(plan: plan, address: address)
        } else if contentMode != .quiet {
            enqueueAnnouncement(plan)
        } else if testMode {
            recordTestLog(utteredPhrase: nil)
        }
    }

    private func recordTestLog(utteredPhrase: String?) {
        guard testMode,
              let location = lastKnownLocation,
              let address = lastKnownAddress else { return }
        onRideLog?(location, address, utteredPhrase)
    }

    private func fetchFactAndEnqueue(plan: AnnouncementPlan, address: Address) {
        let token = UUID()
        activeAnnouncementToken = token
        inFlightFactTask?.cancel()
        cancelPendingAnnouncement()

        let request = AnnouncementPolicy.factRequest(for: plan, address: address)
        let generator = factGenerator

        inFlightFactTask = Task { [weak self] in
            let fact = await PlaceFactFetcher.fact(for: request, using: generator)
            await MainActor.run {
                guard let self, !Task.isCancelled, self.activeAnnouncementToken == token else { return }
                let text = FactPhraseBuilder.utterance(basePhrase: plan.text, fact: fact)
                self.enqueueAnnouncement(AnnouncementPlan(text: text, boundary: plan.boundary))
            }
        }
    }

    private func handleDebugSpeech(for address: Address) {
        guard contentMode != .quiet else { return }

        guard let speechText = AnnouncementDecision.speechText(
            for: address,
            previous: previousAddress,
            preferences: legacyRepeatPreferences,
            speakAfterEveryGeocode: true
        ) else {
            return
        }

        previousAddress = address
        let plan = AnnouncementPlan(text: speechText, boundary: .town)
        enqueueAnnouncement(plan)
    }

    private func enqueueAnnouncement(_ plan: AnnouncementPlan) {
        if speechSynthesizer.isSpeaking, let speakingBoundary = currentlySpeakingBoundary {
            if AnnouncementQueue.shouldDropWhileSpeaking(
                newBoundary: plan.boundary,
                currentlySpeaking: speakingBoundary
            ) {
                print("Dropped lower-priority announcement: \(plan.text)")
                return
            }

            if AnnouncementQueue.shouldInterrupt(
                newBoundary: plan.boundary,
                currentlySpeaking: speakingBoundary
            ) {
                speechSynthesizer.stopSpeaking(at: .immediate)
                currentlySpeakingBoundary = nil
            }
        }

        let request = announcementQueue.replacePending(text: plan.text, boundary: plan.boundary)
        delayWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.deliverAnnouncement(id: request.id)
        }
        delayWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + bluetoothDelaySeconds,
            execute: workItem
        )
        print("Queued announcement after \(bluetoothDelaySeconds)s: \(plan.text)")
    }

    private func cancelPendingAnnouncement() {
        delayWorkItem?.cancel()
        delayWorkItem = nil
        announcementQueue.clearPending()
    }

    private func deliverAnnouncement(id: UUID) {
        guard let pending = announcementQueue.pending, pending.id == id else {
            print("Skipped stale announcement.")
            return
        }

        if speechSynthesizer.isSpeaking, let speakingBoundary = currentlySpeakingBoundary {
            if AnnouncementQueue.shouldDropWhileSpeaking(
                newBoundary: pending.boundary,
                currentlySpeaking: speakingBoundary
            ) {
                announcementQueue.clearPending(id: id)
                print("Dropped stale lower-priority announcement at delivery.")
                return
            }

            if AnnouncementQueue.shouldInterrupt(
                newBoundary: pending.boundary,
                currentlySpeaking: speakingBoundary
            ) {
                speechSynthesizer.stopSpeaking(at: .immediate)
            }
        }

        announcementQueue.clearPending(id: id)
        speak(text: pending.text, boundary: pending.boundary)
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

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startRideTrackingIfAuthorized()
    }

    private func reverseGeocode(location: CLLocation, completion: (@MainActor () -> Void)? = nil) {
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
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lastKnownAddress = address
                if let addressJSON = address.toJSON() {
                    print("Resolved Address JSON: \(addressJSON)")
                }

                completion?()
                self.processResolvedAddress(address)
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
            if speechSynthesizer.isSpeaking {
                print("Speech interrupted, stopping immediately.")
                speechSynthesizer.stopSpeaking(at: .immediate)
                currentlySpeakingBoundary = nil
            }
        } else if interruptionType == .ended {
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume),
               let pending = announcementQueue.pending {
                print("Speech interruption ended, resuming pending announcement.")
                deliverAnnouncement(id: pending.id)
            }
        }
    }

    private func speak(text: String, boundary: BoundaryType? = nil) {
        guard contentMode != .quiet else { return }
        guard AVSpeechSynthesisVoice.speechVoices().count > 0 else {
            print("No available voices.")
            return
        }

        currentlySpeakingBoundary = boundary
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        print("Speaking: \(text)")
        recordTestLog(utteredPhrase: text)
        speechSynthesizer.speak(utterance)
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
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lastKnownAddress = address
                if let addressJSON = address.toJSON() {
                    print("Resolved Test Address JSON: \(addressJSON)")
                }

                self.processResolvedAddress(address)
            }
        }
    }
}

private final class SpeechSynthesizerDelegateBridge: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onFinish: (@Sendable () -> Void)?
    var onCancel: (@Sendable () -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onCancel?()
    }
}
