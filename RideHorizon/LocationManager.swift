import Foundation
import CoreLocation
import AVFoundation

enum LocationServiceStatus: Equatable {
    case idle
    case checking
    case waitingForPermission
    case denied
    case restricted
    case active
    case locationUnavailable(String)
    case placeUnavailable(String)

    var riderMessage: String {
        switch self {
        case .idle:
            return "Ready to start a ride."
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
        case .idle, .checking, .waitingForPermission, .active, .locationUnavailable, .placeUnavailable:
            return false
        }
    }
}

enum AnnouncementPipelineStatus: Equatable {
    case idle
    case retrievingContent
    case phraseReady
    case waitingForAudio
    case preparingVoice
    case speaking

    var riderLabel: String {
        switch self {
        case .idle:
            return "Ready"
        case .retrievingContent:
            return "Finding fact"
        case .phraseReady:
            return "Phrase ready"
        case .waitingForAudio:
            return "Waiting for audio"
        case .preparingVoice:
            return "Creating voice"
        case .speaking:
            return "Speaking"
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            return "checkmark.circle"
        case .retrievingContent:
            return "sparkles"
        case .phraseReady:
            return "text.bubble"
        case .waitingForAudio:
            return "pause.circle"
        case .preparingVoice:
            return "waveform"
        case .speaking:
            return "speaker.wave.2.fill"
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
    static let audioInteropDebugTestModeChoiceKey = "RideHorizonAudioInteropDebugTestModeChoice"
#if DEBUG
    static let shortInactivityTimeoutKey = "RideHorizonShortInactivityTimeout"
#endif
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

enum AudioCoexistencePolicy: String, Codable, Equatable {
    case mix
    case duck
    case interrupt
}

@MainActor
protocol AudioSessionManaging: AnyObject {
    var shouldYieldToPrimaryAudio: Bool { get }
    var snapshot: AudioSessionSnapshot { get }
    func activate(policy: AudioCoexistencePolicy) throws
    func deactivate() throws
    func neutralizeAfterDeactivationFailure() -> Bool
}

@MainActor
final class SystemAudioSessionManager: AudioSessionManaging {
    private let session: AVAudioSession

    init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    var shouldYieldToPrimaryAudio: Bool {
        session.secondaryAudioShouldBeSilencedHint
    }

    var snapshot: AudioSessionSnapshot {
        let categoryOptions = session.categoryOptions
        var optionNames: [String] = []
        if categoryOptions.contains(.mixWithOthers) { optionNames.append("mixWithOthers") }
        if categoryOptions.contains(.duckOthers) { optionNames.append("duckOthers") }
        if categoryOptions.contains(.interruptSpokenAudioAndMixWithOthers) {
            optionNames.append("interruptSpokenAudioAndMixWithOthers")
        }
        if categoryOptions.contains(.allowBluetoothA2DP) { optionNames.append("allowBluetoothA2DP") }
        if categoryOptions.contains(.allowAirPlay) { optionNames.append("allowAirPlay") }
        return AudioSessionSnapshot(
            outputVolume: session.outputVolume,
            outputRouteTypes: session.currentRoute.outputs.map { $0.portType.rawValue },
            isOtherAudioPlaying: session.isOtherAudioPlaying,
            shouldYieldToPrimaryAudio: session.secondaryAudioShouldBeSilencedHint,
            category: session.category.rawValue,
            mode: session.mode.rawValue,
            options: optionNames
        )
    }

    func activate(policy: AudioCoexistencePolicy) throws {
        let options: AVAudioSession.CategoryOptions
        switch policy {
        case .mix:
            options = [.mixWithOthers]
        case .duck:
            options = [.duckOthers]
        case .interrupt:
            options = []
        }
        try session.setCategory(.playback, mode: .spokenAudio, options: options)
        try session.setActive(true)
    }

    func deactivate() throws {
        try session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func neutralizeAfterDeactivationFailure() -> Bool {
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            return true
        } catch {
            return false
        }
    }
}

@MainActor
protocol SpeechOutputEngine: AnyObject {
    var isSpeaking: Bool { get }
    var isPlayingAudio: Bool { get }
    var onPlaybackWillStart: ((SpeechProvider) -> Bool)? { get set }
    var onFinish: (() -> Void)? { get set }
    var onCancel: (() -> Void)? { get set }
    var onDiagnosticNote: ((String) -> Void)? { get set }
    var onPipelineEvent: ((SpeechOutputPipelineEvent) -> Void)? { get set }

    func speak(
        text: String,
        boundary: BoundaryType?,
        provider: SpeechProvider,
        appleVoice: AVSpeechSynthesisVoice?,
        allowAppleFallback: Bool,
        announcementID: UUID
    )
    func cancelPendingPreparation()
    func stop()
}

enum SpeechOutputPipelineStage: Equatable {
    case ttsRequested
    case speechAudioReady
}

struct SpeechOutputPipelineEvent: Equatable {
    let announcementID: UUID
    let provider: SpeechProvider
    let stage: SpeechOutputPipelineStage
}

@MainActor
protocol AppleSpeechOutputting: AnyObject {
    var isSpeaking: Bool { get }
    var onPlaybackWillStart: ((UUID) -> Bool)? { get set }
    var onFinish: ((UUID) -> Void)? { get set }
    var onCancel: ((UUID) -> Void)? { get set }

    func speak(text: String, boundary: BoundaryType?, voice: AVSpeechSynthesisVoice?, requestID: UUID)
    func stop()
}

@MainActor
final class AppleSpeechOutput: NSObject, AppleSpeechOutputting, AVSpeechSynthesizerDelegate {
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var activeUtterance: (id: ObjectIdentifier, requestID: UUID)?

    var onPlaybackWillStart: ((UUID) -> Bool)?
    var onFinish: ((UUID) -> Void)?
    var onCancel: ((UUID) -> Void)?
    var onDiagnosticNote: ((String) -> Void)?

    var isSpeaking: Bool {
        speechSynthesizer.isSpeaking
    }

    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    func speak(text: String, boundary: BoundaryType?, voice: AVSpeechSynthesisVoice?, requestID: UUID) {
        guard let voice else {
            ProxyDiagnostics.log("Speech", "No usable Apple voice.")
            onFinish?(requestID)
            return
        }

        ProxyDiagnostics.log("Speech", "Routing \(boundary?.factLabel ?? "unknown") speech through Apple voice \(voice.identifier).")
        let utterance = AVSpeechUtterance(string: text)
        activeUtterance = (ObjectIdentifier(utterance), requestID)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1
        guard onPlaybackWillStart?(requestID) != false else {
            activeUtterance = nil
            onCancel?(requestID)
            return
        }
        speechSynthesizer.speak(utterance)
    }

    func stop() {
        activeUtterance = nil
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, let active = self.activeUtterance,
                  active.id == ObjectIdentifier(utterance) else { return }
            self.activeUtterance = nil
            self.onFinish?(active.requestID)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, let active = self.activeUtterance,
                  active.id == ObjectIdentifier(utterance) else { return }
            self.activeUtterance = nil
            self.onCancel?(active.requestID)
        }
    }
}

@MainActor
protocol PremiumAudioPlaying: AnyObject {
    var isPlaying: Bool { get }
    func play(
        buffer: AVAudioPCMBuffer,
        completion: @escaping @MainActor (Result<Void, Error>) -> Void
    ) throws
    func stop()
}

@MainActor
final class NormalisedPremiumAudioPlayer: PremiumAudioPlaying {

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var activeBuffer: AVAudioPCMBuffer?
    private var configurationObserver: NSObjectProtocol?
    private var playbackID = UUID()

    var isPlaying: Bool {
        playerNode?.isPlaying == true
    }

    func play(
        buffer: AVAudioPCMBuffer,
        completion: @escaping @MainActor (Result<Void, Error>) -> Void
    ) throws {
        stop()
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        let playbackID = UUID()
        self.playbackID = playbackID
        self.engine = engine
        self.playerNode = playerNode
        activeBuffer = buffer

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: buffer.format)
        playerNode.scheduleBuffer(
            buffer,
            at: nil,
            options: [],
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.playbackID == playbackID else { return }
                self.finishPlayback()
                completion(.success(()))
            }
        }
        engine.prepare()
        try engine.start()
        playerNode.play()
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.playbackID == playbackID else { return }
                self.finishPlayback()
                completion(.failure(PremiumAudioPlaybackError.engineConfigurationChanged))
            }
        }
    }

    func stop() {
        playbackID = UUID()
        removeConfigurationObserver()
        playerNode?.stop()
        engine?.stop()
        playerNode = nil
        engine = nil
        activeBuffer = nil
    }

    private func finishPlayback() {
        playbackID = UUID()
        removeConfigurationObserver()
        engine?.stop()
        playerNode = nil
        engine = nil
        activeBuffer = nil
    }

    private func removeConfigurationObserver() {
        guard let configurationObserver else { return }
        NotificationCenter.default.removeObserver(configurationObserver)
        self.configurationObserver = nil
    }
}

