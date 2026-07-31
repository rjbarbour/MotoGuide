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
    static let preferredVoiceIdentifierKey = "RideHorizonPreferredVoiceIdentifier"
    static let speechProviderKey = "RideHorizonSpeechProvider"
    static let speechProviderMigrationKey = "RideHorizonSpeechProviderPremiumNoAppleFallbackMigration20260703"
    static let premiumVoiceAppleFallbackEnabledKey = "RideHorizonPremiumVoiceAppleFallbackEnabled"
    static let interruptsMusicKey = "RideHorizonInterruptsMusic"
    static let homeCountryKey = "RideHorizonHomeCountry"
    static let homeRegionKey = "RideHorizonHomeRegion"
    static let familiarRegionsKey = "RideHorizonFamiliarRegions"
    static let customFactInstructionsKey = "RideHorizonCustomFactInstructions"
    static let factInterestCategoriesKey = "RideHorizonFactInterestCategories"
    static let boundarySpeechCooldownSecondsKey = "RideHorizonBoundarySpeechCooldownSeconds"
    static let testModeKey = "RideHorizonTestMode"
}

enum SpeechProvider: String, CaseIterable, Identifiable {
    case apple
    case proxyElevenLabs

    var id: String { rawValue }

    var label: String {
        switch self {
        case .apple: return "Apple voices"
        case .proxyElevenLabs: return "Premium voice (ElevenLabs)"
        }
    }
}

@MainActor
protocol SpeechOutputEngine: AnyObject {
    var isSpeaking: Bool { get }
    var onFinish: (() -> Void)? { get set }
    var onCancel: (() -> Void)? { get set }
    var onDiagnosticNote: ((String) -> Void)? { get set }

    func speak(
        text: String,
        boundary: BoundaryType?,
        provider: SpeechProvider,
        appleVoice: AVSpeechSynthesisVoice?,
        allowAppleFallback: Bool
    )
    func cancelPendingPreparation()
    func stop()
}

@MainActor
protocol AppleSpeechOutputting: AnyObject {
    var isSpeaking: Bool { get }
    var onFinish: (() -> Void)? { get set }
    var onCancel: (() -> Void)? { get set }

    func speak(text: String, boundary: BoundaryType?, voice: AVSpeechSynthesisVoice?)
    func stop()
}

@MainActor
final class AppleSpeechOutput: NSObject, AppleSpeechOutputting, AVSpeechSynthesizerDelegate {
    private let speechSynthesizer = AVSpeechSynthesizer()

    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDiagnosticNote: ((String) -> Void)?

    var isSpeaking: Bool {
        speechSynthesizer.isSpeaking
    }

    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    func speak(text: String, boundary: BoundaryType?, voice: AVSpeechSynthesisVoice?) {
        guard let voice else {
            ProxyDiagnostics.log("Speech", "No usable Apple voice.")
            onFinish?()
            return
        }

        ProxyDiagnostics.log("Speech", "Routing \(boundary?.factLabel ?? "unknown") speech through Apple voice \(voice.identifier).")
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
    }

    func stop() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            onFinish?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            onCancel?()
        }
    }
}

@MainActor
final class DefaultSpeechOutputEngine: NSObject, SpeechOutputEngine, AVAudioPlayerDelegate {
    private let proxySpeechGenerator: ProxySpeechGenerating
    private let appleSpeechOutput: AppleSpeechOutputting
    private var proxyAudioPlayer: AVAudioPlayer?
    private var proxyAudioChunks: [Data] = []
    private var proxyRequestTask: Task<Void, Never>?
    private var playbackToken = UUID()
    private var currentProxyFallbackText = ""
    private var currentProxyFallbackBoundary: BoundaryType?
    private var currentProxyFallbackAppleVoice: AVSpeechSynthesisVoice?
    private var currentProxyAllowsAppleFallback = false

    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDiagnosticNote: ((String) -> Void)?

