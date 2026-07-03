import Foundation
import CoreLocation
import AVFoundation

enum LocationServiceStatus: Equatable {
    case checking
    case waitingForPermission
    case denied
    case restricted
    case active
    case locationUnavailable(String)
    case placeUnavailable(String)

    var riderMessage: String {
        switch self {
        case .checking:
            return "Checking location..."
        case .waitingForPermission:
            return "Waiting for location permission."
        case .denied:
            return "Location access is off."
        case .restricted:
            return "Location access is restricted."
        case .active:
            return "Location is active."
        case .locationUnavailable(let message), .placeUnavailable(let message):
            return message
        }
    }

    var needsSettingsAction: Bool {
        switch self {
        case .denied, .restricted:
            return true
        case .checking, .waitingForPermission, .active, .locationUnavailable, .placeUnavailable:
            return false
        }
    }
}

struct SpeechVoiceOption: Identifiable, Hashable {
    let identifier: String
    let displayName: String
    let localeIdentifier: String
    let quality: AVSpeechSynthesisVoiceQuality

    var id: String { identifier }

    var isRecommended: Bool {
        localeIdentifier.hasPrefix("en-GB") && quality == .premium
    }

    var isSafeDefaultCandidate: Bool {
        quality == .premium || quality == .enhanced
    }

    var qualityDescription: String {
        switch quality {
        case .premium:
            return "Premium"
        case .enhanced:
            return "Enhanced"
        case .default:
            return "Default"
        @unknown default:
            return "Default"
        }
    }

    var displayLabel: String {
        "\(displayName) · \(localeIdentifier) · \(qualityDescription)"
    }

    var pickerLabel: String {
        if isRecommended {
            return "\(displayLabel) · Premium"
        }

        return displayLabel
    }

    var compactLabel: String {
        displayLabel
    }
}

private enum LocationManagerDefaults {
    static let preferredVoiceIdentifierKey = "MotoGuidePreferredVoiceIdentifier"
    static let speechProviderKey = "MotoGuideSpeechProvider"
    static let interruptsMusicKey = "MotoGuideInterruptsMusic"
    static let homeCountryKey = "MotoGuideHomeCountry"
    static let homeRegionKey = "MotoGuideHomeRegion"
    static let familiarRegionsKey = "MotoGuideFamiliarRegions"
    static let customFactInstructionsKey = "MotoGuideCustomFactInstructions"
    static let factInterestCategoriesKey = "MotoGuideFactInterestCategories"
}

enum SpeechProvider: String, CaseIterable, Identifiable {
    case apple
    case proxyElevenLabs

    var id: String { rawValue }

    var label: String {
        switch self {
        case .apple: return "Apple voices (recommended)"
        case .proxyElevenLabs: return "Premium voice (ElevenLabs)"
        }
    }
}

@MainActor
class LocationManager: NSObject, ObservableObject, @MainActor CLLocationManagerDelegate, AVAudioPlayerDelegate {
    static let movingMapInteractionThresholdMetersPerSecond = 8.0 / 3.6

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let speechDelegate = SpeechSynthesizerDelegateBridge()
    private let proxySpeechGenerator = ProxySpeechGenerator()
    private var proxyAudioPlayer: AVAudioPlayer?
    private var speechPlaybackToken = UUID()
    private var previousAddress: Address?
    private var lastUpdateTime: Date?
    private var testIndex = 0
    private var announcementQueue = AnnouncementQueue()
    private var delayWorkItem: DispatchWorkItem?
    private var currentlySpeakingBoundary: BoundaryType?
    private var activeSpeechPlan: AnnouncementPlan?
    private var interruptedSpeechPlan: AnnouncementPlan?
    private var interruptionResumeWorkItem: DispatchWorkItem?
    private let factGenerator: PlaceFactGenerating
    private var inFlightFactTask: Task<Void, Never>?
    private var activeAnnouncementToken = UUID()
    private var wantsRideTracking = false
    private let externalAudioResumeDelaySeconds: TimeInterval = 3