@MainActor
final class DefaultSpeechOutputEngine: NSObject, SpeechOutputEngine {
    private let proxySpeechGenerator: ProxySpeechGenerating
    private let appleSpeechOutput: AppleSpeechOutputting
    private let proxyAudioPlayer: PremiumAudioPlaying
    private var proxyAudioChunks: [AVAudioPCMBuffer] = []
    private var proxyRequestTask: Task<Void, Never>?
    private var playbackToken = UUID()
    private var currentProxyFallbackText = ""
    private var currentProxyFallbackBoundary: BoundaryType?
    private var currentProxyFallbackAppleVoice: AVSpeechSynthesisVoice?
    private var currentProxyAllowsAppleFallback = false
    private var currentAnnouncementID: UUID?
    private var hasStartedCurrentPlayback = false

    var onPlaybackWillStart: ((SpeechProvider) -> Bool)?
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDiagnosticNote: ((String) -> Void)?
    var onPipelineEvent: ((SpeechOutputPipelineEvent) -> Void)?

    var isSpeaking: Bool {
        proxyRequestTask != nil
            || appleSpeechOutput.isSpeaking
            || proxyAudioPlayer.isPlaying
            || !proxyAudioChunks.isEmpty
    }

    var isPlayingAudio: Bool {
        appleSpeechOutput.isSpeaking || proxyAudioPlayer.isPlaying
    }

    init(
        proxySpeechGenerator: ProxySpeechGenerating = ProxySpeechGenerator(),
        appleSpeechOutput: AppleSpeechOutputting? = nil,
        proxyAudioPlayer: PremiumAudioPlaying? = nil
    ) {
        self.proxySpeechGenerator = proxySpeechGenerator
        self.appleSpeechOutput = appleSpeechOutput ?? AppleSpeechOutput()
        self.proxyAudioPlayer = proxyAudioPlayer ?? NormalisedPremiumAudioPlayer()
        super.init()
        self.appleSpeechOutput.onPlaybackWillStart = { [weak self] requestID in
            guard let self,
                  self.playbackToken == requestID,
                  let announcementID = self.currentAnnouncementID else { return false }
            self.onPipelineEvent?(SpeechOutputPipelineEvent(
                announcementID: announcementID,
                provider: .apple,
                stage: .speechAudioReady
            ))
            return self.prepareForPlayback(provider: .apple)
        }
        self.appleSpeechOutput.onFinish = { [weak self] requestID in
            guard let self, self.playbackToken == requestID else { return }
            self.onFinish?()
        }
        self.appleSpeechOutput.onCancel = { [weak self] requestID in
            guard let self, self.playbackToken == requestID else { return }
            self.onCancel?()
        }
    }

    func speak(
        text: String,
        boundary: BoundaryType?,
        provider: SpeechProvider,
        appleVoice: AVSpeechSynthesisVoice?,
        allowAppleFallback: Bool,
        announcementID: UUID = UUID()
    ) {
        currentAnnouncementID = announcementID
        hasStartedCurrentPlayback = false
        switch provider {
        case .proxyElevenLabs:
            speakWithProxy(text: text, boundary: boundary, appleVoice: appleVoice, allowAppleFallback: allowAppleFallback)
        case .apple:
            speakWithApple(text: text, boundary: boundary, appleVoice: appleVoice)
        }
    }