    var isSpeaking: Bool {
        proxyRequestTask != nil
            || appleSpeechOutput.isSpeaking
            || (proxyAudioPlayer?.isPlaying == true)
            || !proxyAudioChunks.isEmpty
    }

    init(
        proxySpeechGenerator: ProxySpeechGenerating = ProxySpeechGenerator(),
        appleSpeechOutput: AppleSpeechOutputting? = nil
    ) {
        self.proxySpeechGenerator = proxySpeechGenerator
        self.appleSpeechOutput = appleSpeechOutput ?? AppleSpeechOutput()
        super.init()
        self.appleSpeechOutput.onFinish = { [weak self] in
            self?.onFinish?()
        }
        self.appleSpeechOutput.onCancel = { [weak self] in
            self?.onCancel?()
        }
    }

    func speak(
        text: String,
        boundary: BoundaryType?,
        provider: SpeechProvider,
        appleVoice: AVSpeechSynthesisVoice?,
        allowAppleFallback: Bool
    ) {
        switch provider {
        case .proxyElevenLabs:
            speakWithProxy(text: text, boundary: boundary, appleVoice: appleVoice, allowAppleFallback: allowAppleFallback)
        case .apple:
            speakWithApple(text: text, boundary: boundary, appleVoice: appleVoice)
        }
    }

    func stop() {
        playbackToken = UUID()
        proxyRequestTask?.cancel()
        proxyRequestTask = nil
        appleSpeechOutput.stop()
        proxyAudioChunks.removeAll()
        clearProxyFallbackContext()
        onCancel?()
        if proxyAudioPlayer?.isPlaying == true {
            proxyAudioPlayer?.stop()
        }
        proxyAudioPlayer = nil
    }

    func cancelPendingPreparation() {
        guard proxyRequestTask != nil else { return }
        playbackToken = UUID()
        proxyRequestTask?.cancel()
        proxyRequestTask = nil
        proxyAudioChunks.removeAll()
        clearProxyFallbackContext()
        onCancel?()
    }

    private func speakWithProxy(
        text: String,
        boundary: BoundaryType?,
        appleVoice: AVSpeechSynthesisVoice?,
        allowAppleFallback: Bool
    ) {
        proxyRequestTask?.cancel()
        proxyAudioPlayer?.stop()
        proxyAudioChunks.removeAll()
        let token = UUID()
        playbackToken = token
        currentProxyFallbackText = text
        currentProxyFallbackBoundary = boundary
        currentProxyFallbackAppleVoice = appleVoice
        currentProxyAllowsAppleFallback = allowAppleFallback
        ProxyDiagnostics.log(
            "Speech",
            "Routing \(boundary?.factLabel ?? "unknown") speech through Premium Voice, textLength=\(text.count), appleFallbackEnabled=\(allowAppleFallback)."
        )
        let proxySpeechGenerator = proxySpeechGenerator
        proxyRequestTask = Task { [weak self] in
            do {
                let audioDataSegments = try await proxySpeechGenerator.speechAudios(for: text)
                await MainActor.run {
                    guard let self, !Task.isCancelled, self.playbackToken == token else { return }
                    self.proxyRequestTask = nil
                    if audioDataSegments.isEmpty {
                        self.handlePremiumVoiceFailure(
                            message: "Premium voice failed: proxy returned no audio. Apple fallback used.",
                            text: text,
                            boundary: boundary,
                            appleVoice: appleVoice,
                            allowAppleFallback: allowAppleFallback
                        )
                        return
                    }
                    self.proxyAudioChunks = audioDataSegments
                    self.playNextProxyChunk(
                        token: token,
                        boundary: boundary,
                        appleVoice: appleVoice,
                        originalText: text,
                        allowAppleFallback: allowAppleFallback
                    )
                }
            } catch {
                await MainActor.run {
                    guard let self, !Task.isCancelled, self.playbackToken == token else { return }
                    self.proxyRequestTask = nil
                    self.handlePremiumVoiceFailure(
                        message: "Premium voice failed: \(Self.diagnosticDescription(for: error)). Apple fallback used.",
                        text: text,
                        boundary: boundary,
                        appleVoice: appleVoice,
                        allowAppleFallback: allowAppleFallback
                    )
                }
            }
        }
    }