    @Published var lastKnownLocation: CLLocationCoordinate2D?
    @Published var lastKnownAddress: Address?
    @Published var speakAfterEveryGeocode: Bool = false
    @Published var locationCheckInterval: Int = 10
    @Published var announceStreet: Bool = false
    @Published var announceTown: Bool = true
    @Published var announceCounty: Bool = true
    @Published var announceNation: Bool = true
    @Published var announceCountry: Bool = true
    @Published var contentMode: ContentMode = .shortFacts
    @Published var bluetoothDelaySeconds: Double = 0.5
    @Published var testMode: Bool = false
    @Published var interruptsMusic: Bool = {
        guard UserDefaults.standard.object(forKey: LocationManagerDefaults.interruptsMusicKey) != nil else {
            return true
        }
        return UserDefaults.standard.bool(forKey: LocationManagerDefaults.interruptsMusicKey)
    }() {
        didSet {
            UserDefaults.standard.set(interruptsMusic, forKey: LocationManagerDefaults.interruptsMusicKey)
            setupAudioSession()
        }
    }
    @Published var preferredVoiceIdentifier: String = UserDefaults.standard.string(
        forKey: LocationManagerDefaults.preferredVoiceIdentifierKey
    ) ?? "" {
        didSet {
            UserDefaults.standard.set(preferredVoiceIdentifier, forKey: LocationManagerDefaults.preferredVoiceIdentifierKey)
        }
    }

    @Published var speechProvider: SpeechProvider = SpeechProvider(
        rawValue: UserDefaults.standard.string(forKey: LocationManagerDefaults.speechProviderKey) ?? ""
    ) ?? .apple {
        didSet {
            UserDefaults.standard.set(speechProvider.rawValue, forKey: LocationManagerDefaults.speechProviderKey)
        }
    }

    @Published var homeCountry: String = UserDefaults.standard.string(forKey: LocationManagerDefaults.homeCountryKey) ?? "" {
        didSet {
            UserDefaults.standard.set(homeCountry, forKey: LocationManagerDefaults.homeCountryKey)
        }
    }

    @Published var homeRegion: String = UserDefaults.standard.string(forKey: LocationManagerDefaults.homeRegionKey) ?? "" {
        didSet {
            UserDefaults.standard.set(homeRegion, forKey: LocationManagerDefaults.homeRegionKey)
        }
    }

    @Published var familiarRegions: String = UserDefaults.standard.string(
        forKey: LocationManagerDefaults.familiarRegionsKey
    ) ?? "" {
        didSet {
            UserDefaults.standard.set(familiarRegions, forKey: LocationManagerDefaults.familiarRegionsKey)
        }
    }

    @Published var customFactInstructions: String = UserDefaults.standard.string(
        forKey: LocationManagerDefaults.customFactInstructionsKey
    ) ?? "" {
        didSet {
            UserDefaults.standard.set(customFactInstructions, forKey: LocationManagerDefaults.customFactInstructionsKey)
        }
    }
    @Published var factInterestCategories: [FactInterestCategory] = LocationManager.loadFactInterestCategories() {
        didSet {
            UserDefaults.standard.set(
                factInterestCategories
                    .map(\.rawValue)
                    .joined(separator: ","),
                forKey: LocationManagerDefaults.factInterestCategoriesKey
            )
        }
    }
    @Published private(set) var isTracking = false
    @Published private(set) var lastSpokenPhrase: String?
    @Published private(set) var lastSpokenAt: Date?
    @Published private(set) var locationStatus: LocationServiceStatus = .checking
    @Published private(set) var currentSpeedMetersPerSecond: CLLocationSpeed?

    var allowsMapInteraction: Bool {
        true
    }

    private var isSpeechOutputActive: Bool {
        speechSynthesizer.isSpeaking || proxyAudioPlayer?.isPlaying == true
    }

    private var shouldYieldToPrimaryAudio: Bool {
        AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
    }

    var onAddressChange: ((Address) -> Void)?
    var onRideLog: ((CLLocationCoordinate2D, Address, String?) -> Void)?