    func stop() {
        let wasActive = isSpeaking
        playbackToken = UUID()
        proxyRequestTask?.cancel()
        proxyRequestTask = nil
        appleSpeechOutput.stop()
        proxyAudioPlayer.stop()
        proxyAudioChunks.removeAll()
        hasStartedCurrentPlayback = false
        clearProxyFallbackContext()
        if wasActive {
            onCancel?()
        }
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
        if let announcementID = currentAnnouncementID {
            onPipelineEvent?(SpeechOutputPipelineEvent(
                announcementID: announcementID,
                provider: .proxyElevenLabs,
                stage: .ttsRequested
            ))
        }
        proxyRequestTask?.cancel()
        proxyAudioPlayer.stop()
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
                guard !audioDataSegments.isEmpty else {
                    throw PremiumAudioPlaybackError.emptyAudio
                }
                let preparedAudio = try await PremiumAudioPreparer.prepare(
                    dataSegments: audioDataSegments
                )
                await MainActor.run {
                    guard let self, !Task.isCancelled, self.playbackToken == token else { return }
                    self.proxyRequestTask = nil
                    if let announcementID = self.currentAnnouncementID {
                        self.onPipelineEvent?(SpeechOutputPipelineEvent(
                            announcementID: announcementID,
                            provider: .proxyElevenLabs,
                            stage: .speechAudioReady
                        ))
                    }
                    self.proxyAudioChunks = preparedAudio.buffers
                    ProxyDiagnostics.log(
                        "Speech",
                        String(
                            format: "Premium Voice local utterance peak-normalisation gainDb=%.2f.",
                            preparedAudio.gainDecibels
                        )
                    )
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
        if let announcementID = currentAnnouncementID {
            onPipelineEvent?(SpeechOutputPipelineEvent(
                announcementID: announcementID,
                provider: .apple,
                stage: .ttsRequested
            ))
        }
        let requestID = UUID()
        playbackToken = requestID
        appleSpeechOutput.speak(text: text, boundary: boundary, voice: appleVoice, requestID: requestID)
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

        guard let audioBuffer = proxyAudioChunks.first else {
            clearProxyFallbackContext()
            onFinish?()
            return
        }

        proxyAudioChunks.removeFirst()
        do {
            guard prepareForPlayback(provider: .proxyElevenLabs) else {
                proxyAudioPlayer.stop()
                proxyAudioChunks.removeAll()
                clearProxyFallbackContext()
                onCancel?()
                return
            }
            try proxyAudioPlayer.play(buffer: audioBuffer) { [weak self] result in
                switch result {
                case .success:
                    self?.handleProxyChunkFinished(token: token)
                case .failure:
                    guard let self, self.playbackToken == token else { return }
                    self.handleActiveProxyPlaybackFailure(
                        message: "Premium voice failed: audio output changed during playback. Apple fallback used."
                    )
                }
            }
        } catch {
            proxyAudioPlayer.stop()
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

    private func prepareForPlayback(provider: SpeechProvider) -> Bool {
        guard !hasStartedCurrentPlayback else { return true }
        guard onPlaybackWillStart?(provider) != false else { return false }
        hasStartedCurrentPlayback = true
        return true
    }

    private func handleProxyChunkFinished(token: UUID) {
        guard playbackToken == token else { return }
        playNextProxyChunk(
            token: token,
            boundary: currentProxyFallbackBoundary,
            appleVoice: currentProxyFallbackAppleVoice,
            originalText: currentProxyFallbackText,
            allowAppleFallback: currentProxyAllowsAppleFallback
        )
    }

    private func handleActiveProxyPlaybackFailure(message: String) {
        proxyAudioPlayer.stop()
        proxyAudioChunks.removeAll()
        let text = currentProxyFallbackText
        let boundary = currentProxyFallbackBoundary
        let appleVoice = currentProxyFallbackAppleVoice
        let allowAppleFallback = currentProxyAllowsAppleFallback
        guard !text.isEmpty else {
            clearProxyFallbackContext()
            onFinish?()
            return
        }
        handlePremiumVoiceFailure(
            message: message,
            text: text,
            boundary: boundary,
            appleVoice: appleVoice,
            allowAppleFallback: allowAppleFallback
        )
    }

}

private enum ObservedAudioPauseSource: Hashable {
    case interruption
    case primaryAudio
}

@MainActor
class LocationManager: NSObject, ObservableObject, @MainActor CLLocationManagerDelegate {
    static let movingMapInteractionThresholdMetersPerSecond = 8.0 / 3.6

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let speechOutput: SpeechOutputEngine
    private let audioSession: AudioSessionManaging
    private let diagnostics: RideDiagnosticsStore
    private var ownsAudioSession = false
    private var previousAddress: Address?
    private var lastUpdateTime: Date?
    private var lastLocationDiagnosticTime: Date?
    private var lastBoundaryAnnouncementTime: Date?
    private var testIndex = 0
    private var announcementQueue = AnnouncementQueue()
    private var delayWorkItem: DispatchWorkItem?
    private var currentlySpeakingBoundary: BoundaryType?
    private var activeSpeechPlan: AnnouncementPlan?
    private var interruptedSpeechPlan: AnnouncementPlan?
    private var observedAudioPauseSources: Set<ObservedAudioPauseSource> = []
    private let factGenerator: PlaceFactGenerating
    private let aiSharingAllowed: () -> Bool
    private let inactivityNotifier: RideInactivityNotifying
    private var inFlightFactTask: Task<Void, Never>?
    private var inFlightFactBoundary: BoundaryType?
    private var inFlightFactAnnouncementID: UUID?
    private var activeAnnouncementToken = UUID()
    private var wantsRideTracking = false
    private var hasSeededTestRoute = false
    private var rideSessionLifecycle = RideSessionLifecycle()
    private var inactivityTimer: DispatchSourceTimer?
    private var rideStartedAt: Date?
    private var rideSessionGeneration = UUID()
    private var geocodeRequestGeneration = UUID()
    private var activePlaceLookupID: UUID?
    private var hasAppliedDebugTestModeCampaignDefaults = false
    private var audioSessionReleaseRetryWorkItem: DispatchWorkItem?
    private var audioSessionReleaseRetryAttempts = 0
    private var activeRideSessionID: UUID?
    private var diagnosticAppState: DiagnosticAppState = .foreground
#if INTERNAL_AUDIO_CALIBRATION
    private let calibrationProcessor: PremiumSpeechProcessing = DefaultPremiumSpeechProcessor()
    private let calibrationPremiumAudioPlayer: PremiumAudioPlaying = NormalisedPremiumAudioPlayer()
    private let calibrationAppleSpeechOutput: AppleSpeechOutputting = AppleSpeechOutput()
    private var calibrationPreparationTask: Task<Void, Never>?
    private var calibrationPlaybackToken = UUID()
    private var calibrationPremiumCompletion: ((Result<PreparedPremiumAudio, Error>) -> Void)?
    private var calibrationAppleCompletion: ((Result<Void, Error>) -> Void)?
    private var calibrationPlaybackStarted: (() -> Void)?
    private var calibrationDiagnosticContext: SpeechCalibrationDiagnosticSnapshot?
    private var calibrationAppleSessionActivationFailed = false
#endif

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
#if DEBUG
    @Published var shortInactivityTimeout: Bool = UserDefaults.standard.bool(
        forKey: LocationManagerDefaults.shortInactivityTimeoutKey
    ) {
        didSet {
            UserDefaults.standard.set(
                shortInactivityTimeout,
                forKey: LocationManagerDefaults.shortInactivityTimeoutKey
            )
        }
    }
#endif
    @Published var testMode: Bool = LocationManager.loadTestMode() {
        didSet {
            UserDefaults.standard.set(testMode, forKey: LocationManagerDefaults.testModeKey)
#if DEBUG
            UserDefaults.standard.set(
                true,
                forKey: LocationManagerDefaults.audioInteropDebugTestModeChoiceKey
            )
#endif
            if testMode {
                applyDebugTestModeCampaignDefaults()
                locationManager.stopUpdatingLocation()
                locationManager.allowsBackgroundLocationUpdates = false
                isTracking = false
                if rideSessionState.isActive {
                    startTestRouteIfNeeded()
                }
            } else {
                hasSeededTestRoute = false
                testIndex = 0
                if rideSessionState.isActive {
                    startRideTrackingIfAuthorized()
                }
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
    @Published private(set) var rideSessionState: RideSessionState = .idle
    @Published private(set) var lastSpokenPhrase: String?
    @Published private(set) var lastSpokenAt: Date?
    @Published private(set) var lastSpeechDiagnosticNote: String?
    @Published private(set) var locationStatus: LocationServiceStatus = .idle
    @Published private(set) var currentSpeedMetersPerSecond: CLLocationSpeed?
    @Published private(set) var announcementStatus: AnnouncementPipelineStatus = .idle

    var allowsMapInteraction: Bool {
        true
    }

    private var isSpeechOutputActive: Bool {
        speechOutput.isSpeaking
    }

    private var audioCoexistencePolicy: AudioCoexistencePolicy {
        interruptsMusic ? .interrupt : .mix
    }

    var onAddressChange: ((Address) -> Void)?
    var onRideLog: ((CLLocationCoordinate2D, Address, String?) -> Void)?

    init(
        factGenerator: PlaceFactGenerating? = nil,
        speechOutput: SpeechOutputEngine? = nil,
        inactivityNotifier: RideInactivityNotifying? = nil,
        audioSession: AudioSessionManaging? = nil,
        diagnostics: RideDiagnosticsStore? = nil,
        aiSharingAllowed: @escaping () -> Bool = { AISharingConsentStore.isGranted() }
    ) {
        self.factGenerator = factGenerator ?? Self.makeDefaultFactGenerator()
        self.speechOutput = speechOutput ?? DefaultSpeechOutputEngine()
        self.inactivityNotifier = inactivityNotifier ?? UserNotificationRideInactivityNotifier()
        self.audioSession = audioSession ?? SystemAudioSessionManager()
        self.diagnostics = diagnostics ?? .shared
        self.aiSharingAllowed = aiSharingAllowed
        super.init()
        if testMode {
            applyDebugTestModeCampaignDefaults()
        }
        self.speechOutput.onPlaybackWillStart = { [weak self] provider in
            guard let self else { return false }
            return self.acquireAudioSessionForSpeech(
                provider: provider,
                announcementID: self.activeSpeechPlan?.id
            )
        }
        self.speechOutput.onFinish = { [weak self] in
            let announcementID = self?.activeSpeechPlan?.id
            self?.activeSpeechPlan = nil
            self?.currentlySpeakingBoundary = nil
            self?.announcementStatus = .idle
            self?.recordDiagnostic(
                .audioPlaybackFinished,
                announcementID: announcementID,
                reason: .playbackCompleted
            )
            self?.releaseAudioSessionAfterSpeech(announcementID: announcementID)
        }
        self.speechOutput.onCancel = { [weak self] in
            let announcementID = self?.activeSpeechPlan?.id
            self?.activeSpeechPlan = nil
            self?.currentlySpeakingBoundary = nil
            self?.announcementStatus = .idle
            self?.recordDiagnostic(
                .audioPlaybackCancelled,
                announcementID: announcementID,
                reason: .playbackCancelled
            )
            self?.releaseAudioSessionAfterSpeech(announcementID: announcementID)
        }
        self.speechOutput.onDiagnosticNote = { [weak self] note in
            self?.lastSpeechDiagnosticNote = note
            self?.announcementStatus = .idle
            self?.recordDiagnostic(
                .announcementFailed,
                announcementID: self?.activeSpeechPlan?.id,
                reason: .playbackFailed,
                playbackPath: .premiumVoice
            )
        }
        self.speechOutput.onPipelineEvent = { [weak self] event in
            let diagnosticEvent: RideDiagnosticEvent = switch event.stage {
            case .ttsRequested: .ttsRequested
            case .speechAudioReady: .speechAudioReady
            }
            self?.recordDiagnostic(
                diagnosticEvent,
                announcementID: event.announcementID,
                playbackPath: event.provider == .apple ? .apple : .premiumVoice
            )
        }
#if INTERNAL_AUDIO_CALIBRATION
        self.calibrationAppleSpeechOutput.onPlaybackWillStart = { [weak self] requestID in
            guard let self, requestID == self.calibrationPlaybackToken else { return false }
            let acquired = self.acquireAudioSessionForSpeech(provider: .apple, announcementID: nil)
            self.calibrationAppleSessionActivationFailed = !acquired
            if acquired { self.calibrationPlaybackStarted?() }
            return acquired
        }
        self.calibrationAppleSpeechOutput.onFinish = { [weak self] requestID in
            guard let self, requestID == self.calibrationPlaybackToken else { return }
            self.finishCalibrationApple(with: .success(()))
        }
        self.calibrationAppleSpeechOutput.onCancel = { [weak self] requestID in
            guard let self, requestID == self.calibrationPlaybackToken else { return }
            let outcome: SpeechCalibrationDiagnosticOutcome = self.calibrationAppleSessionActivationFailed
                ? .sessionFailed
                : .cancelled
            self.finishCalibrationApple(
                with: .failure(
                    self.calibrationAppleSessionActivationFailed
                        ? SpeechCalibrationError.playbackFailed
                        : SpeechCalibrationError.cancelled
                ),
                failureOutcome: outcome
            )
        }
#endif
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.pausesLocationUpdatesAutomatically = false

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance()
        )

        ensurePreferredVoiceSelection()
    }

    private func applyDebugTestModeCampaignDefaults() {
#if DEBUG
        guard !hasAppliedDebugTestModeCampaignDefaults else { return }
        hasAppliedDebugTestModeCampaignDefaults = true
        contentMode = .namesOnly
        announceStreet = true
#endif
    }

    private static func makeDefaultFactGenerator() -> PlaceFactGenerating {
        CachedPlaceFactGenerator(generator: ProxyFactGenerator())
    }

    private static func loadTestMode() -> Bool {
#if DEBUG
        if !UserDefaults.standard.bool(
            forKey: LocationManagerDefaults.audioInteropDebugTestModeChoiceKey
        ) {
            return true
        }
#endif
        let key = LocationManagerDefaults.testModeKey
        guard UserDefaults.standard.object(forKey: key) != nil else { return false }
        return UserDefaults.standard.bool(forKey: key)
    }

    func requestLocation() {
        locationManager.requestLocation()
    }

    /// Starts a rider-controlled session. Continuous and background work must remain inside this boundary.
    func startRide(at date: Date = Date()) {
        startRide(at: date, startsLocationInput: true)
    }

    private func startRide(at date: Date, startsLocationInput: Bool) {
        guard rideSessionState == .idle else { return }
#if DEBUG
        rideSessionLifecycle = shortInactivityTimeout
            ? RideSessionLifecycle(inactivityInterval: 30, confirmationGracePeriod: 30)
            : RideSessionLifecycle()
#else
        rideSessionLifecycle = RideSessionLifecycle()
#endif
        rideSessionGeneration = UUID()
        activeRideSessionID = UUID()
        rideSessionLifecycle.start(at: date)
        rideStartedAt = date
        rideSessionState = rideSessionLifecycle.state
        wantsRideTracking = true
        locationStatus = .checking
        inactivityNotifier.requestAuthorizationIfNeeded()
        startInactivityTimer()
        if startsLocationInput {
            startTestRouteIfNeeded()
            startRideTrackingIfAuthorized()
        }
        recordDiagnostic(.rideStarted, at: date)
    }

    func endRide() {
        finishRideSession()
    }

    func recordAppLifecycle(isForeground: Bool) {
        diagnosticAppState = isForeground ? .foreground : .background
        recordDiagnostic(isForeground ? .appEnteredForeground : .appEnteredBackground)
    }

    func continueRide(at date: Date = Date()) {
        guard case .awaitingConfirmation = rideSessionState else { return }
        guard rideSessionLifecycle.continueRide(at: date) else {
            finishRideSession()
            return
        }
        rideSessionState = rideSessionLifecycle.state
        inactivityNotifier.cancelInactivityPrompt()
        recordDiagnostic(.rideContinued, at: date)
        AppDiagnostics.log("Ride continued after inactivity prompt.")
    }

    func pauseRideTracking() {
        finishRideSession()
    }

    private func finishRideSession() {
        let wasActive = wantsRideTracking || rideSessionState.isActive
        rideSessionGeneration = UUID()
        rideSessionLifecycle.end()
        rideSessionState = rideSessionLifecycle.state
        wantsRideTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        isTracking = false
        locationStatus = .idle
        announcementStatus = .idle
        currentSpeedMetersPerSecond = nil
        lastUpdateTime = nil
        lastLocationDiagnosticTime = nil
        inactivityTimer?.cancel()
        inactivityTimer = nil
        inactivityNotifier.cancelInactivityPrompt()

        if let announcementID = inFlightFactAnnouncementID {
            recordDiagnostic(
                .announcementCancelled,
                announcementID: announcementID,
                reason: .rideEnded
            )
        }
        if let announcementID = interruptedSpeechPlan?.id {
            recordDiagnostic(
                .announcementCancelled,
                announcementID: announcementID,
                reason: .rideEnded
            )
        }
        inFlightFactTask?.cancel()
        inFlightFactTask = nil
        inFlightFactBoundary = nil
        inFlightFactAnnouncementID = nil
        activeAnnouncementToken = UUID()
        observedAudioPauseSources.removeAll()
        interruptedSpeechPlan = nil
        cancelPendingAnnouncement(reason: .rideEnded)
        stopSpeechOutput()
        cancelActivePlaceLookup(reason: .rideEnded)
        geocoder.cancelGeocode()
        hasSeededTestRoute = false
        testIndex = 0
        AppDiagnostics.log("Ride session ended and background work stopped.")
        if wasActive {
            recordDiagnostic(.rideEnded)
        }
        activeRideSessionID = nil
        rideStartedAt = nil
    }

    func applyAISharingDecision(isGranted: Bool) {
        inFlightFactTask?.cancel()
        inFlightFactTask = nil
        inFlightFactBoundary = nil
        inFlightFactAnnouncementID = nil
        activeAnnouncementToken = UUID()
        cancelPendingAnnouncement(reason: .settingsChanged)
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
        announcementStatus = .idle
        locationStatus = .idle
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

        if testMode {
            locationManager.stopUpdatingLocation()
            locationManager.allowsBackgroundLocationUpdates = false
            locationStatus = .active
            isTracking = false
            return
        }

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

    func evaluateRideSession(at date: Date = Date()) {
        handleRideSessionTransition(rideSessionLifecycle.advanceTime(to: date))
    }

    private func startInactivityTimer() {
        inactivityTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 15, repeating: 15)
        timer.setEventHandler { [weak self] in
            self?.evaluateRideSession()
        }
        inactivityTimer = timer
        timer.resume()
    }

    private func handleRideSessionTransition(_ transition: RideSessionTransition) {
        rideSessionState = rideSessionLifecycle.state
        switch transition {
        case .none:
            return
        case .inactivityPrompt(let deadline):
            cancelActivePlaceLookup(reason: .inactivityPrompted)
            geocodeRequestGeneration = UUID()
            geocoder.cancelGeocode()
            inFlightFactTask?.cancel()
            inFlightFactTask = nil
            inFlightFactBoundary = nil
            inFlightFactAnnouncementID = nil
            activeAnnouncementToken = UUID()
            cancelPendingAnnouncement(reason: .inactivityPrompted)
            stopSpeechOutput()
            inactivityNotifier.showInactivityPrompt(deadline: deadline)
            recordDiagnostic(.rideInactivityPrompted)
            AppDiagnostics.log("Ride paused after the configured inactivity interval without confirmed movement.")
        case .movementResumed:
            inactivityNotifier.cancelInactivityPrompt()
            recordDiagnostic(.rideMovementResumed)
            AppDiagnostics.log("Ride resumed after confirmed movement.")
        case .automaticEnd:
            finishRideSession()
            AppDiagnostics.log("Ride ended after inactivity confirmation expired.")
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

#if INTERNAL_AUDIO_CALIBRATION
    var isRideActiveForCalibration: Bool {
        rideSessionState.isActive
    }

    var calibrationAudioSnapshot: AudioSessionSnapshot {
        audioSession.snapshot
    }

    func playCalibrationApple(
        announcementText: String,
        fixtureID: SpeechCalibrationFixture,
        profileID: String,
        onPlaybackStarted: @escaping @MainActor () -> Void,
        completion: @escaping @MainActor (Result<Void, Error>) -> Void
    ) {
        guard !rideSessionState.isActive else {
            completion(.failure(SpeechCalibrationError.rideActive))
            return
        }
        stopCalibrationPlayback()
        let token = UUID()
        calibrationPlaybackToken = token
        calibrationAppleCompletion = completion
        calibrationPlaybackStarted = onPlaybackStarted
        calibrationAppleSessionActivationFailed = false
        calibrationDiagnosticContext = SpeechCalibrationDiagnosticSnapshot(
            fixtureID: fixtureID.rawValue,
            provider: .apple,
            profileID: profileID,
            appliedGainDB: nil,
            compressionPreset: nil,
            presenceGainDB: nil,
            resultingSamplePeak: nil,
            processingDurationSeconds: nil,
            terminalOutcome: nil
        )
        if let calibrationDiagnosticContext {
            diagnostics.recordCalibration(.speechCalibrationStarted, snapshot: calibrationDiagnosticContext)
        }
        calibrationAppleSpeechOutput.speak(
            text: announcementText,
            boundary: nil,
            voice: resolveSpeechVoice(),
            requestID: token
        )
    }

    func playCalibrationPremium(
        rawSpeechAudio: Data,
        profile: SpeechProcessingProfile,
        fixtureID: SpeechCalibrationFixture,
        profileID: String,
        onPlaybackStarted: @escaping @MainActor () -> Void,
        completion: @escaping @MainActor (Result<PreparedPremiumAudio, Error>) -> Void
    ) {
        guard !rideSessionState.isActive else {
            completion(.failure(SpeechCalibrationError.rideActive))
            return
        }
        stopCalibrationPlayback()
        let token = UUID()
        calibrationPlaybackToken = token
        calibrationPremiumCompletion = completion
        calibrationPlaybackStarted = onPlaybackStarted
        calibrationDiagnosticContext = SpeechCalibrationDiagnosticSnapshot(
            fixtureID: fixtureID.rawValue,
            provider: .premiumVoice,
            profileID: profileID,
            appliedGainDB: nil,
            compressionPreset: profile.compressionPreset.rawValue,
            presenceGainDB: profile.presenceGainDB,
            resultingSamplePeak: nil,
            processingDurationSeconds: nil,
            terminalOutcome: nil
        )
        if let calibrationDiagnosticContext {
            diagnostics.recordCalibration(.speechCalibrationStarted, snapshot: calibrationDiagnosticContext)
        }
        let processor = calibrationProcessor
        calibrationPreparationTask = Task { [weak self] in
            do {
                let prepared = try await processor.prepare(
                    speechAudio: [rawSpeechAudio],
                    profile: profile
                )
                try Task.checkCancellation()
                await MainActor.run {
                    guard let self, self.calibrationPlaybackToken == token else { return }
                    self.calibrationPreparationTask = nil
                    guard let firstBuffer = prepared.buffers.first else {
                        self.finishCalibrationPremium(
                            with: .failure(PremiumAudioPlaybackError.emptyAudio),
                            failureOutcome: .preparationFailed
                        )
                        return
                    }
                    guard self.acquireAudioSessionForSpeech(provider: .proxyElevenLabs, announcementID: nil) else {
                        self.finishCalibrationPremium(
                            with: .failure(SpeechCalibrationError.playbackFailed),
                            failureOutcome: .sessionFailed
                        )
                        return
                    }
                    do {
                        try self.calibrationPremiumAudioPlayer.play(buffer: firstBuffer) { [weak self] result in
                            guard let self, self.calibrationPlaybackToken == token else { return }
                            switch result {
                            case .success:
                                self.finishCalibrationPremium(with: .success(prepared))
                            case .failure(let error):
                                self.finishCalibrationPremium(with: .failure(error))
                            }
                        }
                        self.calibrationPlaybackStarted?()
                    } catch {
                        self.finishCalibrationPremium(with: .failure(error))
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self, self.calibrationPlaybackToken == token else { return }
                    self.calibrationPreparationTask = nil
                    self.finishCalibrationPremium(
                        with: .failure(error),
                        failureOutcome: .preparationFailed
                    )
                }
            }
        }
        ProxyDiagnostics.log(
            "Speech",
            "Calibration prepared fixture=\(fixtureID.rawValue), profile=\(profileID), outputGainDb=\(profile.outputGainDB), compression=\(profile.compressionPreset.rawValue), presenceGainDb=\(profile.presenceGainDB)."
        )
    }

    func stopCalibrationPlayback() {
        let premiumCompletion = calibrationPremiumCompletion
        let appleCompletion = calibrationAppleCompletion
        calibrationPlaybackToken = UUID()
        calibrationPreparationTask?.cancel()
        calibrationPreparationTask = nil
        calibrationPremiumAudioPlayer.stop()
        calibrationAppleSpeechOutput.stop()
        calibrationPremiumCompletion = nil
        calibrationAppleCompletion = nil
        calibrationPlaybackStarted = nil
        calibrationAppleSessionActivationFailed = false
        announcementStatus = .idle
        releaseAudioSessionAfterSpeech()
        if premiumCompletion != nil || appleCompletion != nil {
            recordCalibrationTerminal(.cancelled, event: .speechCalibrationCancelled)
        }
        premiumCompletion?(.failure(SpeechCalibrationError.cancelled))
        appleCompletion?(.failure(SpeechCalibrationError.cancelled))
    }

    private func finishCalibrationPremium(
        with result: Result<PreparedPremiumAudio, Error>,
        failureOutcome: SpeechCalibrationDiagnosticOutcome = .playbackFailed
    ) {
        let completion = calibrationPremiumCompletion
        calibrationPremiumCompletion = nil
        calibrationPlaybackStarted = nil
        calibrationPremiumAudioPlayer.stop()
        announcementStatus = .idle
        releaseAudioSessionAfterSpeech()
        switch result {
        case .success(let prepared):
            recordCalibrationTerminal(
                .completed,
                event: .speechCalibrationFinished,
                prepared: prepared
            )
        case .failure(let error):
            let outcome: SpeechCalibrationDiagnosticOutcome = error as? SpeechCalibrationError == .cancelled
                ? .cancelled
                : failureOutcome
            recordCalibrationTerminal(
                outcome,
                event: outcome == .cancelled ? .speechCalibrationCancelled : .speechCalibrationFailed
            )
        }
        completion?(result)
    }

    private func finishCalibrationApple(
        with result: Result<Void, Error>,
        failureOutcome: SpeechCalibrationDiagnosticOutcome = .playbackFailed
    ) {
        let completion = calibrationAppleCompletion
        calibrationAppleCompletion = nil
        calibrationPlaybackStarted = nil
        announcementStatus = .idle
        releaseAudioSessionAfterSpeech()
        switch result {
        case .success:
            recordCalibrationTerminal(.completed, event: .speechCalibrationFinished)
        case .failure(let error):
            let outcome: SpeechCalibrationDiagnosticOutcome = failureOutcome == .sessionFailed
                ? .sessionFailed
                : (error as? SpeechCalibrationError == .cancelled ? .cancelled : failureOutcome)
            recordCalibrationTerminal(
                outcome,
                event: outcome == .cancelled ? .speechCalibrationCancelled : .speechCalibrationFailed
            )
        }
        completion?(result)
    }

    private func recordCalibrationTerminal(
        _ outcome: SpeechCalibrationDiagnosticOutcome,
        event: RideDiagnosticEvent,
        prepared: PreparedPremiumAudio? = nil
    ) {
        guard let context = calibrationDiagnosticContext else { return }
        let snapshot = SpeechCalibrationDiagnosticSnapshot(
            fixtureID: context.fixtureID,
            provider: context.provider,
            profileID: context.profileID,
            appliedGainDB: prepared?.gainDecibels,
            compressionPreset: context.compressionPreset,
            presenceGainDB: context.presenceGainDB,
            resultingSamplePeak: prepared?.resultingSamplePeak,
            processingDurationSeconds: prepared?.processingDuration,
            terminalOutcome: outcome
        )
        diagnostics.recordCalibration(event, snapshot: snapshot)
        calibrationDiagnosticContext = nil
    }
#endif

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

    private func processResolvedAddress(_ address: Address, placeLookupID: UUID? = nil) {
        if speakAfterEveryGeocode {
            handleDebugSpeech(for: address, placeLookupID: placeLookupID)
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
            fetchFactAndEnqueue(
                plan: plan,
                address: address,
                mode: factMode,
                placeLookupID: placeLookupID
            )
        } else if contentMode != .quiet {
            lastBoundaryAnnouncementTime = Date()
            enqueueAnnouncement(plan, placeLookupID: placeLookupID)
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
            interruptedSpeechPlan?.boundary,
            isSpeechOutputActive ? activeSpeechPlan?.boundary : nil
        ].compactMap { $0 }

        if let highestPriorityBoundary = activeBoundaries.min(),
           newBoundary > highestPriorityBoundary {
            return false
        }

        guard !activeBoundaries.isEmpty else { return true }
        let supersededAnnouncementIDs = [
            inFlightFactAnnouncementID,
            announcementQueue.pending?.id,
            interruptedSpeechPlan?.id,
            isSpeechOutputActive ? activeSpeechPlan?.id : nil
        ].compactMap { $0 }
        for announcementID in Set(supersededAnnouncementIDs) {
            recordDiagnostic(
                .announcementSuperseded,
                announcementID: announcementID,
                reason: .supersededByNewerContext
            )
        }
        activeAnnouncementToken = UUID()
        inFlightFactTask?.cancel()
        inFlightFactTask = nil
        inFlightFactBoundary = nil
        inFlightFactAnnouncementID = nil
        interruptedSpeechPlan = nil
        cancelPendingAnnouncement(reason: .supersededByNewerContext)
        if speechOutput.isPlayingAudio {
            stopSpeechOutput()
        } else {
            speechOutput.cancelPendingPreparation()
        }
        return true
    }

    private func fetchFactAndEnqueue(
        plan: AnnouncementPlan,
        address: Address,
        mode: FactMode,
        placeLookupID: UUID? = nil
    ) {
        let token = UUID()
        activeAnnouncementToken = token
        inFlightFactTask?.cancel()
        inFlightFactBoundary = plan.boundary
        inFlightFactAnnouncementID = plan.id
        cancelPendingAnnouncement(reason: .supersededByNewerContext)
        announcementStatus = .retrievingContent
        recordDiagnostic(.factGenerationStarted, announcementID: plan.id)

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
                self.inFlightFactAnnouncementID = nil
                guard aiSharingAllowed() else {
                    self.recordDiagnostic(
                        .factGenerationFinished,
                        announcementID: plan.id,
                        reason: .factUnavailable
                    )
                    self.enqueueAnnouncement(plan, placeLookupID: placeLookupID)
                    return
                }
                self.recordDiagnostic(
                    .factGenerationFinished,
                    announcementID: plan.id,
                    reason: fact == nil ? .factUnavailable : .factAvailable
                )
                if fact == nil {
                    self.recordDiagnostic(
                        .announcementFailed,
                        announcementID: plan.id,
                        reason: .factUnavailable
                    )
                    ProxyDiagnostics.log("Facts", "No proxy fact available. Speaking base phrase for \(request.cacheKey).")
                }
                let text = FactPhraseBuilder.utterance(basePhrase: plan.text, fact: fact, mode: mode)
                self.enqueueAnnouncement(
                    AnnouncementPlan(id: plan.id, text: text, boundary: plan.boundary),
                    placeLookupID: placeLookupID
                )
            }
        }
    }

    private func handleDebugSpeech(for address: Address, placeLookupID: UUID? = nil) {
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
        enqueueAnnouncement(plan, placeLookupID: placeLookupID)
    }

    private func enqueueAnnouncement(_ plan: AnnouncementPlan, placeLookupID: UUID? = nil) {
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

        let request = announcementQueue.replacePending(
            id: plan.id,
            text: plan.text,
            boundary: plan.boundary
        )
        announcementStatus = .phraseReady
        recordDiagnostic(
            .announcementTextReady,
            placeLookupID: placeLookupID,
            announcementID: plan.id
        )
        recordDiagnostic(
            .announcementQueued,
            placeLookupID: placeLookupID,
            announcementID: plan.id
        )
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

    private func cancelPendingAnnouncement(reason: RideDiagnosticReason) {
        let pendingID = announcementQueue.pending?.id
        let hadPendingAnnouncement = delayWorkItem != nil || announcementQueue.pending != nil
        delayWorkItem?.cancel()
        delayWorkItem = nil
        announcementQueue.clearPending()
        if hadPendingAnnouncement {
            announcementStatus = .idle
            recordDiagnostic(
                .announcementCancelled,
                announcementID: pendingID,
                reason: reason
            )
        }
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
        speak(
            announcementID: pending.id,
            text: pending.text,
            boundary: pending.boundary
        )
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
        guard rideSessionState.isActive else { return }
        if testMode { return }

        if let location = locations.last {
            let currentTime = Date()
            let transition = rideSessionLifecycle.observe(location, at: currentTime)
            let shouldRecordLocationSample = lastLocationDiagnosticTime.map {
                currentTime.timeIntervalSince($0) >= 10
            } ?? true
            if transition != .none || shouldRecordLocationSample {
                recordDiagnostic(
                    .locationSampleObserved,
                    at: currentTime,
                    horizontalAccuracyMetres: location.horizontalAccuracy,
                    locationSampleAgeSeconds: currentTime.timeIntervalSince(location.timestamp)
                )
                lastLocationDiagnosticTime = currentTime
            }
            handleRideSessionTransition(transition)
            guard rideSessionState == .riding else { return }

            lastKnownLocation = location.coordinate
            currentSpeedMetersPerSecond = location.speed
            locationStatus = .active

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
        guard rideSessionState.isActive else { return }
        locationStatus = .locationUnavailable("Location update failed. \(ProductIdentity.displayName) will keep trying.")
        AppDiagnostics.log("Location update failed.")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startRideTrackingIfAuthorized()
    }

    private func reverseGeocode(location: CLLocation, completion: (@MainActor () -> Void)? = nil) {
        let rideGeneration = rideSessionGeneration
        let requestGeneration = UUID()
        cancelActivePlaceLookup(reason: .supersededByNewerContext)
        geocoder.cancelGeocode()
        geocodeRequestGeneration = requestGeneration
        activePlaceLookupID = requestGeneration
        recordDiagnostic(.placeLookupStarted, placeLookupID: requestGeneration)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if error != nil {
                Task { @MainActor [weak self] in
                    guard let self,
                          self.canAcceptGeocodeResult(
                            rideGeneration: rideGeneration,
                            requestGeneration: requestGeneration
                          ) else { return }
                    self.activePlaceLookupID = nil
                    self.recordDiagnostic(.placeLookupFailed, placeLookupID: requestGeneration)
                    self.locationStatus = .placeUnavailable("Place lookup failed. GPS is still active.")
                }
                AppDiagnostics.log("Reverse geocoding failed.")
                return
            }

            guard let placemark = placemarks?.first else {
                Task { @MainActor [weak self] in
                    guard let self,
                          self.canAcceptGeocodeResult(
                            rideGeneration: rideGeneration,
                            requestGeneration: requestGeneration
                          ) else { return }
                    self.activePlaceLookupID = nil
                    self.recordDiagnostic(.placeLookupFailed, placeLookupID: requestGeneration)
                    self.locationStatus = .placeUnavailable("Place name is unavailable here.")
                }
                AppDiagnostics.log("No placemark was returned.")
                return
            }

            let address = Address(placemark: placemark)
            Task { @MainActor [weak self] in
                guard let self,
                      self.canAcceptGeocodeResult(
                        rideGeneration: rideGeneration,
                        requestGeneration: requestGeneration
                      ) else { return }
                self.activePlaceLookupID = nil
                self.lastKnownAddress = address
                self.recordDiagnostic(.placeLookupFinished, placeLookupID: requestGeneration)
                AppDiagnostics.log("Resolved a place name.")

                completion?()
                self.processResolvedAddress(address, placeLookupID: requestGeneration)
            }
        }
    }

    private func cancelActivePlaceLookup(reason: RideDiagnosticReason) {
        guard let activePlaceLookupID else { return }
        recordDiagnostic(
            .placeLookupCancelled,
            placeLookupID: activePlaceLookupID,
            reason: reason
        )
        self.activePlaceLookupID = nil
    }

    private func canAcceptGeocodeResult(
        rideGeneration: UUID,
        requestGeneration: UUID
    ) -> Bool {
        rideSessionState == .riding
            && rideSessionGeneration == rideGeneration
            && geocodeRequestGeneration == requestGeneration
    }

    private func recordDiagnostic(
        _ event: RideDiagnosticEvent,
        at timestamp: Date = Date(),
        placeLookupID: UUID? = nil,
        announcementID: UUID? = nil,
        reason: RideDiagnosticReason? = nil,
        audioPolicy: AudioCoexistencePolicy? = nil,
        playbackPath: DiagnosticPlaybackPath? = nil,
        interruptionReason: UInt? = nil,
        shouldResume: Bool? = nil,
        routeChangeReason: UInt? = nil,
        horizontalAccuracyMetres: Double? = nil,
        locationSampleAgeSeconds: TimeInterval? = nil
    ) {
        let diagnosticState: DiagnosticRideState
        switch rideSessionState {
        case .idle:
            diagnosticState = .idle
        case .riding:
            diagnosticState = .riding
        case .awaitingConfirmation:
            diagnosticState = .awaitingConfirmation
        }
        diagnostics.record(
            event,
            rideSessionID: activeRideSessionID,
            placeLookupID: placeLookupID,
            announcementID: announcementID,
            reason: reason,
            appState: diagnosticAppState,
            audio: audioSession.snapshot,
            audioPolicy: audioPolicy,
            elapsedRideSeconds: rideStartedAt.map { max(0, timestamp.timeIntervalSince($0)) },
            rideState: diagnosticState,
            isLocationTracking: isTracking,
            playbackPath: playbackPath,
            interruptionReason: interruptionReason,
            shouldResume: shouldResume,
            routeChangeReason: routeChangeReason,
            horizontalAccuracyMetres: horizontalAccuracyMetres,
            locationSampleAgeSeconds: locationSampleAgeSeconds,
            at: timestamp
        )
    }

    private func acquireAudioSessionForSpeech(
        provider: SpeechProvider,
        announcementID: UUID?
    ) -> Bool {
        audioSessionReleaseRetryWorkItem?.cancel()
        audioSessionReleaseRetryWorkItem = nil
        if !ownsAudioSession {
            do {
                try audioSession.activate(policy: audioCoexistencePolicy)
                ownsAudioSession = true
                recordDiagnostic(
                    .audioSessionActivated,
                    announcementID: announcementID,
                    audioPolicy: audioCoexistencePolicy
                )
                AppDiagnostics.log("Audio session activated for speech playback.")
            } catch {
                recordDiagnostic(
                    .audioSessionActivationFailed,
                    announcementID: announcementID,
                    audioPolicy: audioCoexistencePolicy
                )
                announcementStatus = .idle
                AppDiagnostics.log("Audio session activation failed; playback cancelled.")
                return false
            }
        }
        announcementStatus = .speaking
        recordDiagnostic(
            .audioPlaybackStarted,
            announcementID: announcementID,
            audioPolicy: audioCoexistencePolicy,
            playbackPath: provider == .apple ? .apple : .premiumVoice
        )
        return true
    }

    private func releaseAudioSessionAfterSpeech(announcementID: UUID? = nil) {
        guard ownsAudioSession else { return }
        audioSessionReleaseRetryWorkItem?.cancel()
        audioSessionReleaseRetryWorkItem = nil
        do {
            try audioSession.deactivate()
            ownsAudioSession = false
            audioSessionReleaseRetryAttempts = 0
            recordDiagnostic(
                .audioSessionReleased,
                announcementID: announcementID,
                audioPolicy: audioCoexistencePolicy
            )
            AppDiagnostics.log("Audio session released after speech playback.")
        } catch {
            recordDiagnostic(
                .audioSessionReleaseFailed,
                announcementID: announcementID,
                reason: .deactivationRetry,
                audioPolicy: audioCoexistencePolicy
            )
            AppDiagnostics.log("Audio session release failed.")
            guard audioSessionReleaseRetryAttempts < 2 else {
                if audioSession.neutralizeAfterDeactivationFailure() {
                    ownsAudioSession = false
                    audioSessionReleaseRetryAttempts = 0
                    recordDiagnostic(
                        .audioSessionNeutralized,
                        announcementID: announcementID,
                        reason: .deactivationRecovery,
                        audioPolicy: .mix
                    )
                    AppDiagnostics.log("Audio session neutralized after repeated release failures.")
                } else {
                    recordDiagnostic(
                        .audioSessionNeutralizationFailed,
                        announcementID: announcementID,
                        reason: .deactivationRecovery,
                        audioPolicy: audioCoexistencePolicy
                    )
                    AppDiagnostics.log("Audio session could not be neutralized after repeated release failures.")
                }
                return
            }
            audioSessionReleaseRetryAttempts += 1
            let workItem = DispatchWorkItem { [weak self] in
                self?.releaseAudioSessionAfterSpeech(announcementID: announcementID)
            }
            audioSessionReleaseRetryWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        let interruptionReason = (userInfo[AVAudioSessionInterruptionReasonKey] as? NSNumber)?.uintValue

        if interruptionType == .began {
            observedAudioPauseSources.insert(.interruption)
            recordDiagnostic(
                .audioInterruptionBegan,
                announcementID: activeSpeechPlan?.id ?? interruptedSpeechPlan?.id,
                reason: .interruptionBegan,
                interruptionReason: interruptionReason
            )
            pauseForObservedExternalAudio()
        } else if interruptionType == .ended {
            let optionsValue = (userInfo[AVAudioSessionInterruptionOptionKey] as? NSNumber)?.uintValue ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            let shouldResume = options.contains(.shouldResume)
            observedAudioPauseSources.remove(.interruption)
            recordDiagnostic(
                .audioInterruptionEnded,
                announcementID: interruptedSpeechPlan?.id,
                reason: shouldResume ? .interruptionShouldResume : .interruptionMustNotResume,
                interruptionReason: interruptionReason,
                shouldResume: shouldResume
            )
            if shouldResume {
                resumeInterruptedSpeech(reason: .interruptionShouldResume)
            } else {
                recordDiagnostic(
                    .announcementCancelled,
                    announcementID: interruptedSpeechPlan?.id,
                    reason: .interruptionMustNotResume
                )
                interruptedSpeechPlan = nil
                announcementStatus = .idle
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
            observedAudioPauseSources.insert(.primaryAudio)
            recordDiagnostic(
                .primaryAudioBegan,
                announcementID: activeSpeechPlan?.id
                    ?? announcementQueue.pending?.id
                    ?? interruptedSpeechPlan?.id,
                reason: .primaryAudioActive
            )
            pauseForObservedExternalAudio()
        case .end:
            observedAudioPauseSources.remove(.primaryAudio)
            recordDiagnostic(
                .primaryAudioEnded,
                announcementID: interruptedSpeechPlan?.id,
                reason: .primaryAudioEnded
            )
            resumeInterruptedSpeech(reason: .primaryAudioEnded)
        @unknown default:
            return
        }
    }

    @objc private func handleAudioRouteChange(_ notification: Notification) {
        let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
        recordDiagnostic(.audioRouteChanged, routeChangeReason: reason)
    }

    @objc private func handleAudioMediaServicesReset(_ notification: Notification) {
        audioSessionReleaseRetryWorkItem?.cancel()
        audioSessionReleaseRetryWorkItem = nil
        audioSessionReleaseRetryAttempts = 0
        ownsAudioSession = false
        observedAudioPauseSources.removeAll()
        recordDiagnostic(.audioMediaServicesReset)
        resumeInterruptedSpeech(reason: .mediaServicesReset)
    }

    private func pauseForObservedExternalAudio() {
        if let activeSpeechPlan {
            interruptedSpeechPlan = activeSpeechPlan
        } else if let pending = announcementQueue.pending {
            interruptedSpeechPlan = AnnouncementPlan(
                id: pending.id,
                text: pending.text,
                boundary: pending.boundary
            )
            announcementQueue.clearPending(id: pending.id)
            delayWorkItem?.cancel()
            delayWorkItem = nil
        }

        if isSpeechOutputActive {
            AppDiagnostics.log("RideHorizon speech stopped for primary audio.")
            stopSpeechOutput()
        }

        guard interruptedSpeechPlan != nil else { return }
        announcementStatus = .waitingForAudio
    }

    private func resumeInterruptedSpeech(reason: RideDiagnosticReason) {
        guard observedAudioPauseSources.isEmpty,
              rideSessionState == .riding,
              let plan = interruptedSpeechPlan else { return }
        interruptedSpeechPlan = nil
        recordDiagnostic(
            .announcementRestarted,
            announcementID: plan.id,
            reason: reason
        )
        speak(
            announcementID: plan.id,
            text: plan.text,
            boundary: plan.boundary,
            shouldRecordTestLog: false
        )
    }

    private func speak(
        announcementID: UUID = UUID(),
        text: String,
        boundary: BoundaryType? = nil,
        shouldRecordTestLog: Bool = true,
        ignoreQuietMode: Bool = false
    ) {
        guard ignoreQuietMode || contentMode != .quiet else { return }
        if !observedAudioPauseSources.isEmpty {
            interruptedSpeechPlan = AnnouncementPlan(
                id: announcementID,
                text: text,
                boundary: boundary ?? .street
            )
            announcementStatus = .waitingForAudio
            recordDiagnostic(
                .announcementDeferred,
                announcementID: announcementID,
                reason: observedAudioPauseSources.contains(.interruption)
                    ? .interruptionBegan
                    : .primaryAudioActive
            )
            return
        }
        currentlySpeakingBoundary = boundary
        activeSpeechPlan = AnnouncementPlan(
            id: announcementID,
            text: text,
            boundary: boundary ?? .street
        )
        AppDiagnostics.log("Speaking an announcement.")
        lastSpokenPhrase = text
        lastSpokenAt = Date()
        lastSpeechDiagnosticNote = nil
        if shouldRecordTestLog {
            recordTestLog(utteredPhrase: text)
        }

        let provider = aiSharingAllowed() ? speechProvider : .apple
        announcementStatus = .preparingVoice
        speechOutput.speak(
            text: text,
            boundary: boundary,
            provider: provider,
            appleVoice: resolveSpeechVoice(),
            allowAppleFallback: aiSharingAllowed() ? premiumVoiceAppleFallbackEnabled : false,
            announcementID: announcementID
        )
    }

    private func stopSpeechOutput() {
        let announcementID = activeSpeechPlan?.id
        speechOutput.stop()
        releaseAudioSessionAfterSpeech(announcementID: announcementID)
        activeSpeechPlan = nil
        currentlySpeakingBoundary = nil
    }

#if DEBUG
    func startRideWithoutLocationInputForTesting(at date: Date = Date()) {
        startRide(at: date, startsLocationInput: false)
    }

    func speakForTesting(text: String, boundary: BoundaryType) {
        speak(text: text, boundary: boundary, shouldRecordTestLog: false, ignoreQuietMode: true)
    }

    func processResolvedAddressForTesting(_ address: Address, placeLookupID: UUID? = nil) {
        processResolvedAddress(address, placeLookupID: placeLookupID)
    }

    func beginPlaceLookupDiagnosticForTesting() -> UUID {
        let lookupID = UUID()
        geocodeRequestGeneration = lookupID
        activePlaceLookupID = lookupID
        recordDiagnostic(.placeLookupStarted, placeLookupID: lookupID)
        return lookupID
    }

    var hasInterruptedSpeechPlanForTesting: Bool {
        interruptedSpeechPlan != nil
    }

    var rideSessionGenerationForTesting: UUID {
        rideSessionGeneration
    }

    var geocodeRequestGenerationForTesting: UUID {
        geocodeRequestGeneration
    }

    func canAcceptGeocodeResultForTesting(
        rideGeneration: UUID,
        requestGeneration: UUID
    ) -> Bool {
        canAcceptGeocodeResult(
            rideGeneration: rideGeneration,
            requestGeneration: requestGeneration
        )
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

    /// Advances the shared Test Mode route. Every UI trigger uses this single pipeline entry point.
    func advanceTestLocation() {
        guard testMode, rideSessionState.isActive else { return }
        let waypoint = TestRouteFixture.waypoint(at: testIndex)
        testIndex = (testIndex + 1) % TestRouteFixture.waypoints.count

        let sampleDate = Date()
        let sampleLocation = CLLocation(
            coordinate: waypoint.coordinate,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 0,
            timestamp: sampleDate
        )
        handleRideSessionTransition(rideSessionLifecycle.observe(sampleLocation, at: sampleDate))
        guard rideSessionState == .riding else { return }

        lastKnownLocation = waypoint.coordinate
        currentSpeedMetersPerSecond = 0
        locationStatus = .active
        AppDiagnostics.log("Test location advanced.")

        reverseGeocode(location: sampleLocation)
    }

    private func startTestRouteIfNeeded() {
        guard testMode, rideSessionState.isActive, !hasSeededTestRoute else { return }
        hasSeededTestRoute = true
        testIndex = 0
        advanceTestLocation()
    }
}