    private func clearProxyFallbackContext() {
        currentProxyFallbackText = ""
        currentProxyFallbackBoundary = nil
        currentProxyFallbackAppleVoice = nil
        currentProxyAllowsAppleFallback = false
    }

    private func handlePremiumVoiceFailure(
        message: String,
        text: String,
        boundary: BoundaryType?,
        appleVoice: AVSpeechSynthesisVoice?,
        allowAppleFallback: Bool
    ) {
        if allowAppleFallback {
            ProxyDiagnostics.log("Speech", message)
            onDiagnosticNote?(message)
            clearProxyFallbackContext()
            speakWithApple(text: text, boundary: boundary, appleVoice: appleVoice)
            return
        }

        let noFallbackMessage = message.replacingOccurrences(of: "Apple fallback used.", with: "Apple fallback disabled.")
        ProxyDiagnostics.log("Speech", noFallbackMessage)
        onDiagnosticNote?(noFallbackMessage)
        clearProxyFallbackContext()
        onFinish?()
    }

    private func speakWithApple(text: String, boundary: BoundaryType?, appleVoice: AVSpeechSynthesisVoice?) {
        appleSpeechOutput.speak(text: text, boundary: boundary, voice: appleVoice)
    }

    private static func diagnosticDescription(for error: Error) -> String {
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty {
            return description
        }
        return String(describing: error)
    }

    private func playNextProxyChunk(
        token: UUID,
        boundary: BoundaryType?,
        appleVoice: AVSpeechSynthesisVoice?,
        originalText: String,
        allowAppleFallback: Bool
    ) {
        guard playbackToken == token else {
            return
        }

        guard let audioData = proxyAudioChunks.first else {
            clearProxyFallbackContext()
            onFinish?()
            return
        }

        proxyAudioChunks.removeFirst()
        do {
            let player = try AVAudioPlayer(data: audioData)
            proxyAudioPlayer = player
            player.delegate = self
            player.prepareToPlay()
            player.play()
        } catch {
            handlePremiumVoiceFailure(
                message: "Premium voice failed: audio playback error. Apple fallback used.",
                text: originalText,
                boundary: boundary,
                appleVoice: appleVoice,
                allowAppleFallback: allowAppleFallback
            )
            proxyAudioChunks.removeAll()
            clearProxyFallbackContext()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let token = self.playbackToken
            self.playNextProxyChunk(
                token: token,
                boundary: self.currentProxyFallbackBoundary,
                appleVoice: self.currentProxyFallbackAppleVoice,
                originalText: self.currentProxyFallbackText,
                allowAppleFallback: self.currentProxyAllowsAppleFallback
            )
        }
    }

}

@MainActor
class LocationManager: NSObject, ObservableObject, @MainActor CLLocationManagerDelegate {
    static let movingMapInteractionThresholdMetersPerSecond = 8.0 / 3.6

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let speechOutput: SpeechOutputEngine
    private var previousAddress: Address?
    private var lastUpdateTime: Date?
    private var lastBoundaryAnnouncementTime: Date?
    private var testIndex = 0
    private var announcementQueue = AnnouncementQueue()
    private var delayWorkItem: DispatchWorkItem?
    private var currentlySpeakingBoundary: BoundaryType?
    private var activeSpeechPlan: AnnouncementPlan?
    private var interruptedSpeechPlan: AnnouncementPlan?
    private var interruptionResumeWorkItem: DispatchWorkItem?
    private let factGenerator: PlaceFactGenerating
    private let aiSharingAllowed: () -> Bool
    private var inFlightFactTask: Task<Void, Never>?
    private var inFlightFactBoundary: BoundaryType?
    private var activeAnnouncementToken = UUID()
    private var wantsRideTracking = false
    private var hasSeededTestRoute = false
    private let externalAudioResumeDelaySeconds: TimeInterval = 3