    init(factGenerator: PlaceFactGenerating? = nil) {
        self.factGenerator = factGenerator ?? Self.makeDefaultFactGenerator()
        super.init()
        speechDelegate.onFinish = { [weak self] in
            Task { @MainActor in
                self?.activeSpeechPlan = nil
                self?.currentlySpeakingBoundary = nil
            }
        }
        speechDelegate.onCancel = { [weak self] in
            Task { @MainActor in
                self?.activeSpeechPlan = nil
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSecondaryAudioHint(_:)),
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: AVAudioSession.sharedInstance()
        )

        ensurePreferredVoiceSelection()
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
            locationStatus = .waitingForPermission
            isTracking = false
        case .authorizedAlways:
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.startUpdatingLocation()
            locationStatus = .active
            isTracking = true
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
            locationManager.allowsBackgroundLocationUpdates = false
            locationManager.startUpdatingLocation()
            locationStatus = .active
            isTracking = true
        case .denied, .restricted:
            locationManager.stopUpdatingLocation()
            locationStatus = locationManager.authorizationStatus == .denied ? .denied : .restricted
            isTracking = false
        @unknown default:
            locationManager.stopUpdatingLocation()
            locationStatus = .locationUnavailable("Location is unavailable on this device.")
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

    private var riderContext: RiderContext {
        RiderContext(
            homeCountry: normalizeContextValue(homeCountry),
            homeRegion: normalizeContextValue(homeRegion),
            familiarRegions: parseFamiliarRegionsNormalized(),
            factInterestCategories: factInterestCategories,
            customFactInstructions: normalizeContextValue(customFactInstructions)
        )
    }

    func availableSpeechVoices() -> [SpeechVoiceOption] {
        let englishVoices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("en")
        }

        let options = englishVoices
            .filter { !$0.identifier.isEmpty && !$0.language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { voice in
                SpeechVoiceOption(
                    identifier: voice.identifier,
                    displayName: voice.name,
                    localeIdentifier: voice.language,
                    quality: voice.quality
                )
            }
            .sorted { lhs, rhs in
                if lhs.isRecommended != rhs.isRecommended {
                    return lhs.isRecommended
                }

                let lhsIsGb = lhs.localeIdentifier.hasPrefix("en-GB")
                let rhsIsGb = rhs.localeIdentifier.hasPrefix("en-GB")
                if lhsIsGb != rhsIsGb {
                    return lhsIsGb
                }

                if lhs.quality != rhs.quality {
                    return Self.speechQualityRank(lhs.quality) > Self.speechQualityRank(rhs.quality)
                }

                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        var deduped: [SpeechVoiceOption] = []
        var seen: Set<String> = []
        for option in options {
            if deduped.count >= 4 { break }
            if seen.insert(option.identifier).inserted {
                deduped.append(option)
            }
        }

        if deduped.count < 4 {
            for option in options
                .filter({ !deduped.contains($0) }) {
                if deduped.count >= 4 { break }
                deduped.append(option)
            }
        }

        return deduped
    }

    func recommendedSpeechVoice() -> SpeechVoiceOption? {
        availableSpeechVoices().first(where: { $0.isSafeDefaultCandidate })
    }

    func previewSelectedVoice() {
        stopSpeechOutput()
        announcementQueue.clearPending()
        speak(
            text: "MotoGuide can speak in this voice. Keep the road in front of you, rider.",
            shouldRecordTestLog: false,
            ignoreQuietMode: true
        )
    }

    private func normalizeContextValue(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func loadFactInterestCategories() -> [FactInterestCategory] {
        let stored = UserDefaults.standard.string(forKey: LocationManagerDefaults.factInterestCategoriesKey) ?? ""
        let values = stored
            .split(separator: ",")
            .compactMap { normalizeFactInterestCategory(String($0)) }
        return values.isEmpty ? FactInterestCategory.defaultSelections : values
    }

    private static func normalizeFactInterestCategory(_ value: String) -> FactInterestCategory? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized == "safetyAdvice" {
            return .localRidingHints
        }
        return FactInterestCategory(rawValue: normalized)
    }

    private func parseFamiliarRegionsNormalized() -> [String] {
        let rawRegions = familiarRegions
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var values: [String] = []
        for region in rawRegions {
            let normalized = region.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty, !values.contains(normalized) {
                values.append(normalized)
            }
        }
        return values
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

        if let factMode = contentMode.factMode {
            fetchFactAndEnqueue(plan: plan, address: address, mode: factMode)
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

    private func fetchFactAndEnqueue(plan: AnnouncementPlan, address: Address, mode: FactMode) {
        let token = UUID()
        activeAnnouncementToken = token
        inFlightFactTask?.cancel()
        cancelPendingAnnouncement()

        let request = AnnouncementPolicy.factRequest(
            for: plan,
            address: address,
            mode: mode,
            riderContext: riderContext
        )
        let generator = factGenerator

        inFlightFactTask = Task { [weak self] in
            let fact = await PlaceFactFetcher.fact(for: request, using: generator)
            await MainActor.run {
                guard let self, !Task.isCancelled, self.activeAnnouncementToken == token else { return }
                if fact == nil {
                    ProxyDiagnostics.log("Facts", "No proxy fact available. Speaking base phrase for \(request.cacheKey).")
                }
                let text = FactPhraseBuilder.utterance(basePhrase: plan.text, fact: fact, mode: mode)
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
        if isSpeechOutputActive, let speakingBoundary = currentlySpeakingBoundary {
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
                stopSpeechOutput()
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

        if isSpeechOutputActive, let speakingBoundary = currentlySpeakingBoundary {
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
                stopSpeechOutput()
            }
        }

        announcementQueue.clearPending(id: id)
        speak(text: pending.text, boundary: pending.boundary)
    }

    func repeatCurrentAnnouncement() {
        guard contentMode != .quiet else { return }
        guard let text = lastSpokenPhrase ?? currentLocationPhrase() else { return }
        if isSpeechOutputActive {
            stopSpeechOutput()
            return
        }

        delayWorkItem?.cancel()
        announcementQueue.clearPending()
        stopSpeechOutput()
        speak(text: text, boundary: currentlySpeakingBoundary, shouldRecordTestLog: false)
    }

    private func currentLocationPhrase() -> String? {
        guard let address = lastKnownAddress else { return nil }
        let speechMode = AnnouncementPhraseBuilder.baseSpeechMode(for: contentMode)
        return AnnouncementPhraseBuilder.locationPhrase(in: address, mode: speechMode)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if testMode { return }

        if let location = locations.last {
            lastKnownLocation = location.coordinate
            currentSpeedMetersPerSecond = location.speed
            locationStatus = .active

            let currentTime = Date()
            if let lastTime = lastUpdateTime,
               currentTime.timeIntervalSince(lastTime) < TimeInterval(locationCheckInterval) {
                return
            }
            lastUpdateTime = currentTime

            print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            reverseGeocode(location: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationStatus = .locationUnavailable("Location update failed. MotoGuide will keep trying.")
        print("Failed to get user location: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startRideTrackingIfAuthorized()
    }

    private func reverseGeocode(location: CLLocation, completion: (@MainActor () -> Void)? = nil) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let error = error {
                Task { @MainActor [weak self] in
                    self?.locationStatus = .placeUnavailable("Place lookup failed. GPS is still active.")
                }
                print("Failed to reverse geocode location: \(error.localizedDescription)")
                return
            }

            guard let placemark = placemarks?.first else {
                Task { @MainActor [weak self] in
                    self?.locationStatus = .placeUnavailable("Place name is unavailable here.")
                }
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
        var options: AVAudioSession.CategoryOptions = [.mixWithOthers]
        if interruptsMusic {
            options.insert(.duckOthers)
        }

        do {
            try audioSession.setCategory(.playback, mode: .default, options: options)
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
            pauseForPrimaryAudio(reason: "Audio session interruption began.")
        } else if interruptionType == .ended {
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                scheduleInterruptedSpeechResume(reason: "Audio session interruption ended.")
            }
        }
    }

    @objc private func handleSecondaryAudioHint(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
              let hintType = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue) else {
            return
        }

        switch hintType {
        case .begin:
            pauseForPrimaryAudio(reason: "Primary audio started.")
        case .end:
            scheduleInterruptedSpeechResume(reason: "Primary audio ended.")
        @unknown default:
            return
        }
    }

    private func pauseForPrimaryAudio(reason: String) {
        interruptionResumeWorkItem?.cancel()
        interruptionResumeWorkItem = nil

        if let activeSpeechPlan {
            interruptedSpeechPlan = activeSpeechPlan
        } else if let pending = announcementQueue.pending {
            interruptedSpeechPlan = AnnouncementPlan(text: pending.text, boundary: pending.boundary)
            announcementQueue.clearPending(id: pending.id)
            delayWorkItem?.cancel()
            delayWorkItem = nil
        }

        if isSpeechOutputActive {
            print("\(reason) MotoGuide speech stopped.")
            stopSpeechOutput()
        }
    }

    private func scheduleInterruptedSpeechResume(reason: String) {
        guard let plan = interruptedSpeechPlan else { return }

        interruptionResumeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.interruptedSpeechPlan == plan else { return }
            self.interruptedSpeechPlan = nil
            self.speak(text: plan.text, boundary: plan.boundary, shouldRecordTestLog: false)
        }
        interruptionResumeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + externalAudioResumeDelaySeconds, execute: workItem)
        print("\(reason) MotoGuide will resume after \(externalAudioResumeDelaySeconds)s.")
    }

    private func speak(
        text: String,
        boundary: BoundaryType? = nil,
        shouldRecordTestLog: Bool = true,
        ignoreQuietMode: Bool = false
    ) {
        guard ignoreQuietMode || contentMode != .quiet else { return }
        if shouldYieldToPrimaryAudio {
            interruptedSpeechPlan = AnnouncementPlan(text: text, boundary: boundary ?? .street)
            print("Primary audio is active. MotoGuide speech deferred.")
            return
        }
        currentlySpeakingBoundary = boundary
        activeSpeechPlan = AnnouncementPlan(text: text, boundary: boundary ?? .street)
        print("Speaking: \(text)")
        lastSpokenPhrase = text
        lastSpokenAt = Date()
        if shouldRecordTestLog {
            recordTestLog(utteredPhrase: text)
        }

        if speechProvider == .proxyElevenLabs {
            speakWithProxy(text: text, boundary: boundary)
            return
        }

        speakWithApple(text: text, boundary: boundary)
    }

    private func speakWithApple(text: String, boundary: BoundaryType?) {
        guard AVSpeechSynthesisVoice.speechVoices().count > 0 else {
            print("No available voices.")
            return
        }
        guard let preferredVoice = resolveSpeechVoice() else {
            print("No usable voices.")
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
    }

    private func speakWithProxy(text: String, boundary: BoundaryType?) {
        proxyAudioPlayer?.stop()
        let playbackToken = UUID()
        speechPlaybackToken = playbackToken
        Task { [weak self] in
            guard let self else { return }
            do {
                let audioData = try await proxySpeechGenerator.speechAudio(for: text)
                await MainActor.run {
                    guard self.speechPlaybackToken == playbackToken else { return }
                    do {
                        let player = try AVAudioPlayer(data: audioData)
                        self.proxyAudioPlayer = player
                        player.delegate = self
                        player.prepareToPlay()
                        player.play()
                    } catch {
                        ProxyDiagnostics.log("Speech", "Could not play proxy TTS audio: \(error.localizedDescription). Falling back to Apple speech.")
                        self.speakWithApple(text: text, boundary: boundary)
                    }
                }
            } catch {
                await MainActor.run {
                    ProxyDiagnostics.log("Speech", "Proxy TTS failed: \(error.localizedDescription). Falling back to Apple speech.")
                    self.speakWithApple(text: text, boundary: boundary)
                }
            }
        }
    }

    private func stopSpeechOutput() {
        speechPlaybackToken = UUID()
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        if proxyAudioPlayer?.isPlaying == true {
            proxyAudioPlayer?.stop()
        }
        activeSpeechPlan = nil
        currentlySpeakingBoundary = nil
    }

    private func resolveSpeechVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let preferred = voices.first(where: { $0.identifier == preferredVoiceIdentifier }) {
            return preferred
        }

        return bestVoice(from: voices)
    }

    private func ensurePreferredVoiceSelection() {
        let voices = availableSpeechVoices()
        if let first = voices.first, !first.identifier.isEmpty {
            preferredVoiceIdentifier = voices.first(where: { $0.identifier == preferredVoiceIdentifier })?.identifier
                ?? first.identifier
            return
        }
        preferredVoiceIdentifier = ""
    }

    private func bestVoice(from voices: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
        guard !voices.isEmpty else {
            return nil
        }

        if let preferredGb = voices
            .filter({ $0.language == "en-GB" })
            .max(by: compareVoiceQuality) {
            return preferredGb
        }

        if let preferredEnglish = voices
            .filter({ $0.language.hasPrefix("en") })
            .max(by: compareVoiceQuality) {
            return preferredEnglish
        }

        return voices.max(by: compareVoiceQuality)
    }

    private func compareVoiceQuality(lhs: AVSpeechSynthesisVoice, rhs: AVSpeechSynthesisVoice) -> Bool {
        if Self.speechQualityRank(lhs.quality) != Self.speechQualityRank(rhs.quality) {
            return Self.speechQualityRank(lhs.quality) > Self.speechQualityRank(rhs.quality)
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func speechQualityRank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium:
            return 3
        case .enhanced:
            return 2
        case .default:
            return 1
        @unknown default:
            return 1
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            activeSpeechPlan = nil
            currentlySpeakingBoundary = nil
        }
    }

    func logTestLocation() {
        let waypoint = TestRouteFixture.waypoint(at: testIndex)
        testIndex = (testIndex + 1) % TestRouteFixture.waypoints.count

        lastKnownLocation = waypoint.coordinate
        currentSpeedMetersPerSecond = 0
        locationStatus = .active
        print("Test location logged: \(waypoint.name) - \(waypoint.latitude), \(waypoint.longitude)")

        geocoder.reverseGeocodeLocation(CLLocation(latitude: waypoint.latitude, longitude: waypoint.longitude)) { [weak self] placemarks, error in
            if let error = error {
                Task { @MainActor [weak self] in
                    self?.locationStatus = .placeUnavailable("Test place lookup failed.")
                }
                print("Failed to reverse geocode test location: \(error.localizedDescription)")
                return
            }

            guard let placemark = placemarks?.first else {
                Task { @MainActor [weak self] in
                    self?.locationStatus = .placeUnavailable("Test place name is unavailable.")
                }
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