    @Published var lastKnownLocation: CLLocationCoordinate2D?
    @Published var lastKnownAddress: Address?
    @Published var speakAfterEveryGeocode: Bool = false
    @Published var locationCheckInterval: Int = 10
    @Published var boundarySpeechCooldownSeconds: Int = UserDefaults.standard.object(
        forKey: LocationManagerDefaults.boundarySpeechCooldownSecondsKey
    ) as? Int ?? 10 {
        didSet {
            UserDefaults.standard.set(
                boundarySpeechCooldownSeconds,
                forKey: LocationManagerDefaults.boundarySpeechCooldownSecondsKey
            )
        }
    }
    @Published var announceStreet: Bool = false
    @Published var announceTown: Bool = true
    @Published var announceCounty: Bool = true
    @Published var announceNation: Bool = true
    @Published var announceCountry: Bool = true
    @Published var contentMode: ContentMode = .shortFacts
    @Published var bluetoothDelaySeconds: Double = 0.5
    @Published var testMode: Bool = {
        let key = LocationManagerDefaults.testModeKey
        if UserDefaults.standard.object(forKey: key) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: key)
    }() {
        didSet {
            UserDefaults.standard.set(testMode, forKey: LocationManagerDefaults.testModeKey)
            if testMode {
                startTestRouteIfNeeded()
            } else {
                hasSeededTestRoute = false
                testIndex = 0
            }
        }
    }
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
    @Published var premiumVoiceAppleFallbackEnabled: Bool = {
        guard UserDefaults.standard.object(forKey: LocationManagerDefaults.premiumVoiceAppleFallbackEnabledKey) != nil else {
            return true
        }
        return UserDefaults.standard.bool(forKey: LocationManagerDefaults.premiumVoiceAppleFallbackEnabledKey)
    }() {
        didSet {
            UserDefaults.standard.set(
                premiumVoiceAppleFallbackEnabled,
                forKey: LocationManagerDefaults.premiumVoiceAppleFallbackEnabledKey
            )
        }
    }
    @Published var preferredVoiceIdentifier: String = UserDefaults.standard.string(
        forKey: LocationManagerDefaults.preferredVoiceIdentifierKey
    ) ?? "" {
        didSet {
            UserDefaults.standard.set(preferredVoiceIdentifier, forKey: LocationManagerDefaults.preferredVoiceIdentifierKey)
        }
    }

    @Published var speechProvider: SpeechProvider = LocationManager.loadSpeechProvider() {
        didSet {
            UserDefaults.standard.set(speechProvider.rawValue, forKey: LocationManagerDefaults.speechProviderKey)
            UserDefaults.standard.set(true, forKey: LocationManagerDefaults.speechProviderMigrationKey)
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
    @Published private(set) var lastSpeechDiagnosticNote: String?
    @Published private(set) var locationStatus: LocationServiceStatus = .checking
    @Published private(set) var currentSpeedMetersPerSecond: CLLocationSpeed?

    var allowsMapInteraction: Bool {
        true
    }

    private var isSpeechOutputActive: Bool {
        speechOutput.isSpeaking
    }

    private var shouldYieldToPrimaryAudio: Bool {
        AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
    }

    var onAddressChange: ((Address) -> Void)?
    var onRideLog: ((CLLocationCoordinate2D, Address, String?) -> Void)?

    init(
        factGenerator: PlaceFactGenerating? = nil,
        speechOutput: SpeechOutputEngine? = nil,
        aiSharingAllowed: @escaping () -> Bool = { AISharingConsentStore.isGranted() }
    ) {
        self.factGenerator = factGenerator ?? Self.makeDefaultFactGenerator()
        self.speechOutput = speechOutput ?? DefaultSpeechOutputEngine()
        self.aiSharingAllowed = aiSharingAllowed
        super.init()
        self.speechOutput.onFinish = { [weak self] in
            self?.activeSpeechPlan = nil
            self?.currentlySpeakingBoundary = nil
        }
        self.speechOutput.onCancel = { [weak self] in
            self?.activeSpeechPlan = nil
            self?.currentlySpeakingBoundary = nil
        }
        self.speechOutput.onDiagnosticNote = { [weak self] note in
            self?.lastSpeechDiagnosticNote = note
        }
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
        startTestRouteIfNeeded()
        startRideTrackingIfAuthorized()
    }

    func pauseRideTracking() {
        wantsRideTracking = false
        locationManager.stopUpdatingLocation()
        isTracking = false
    }

    func applyAISharingDecision(isGranted: Bool) {
        inFlightFactTask?.cancel()
        inFlightFactTask = nil
        inFlightFactBoundary = nil
        activeAnnouncementToken = UUID()
        cancelPendingAnnouncement()
        stopSpeechOutput()

        if !isGranted {
            contentMode = .namesOnly
            speechProvider = .apple
        }
    }

    /// Cancels active work and removes privacy-sensitive state held by this manager.
    /// The caller remains responsible for clearing persisted defaults and Keychain records.
    func clearLocalPrivacyState() {
        applyAISharingDecision(isGranted: false)
        pauseRideTracking()
        geocoder.cancelGeocode()
        onAddressChange = nil
        onRideLog = nil

        lastKnownLocation = nil
        lastKnownAddress = nil
        currentSpeedMetersPerSecond = nil
        lastSpokenPhrase = nil
        lastSpokenAt = nil
        lastSpeechDiagnosticNote = nil
        locationStatus = .checking
        previousAddress = nil
        lastUpdateTime = nil
        lastBoundaryAnnouncementTime = nil
        interruptedSpeechPlan = nil

        homeCountry = ""
        homeRegion = ""
        familiarRegions = ""
        customFactInstructions = ""
        factInterestCategories = FactInterestCategory.defaultSelections
        contentMode = .shortFacts
        speechProvider = .proxyElevenLabs
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
            text: "\(ProductIdentity.displayName) can speak in this voice. Keep the road in front of you, rider.",
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

    private static func loadSpeechProvider() -> SpeechProvider {
        let migrationKey = LocationManagerDefaults.speechProviderMigrationKey
        let providerKey = LocationManagerDefaults.speechProviderKey
        let stored = UserDefaults.standard.string(forKey: providerKey)
        let provider = stored.flatMap(SpeechProvider.init(rawValue:)) ?? .proxyElevenLabs

        guard UserDefaults.standard.bool(forKey: migrationKey) else {
            UserDefaults.standard.set(SpeechProvider.proxyElevenLabs.rawValue, forKey: providerKey)
            UserDefaults.standard.set(true, forKey: migrationKey)
            return .proxyElevenLabs
        }

        return provider
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
            AppDiagnostics.log("No announcement required.")
            return
        }

        if shouldSuppressBoundarySpeech() {
            _ = supersedeUndeliveredAnnouncementWork(with: plan.boundary)
            if previousAddress != address {
                previousAddress = address
            }
            if testMode {
                recordTestLog(utteredPhrase: nil)
            }
            AppDiagnostics.log("Boundary announcement suppressed due cooldown.")
            return
        }

        guard supersedeUndeliveredAnnouncementWork(with: plan.boundary) else {
            previousAddress = address
            if testMode {
                recordTestLog(utteredPhrase: nil)
            }
            AppDiagnostics.log("Dropped lower-priority announcement while higher-priority work remains active.")
            return
        }
        previousAddress = address
        if !testMode {
            onAddressChange?(address)
        }

        if let factMode = contentMode.factMode, aiSharingAllowed(), plan.boundary != .street {
            lastBoundaryAnnouncementTime = Date()
            fetchFactAndEnqueue(plan: plan, address: address, mode: factMode)
        } else if contentMode != .quiet {
            lastBoundaryAnnouncementTime = Date()
            enqueueAnnouncement(plan)
        } else if testMode {
            recordTestLog(utteredPhrase: nil)
        }
    }

    private func shouldSuppressBoundarySpeech() -> Bool {
        guard boundarySpeechCooldownSeconds > 0 else { return false }
        guard let lastBoundaryAnnouncementTime else { return false }

        return Date().timeIntervalSince(lastBoundaryAnnouncementTime) < TimeInterval(boundarySpeechCooldownSeconds)
    }

    private func recordTestLog(utteredPhrase: String?) {
        guard testMode,
              let location = lastKnownLocation,
              let address = lastKnownAddress else { return }
        onRideLog?(location, address, utteredPhrase)
    }

    @discardableResult
    private func supersedeUndeliveredAnnouncementWork(with newBoundary: BoundaryType) -> Bool {
        let activeBoundaries = [
            inFlightFactBoundary,
            announcementQueue.pending?.boundary,
            isSpeechOutputActive ? activeSpeechPlan?.boundary : nil
        ].compactMap { $0 }

        if let highestPriorityBoundary = activeBoundaries.min(),
           newBoundary > highestPriorityBoundary {
            return false
        }

        guard !activeBoundaries.isEmpty else { return true }
        activeAnnouncementToken = UUID()
        inFlightFactTask?.cancel()
        inFlightFactTask = nil
        inFlightFactBoundary = nil
        cancelPendingAnnouncement()
        speechOutput.cancelPendingPreparation()
        return true
    }

    private func fetchFactAndEnqueue(plan: AnnouncementPlan, address: Address, mode: FactMode) {
        let token = UUID()
        activeAnnouncementToken = token
        inFlightFactTask?.cancel()
        inFlightFactBoundary = plan.boundary
        cancelPendingAnnouncement()

        let request = AnnouncementPolicy.factRequest(
            for: plan,
            address: address,
            mode: mode,
            riderContext: riderContext
        )
        let generator = factGenerator
        let aiSharingAllowed = aiSharingAllowed

        inFlightFactTask = Task { [weak self] in
            let fact = await PlaceFactFetcher.fact(for: request, using: generator)
            await MainActor.run {
                guard let self, !Task.isCancelled, self.activeAnnouncementToken == token else { return }
                self.inFlightFactTask = nil
                self.inFlightFactBoundary = nil
                guard aiSharingAllowed() else {
                    self.enqueueAnnouncement(plan)
                    return
                }
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

        guard supersedeUndeliveredAnnouncementWork(with: .town) else { return }
        previousAddress = address
        lastBoundaryAnnouncementTime = Date()
        let plan = AnnouncementPlan(text: speechText, boundary: .town)
        enqueueAnnouncement(plan)
    }

    private func enqueueAnnouncement(_ plan: AnnouncementPlan) {
        if isSpeechOutputActive, let speakingBoundary = currentlySpeakingBoundary {
            if AnnouncementQueue.shouldDropWhileSpeaking(
                newBoundary: plan.boundary,
                currentlySpeaking: speakingBoundary
            ) {
                AppDiagnostics.log("Dropped lower-priority announcement.")
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
        AppDiagnostics.log("Queued announcement after configured Bluetooth delay.")
    }

    private func cancelPendingAnnouncement() {
        delayWorkItem?.cancel()
        delayWorkItem = nil
        announcementQueue.clearPending()
    }

    private func deliverAnnouncement(id: UUID) {
        guard let pending = announcementQueue.pending, pending.id == id else {
            AppDiagnostics.log("Skipped stale announcement.")
            return
        }

        if isSpeechOutputActive, let speakingBoundary = currentlySpeakingBoundary {
            if AnnouncementQueue.shouldDropWhileSpeaking(
                newBoundary: pending.boundary,
                currentlySpeaking: speakingBoundary
            ) {
                announcementQueue.clearPending(id: id)
                AppDiagnostics.log("Dropped stale lower-priority announcement at delivery.")
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

            AppDiagnostics.log("Location updated.")
            reverseGeocode(location: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationStatus = .locationUnavailable("Location update failed. \(ProductIdentity.displayName) will keep trying.")
        AppDiagnostics.log("Location update failed.")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startRideTrackingIfAuthorized()
    }

    private func reverseGeocode(location: CLLocation, completion: (@MainActor () -> Void)? = nil) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if error != nil {
                Task { @MainActor [weak self] in
                    self?.locationStatus = .placeUnavailable("Place lookup failed. GPS is still active.")
                }
                AppDiagnostics.log("Reverse geocoding failed.")
                return
            }

            guard let placemark = placemarks?.first else {
                Task { @MainActor [weak self] in
                    self?.locationStatus = .placeUnavailable("Place name is unavailable here.")
                }
                AppDiagnostics.log("No placemark was returned.")
                return
            }

            let address = Address(placemark: placemark)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lastKnownAddress = address
                AppDiagnostics.log("Resolved a place name.")

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
            AppDiagnostics.log("Audio session activated for background playback.")
        } catch {
            AppDiagnostics.log("Audio session setup failed.")
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
            AppDiagnostics.log("RideHorizon speech stopped for primary audio.")
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
        AppDiagnostics.log("RideHorizon will resume after the primary-audio delay.")
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
            AppDiagnostics.log("Primary audio is active; RideHorizon speech deferred.")
            return
        }
        currentlySpeakingBoundary = boundary
        activeSpeechPlan = AnnouncementPlan(text: text, boundary: boundary ?? .street)
        AppDiagnostics.log("Speaking an announcement.")
        lastSpokenPhrase = text
        lastSpokenAt = Date()
        lastSpeechDiagnosticNote = nil
        if shouldRecordTestLog {
            recordTestLog(utteredPhrase: text)
        }

        speechOutput.speak(
            text: text,
            boundary: boundary,
            provider: aiSharingAllowed() ? speechProvider : .apple,
            appleVoice: resolveSpeechVoice(),
            allowAppleFallback: aiSharingAllowed() ? premiumVoiceAppleFallbackEnabled : false
        )
    }

    private func stopSpeechOutput() {
        speechOutput.stop()
        activeSpeechPlan = nil
        currentlySpeakingBoundary = nil
    }

#if DEBUG
    func speakForTesting(text: String, boundary: BoundaryType) {
        speak(text: text, boundary: boundary, shouldRecordTestLog: false, ignoreQuietMode: true)
    }

    func processResolvedAddressForTesting(_ address: Address) {
        processResolvedAddress(address)
    }
#endif

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

    func logTestLocation() {
        let waypoint = TestRouteFixture.waypoint(at: testIndex)
        testIndex = (testIndex + 1) % TestRouteFixture.waypoints.count

        lastKnownLocation = waypoint.coordinate
        currentSpeedMetersPerSecond = 0
        locationStatus = .active
        AppDiagnostics.log("Test location advanced.")

        geocoder.reverseGeocodeLocation(CLLocation(latitude: waypoint.latitude, longitude: waypoint.longitude)) { [weak self] placemarks, error in
            if error != nil {
                Task { @MainActor [weak self] in
                    self?.locationStatus = .placeUnavailable("Test place lookup failed.")
                }
                AppDiagnostics.log("Test location reverse geocoding failed.")
                return
            }

            guard let placemark = placemarks?.first else {
                Task { @MainActor [weak self] in
                    self?.locationStatus = .placeUnavailable("Test place name is unavailable.")
                }
                AppDiagnostics.log("No test placemark was returned.")
                return
            }

            let address = Address(placemark: placemark)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lastKnownAddress = address
                AppDiagnostics.log("Resolved a test place name.")

                self.processResolvedAddress(address)
            }
        }
    }

    private func startTestRouteIfNeeded() {
        guard testMode, !hasSeededTestRoute else { return }
        hasSeededTestRoute = true
        testIndex = 0
        logTestLocation()
    }
}
