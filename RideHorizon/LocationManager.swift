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
protocol SpeechOutput: AnyObject {
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
        appleVoice: SpeechVoiceSelection?,
        allowAppleFallback: Bool,
        announcementID: UUID
    )
    func cancelPendingPreparation()
    func stop()
}

protocol SpeechOutputEngine: SpeechOutput {}

enum SpeechOutputPipelineStage: Equatable {
    case ttsRequested
    case speechAudioReady
    case retryScheduled
    case fallbackStarted
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
    private var currentProxyFallbackAppleVoice: SpeechVoiceSelection?
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
        appleVoice: SpeechVoiceSelection?,
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
        appleVoice: SpeechVoiceSelection?,
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
                let speechAudioSegments: [Data]
                if let retryReportingGenerator = proxySpeechGenerator as? RetryReportingProxySpeechGenerating {
                    speechAudioSegments = try await retryReportingGenerator.speechAudios(
                        for: text,
                        onRetry: { [weak self] _ in
                            Task { @MainActor [weak self] in
                                guard let self,
                                      self.playbackToken == token,
                                      let announcementID = self.currentAnnouncementID else { return }
                                self.onPipelineEvent?(SpeechOutputPipelineEvent(
                                    announcementID: announcementID,
                                    provider: .proxyElevenLabs,
                                    stage: .retryScheduled
                                ))
                            }
                        }
                    )
                } else {
                    speechAudioSegments = try await proxySpeechGenerator.speechAudios(for: text)
                }
                guard !speechAudioSegments.isEmpty else {
                    throw PremiumAudioPlaybackError.emptyAudio
                }
                let preparedAudio = try await PremiumAudioPreparer.prepare(
                    dataSegments: speechAudioSegments
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
        appleVoice: SpeechVoiceSelection?,
        allowAppleFallback: Bool
    ) {
        if allowAppleFallback {
            ProxyDiagnostics.log("Speech", message)
            if let announcementID = currentAnnouncementID {
                onPipelineEvent?(SpeechOutputPipelineEvent(
                    announcementID: announcementID,
                    provider: .proxyElevenLabs,
                    stage: .fallbackStarted
                ))
            }
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

    private func speakWithApple(text: String, boundary: BoundaryType?, appleVoice: SpeechVoiceSelection?) {
        if let announcementID = currentAnnouncementID {
            onPipelineEvent?(SpeechOutputPipelineEvent(
                announcementID: announcementID,
                provider: .apple,
                stage: .ttsRequested
            ))
        }
        let requestID = UUID()
        playbackToken = requestID
        let resolvedVoice = appleVoice.flatMap { AVSpeechSynthesisVoice(identifier: $0.identifier) }
        appleSpeechOutput.speak(text: text, boundary: boundary, voice: resolvedVoice, requestID: requestID)
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
        appleVoice: SpeechVoiceSelection?,
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

@MainActor
protocol LocationSource: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var onLocations: (([CLLocation]) -> Void)? { get set }
    var onFailure: ((Error) -> Void)? { get set }
    var onAuthorizationChange: (() -> Void)? { get set }
    func requestLocation()
    func requestAlwaysAuthorization()
    func start(backgroundUpdates: Bool)
    func stop()
}

@MainActor
protocol PlaceResolver: AnyObject {
    func resolve(_ location: AcceptedRideLocation, completion: @escaping (PlaceResolutionResult) -> Void)
    func cancel()
}

@MainActor
final class CoreLocationAdapter: NSObject, LocationSource, PlaceResolver, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private let geocoder: CLGeocoder
    var onLocations: (([CLLocation]) -> Void)?
    var onFailure: ((Error) -> Void)?
    var onAuthorizationChange: (() -> Void)?

    init(manager: CLLocationManager = CLLocationManager(), geocoder: CLGeocoder = CLGeocoder()) {
        self.manager = manager
        self.geocoder = geocoder
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.pausesLocationUpdatesAutomatically = false
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }
    func requestLocation() { manager.requestLocation() }
    func requestAlwaysAuthorization() { manager.requestAlwaysAuthorization() }

    func start(backgroundUpdates: Bool) {
        manager.allowsBackgroundLocationUpdates = backgroundUpdates
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    func resolve(_ location: AcceptedRideLocation, completion: @escaping (PlaceResolutionResult) -> Void) {
        geocoder.reverseGeocodeLocation(CLLocation(
            latitude: location.latitude,
            longitude: location.longitude
        )) { placemarks, error in
            if error != nil {
                completion(.failed)
            } else if let placemark = placemarks?.first {
                completion(.resolved(Address(placemark: placemark)))
            } else {
                completion(.unavailable)
            }
        }
    }

    func cancel() { geocoder.cancelGeocode() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { onLocations?(locations) }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { onFailure?(error) }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { onAuthorizationChange?() }
}

struct CoreLocationRideDistanceMeasurer: RideDistanceMeasuring {
    func distance(from: AcceptedRideLocation, to: AcceptedRideLocation) -> Double {
        CLLocation(latitude: from.latitude, longitude: from.longitude).distance(
            from: CLLocation(latitude: to.latitude, longitude: to.longitude)
        )
    }
}

@MainActor
class LocationManager: NSObject, ObservableObject {
    static let movingMapInteractionThresholdMetersPerSecond = 8.0 / 3.6

    private let locationSource: LocationSource
    private let placeResolver: PlaceResolver
    private let rideDistanceMeasurer: RideDistanceMeasuring
    private let audioSession: AudioSessionManaging
    private let diagnostics: RideDiagnosticsStore
    private let rideSettingsStore: RideSettingsStore
    private var ownsAudioSession = false
    private var lastUpdateTime: Date?
    private var lastLocationDiagnosticTime: Date?
    private var testIndex = 0
    private let announcementCoordinator: AnnouncementCoordinator
    private let aiSharingAllowed: () -> Bool
    private let inactivityNotifier: RideInactivityNotifying
    private var wantsRideTracking: Bool { rideSessionController.wantsLocationInput }
    private var hasSeededTestRoute = false
    private let rideSessionController: RideSessionController
    private var rideStartedAt: Date?
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
    @Published var boundarySpeechCooldownSeconds: Int {
        didSet { persistRideSettings(.boundarySpeechCooldownSeconds) }
    }
    @Published var announceStreet: Bool = false
    @Published var announceTown: Bool = true
    @Published var announceCounty: Bool = true
    @Published var announceNation: Bool = true
    @Published var announceCountry: Bool = true
    @Published var contentMode: ContentMode = .shortFacts
    @Published var bluetoothDelaySeconds: Double = 0.5
#if DEBUG
    @Published var shortInactivityTimeout: Bool {
        didSet { persistRideSettings(.shortInactivityTimeout) }
    }
#endif
    @Published var testMode: Bool {
        didSet {
            persistRideSettings(.testMode)
            if testMode {
                applyDebugTestModeCampaignDefaults()
                locationSource.stop()
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
    @Published var interruptsMusic: Bool {
        didSet { persistRideSettings(.interruptsMusic) }
    }
    @Published var premiumVoiceAppleFallbackEnabled: Bool {
        didSet { persistRideSettings(.premiumVoiceAppleFallbackEnabled) }
    }
    @Published var preferredVoiceIdentifier: String {
        didSet { persistRideSettings(.preferredVoiceIdentifier) }
    }

    @Published var speechProvider: SpeechProvider {
        didSet { persistRideSettings(.speechProvider) }
    }
    @Published var lastNonQuietContentMode: ContentMode {
        didSet { persistRideSettings(.lastNonQuietContentMode) }
    }

    @Published var homeCountry: String {
        didSet { persistRideSettings(.homeCountry) }
    }

    @Published var homeRegion: String {
        didSet { persistRideSettings(.homeRegion) }
    }

    @Published var familiarRegions: String {
        didSet { persistRideSettings(.familiarRegions) }
    }

    @Published var customFactInstructions: String {
        didSet { persistRideSettings(.customFactInstructions) }
    }
    @Published var factInterestCategories: [FactInterestCategory] {
        didSet { persistRideSettings(.factInterestCategories) }
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
        announcementCoordinator.isSpeaking
    }

    private var audioCoexistencePolicy: AudioCoexistencePolicy {
        interruptsMusic ? .interrupt : .mix
    }

    var onAddressChange: ((Address) -> Void)?
    var onRideLog: ((CLLocationCoordinate2D, Address, String?) -> Void)?

    init(
        announcementCoordinator: AnnouncementCoordinator,
        inactivityNotifier: RideInactivityNotifying,
        audioSession: AudioSessionManaging,
        diagnostics: RideDiagnosticsStore,
        rideSettingsStore: RideSettingsStore,
        rideSessionController: RideSessionController,
        locationSource: LocationSource,
        placeResolver: PlaceResolver,
        rideDistanceMeasurer: RideDistanceMeasuring,
        aiSharingAllowed: @escaping () -> Bool = { AISharingConsentStore.isGranted() }
    ) {
        let settings = rideSettingsStore.load()
        self.rideSettingsStore = rideSettingsStore
        self.boundarySpeechCooldownSeconds = settings.boundarySpeechCooldownSeconds
#if DEBUG
        self.shortInactivityTimeout = settings.shortInactivityTimeout
#endif
        self.testMode = settings.testMode
        self.interruptsMusic = settings.interruptsMusic
        self.premiumVoiceAppleFallbackEnabled = settings.premiumVoiceAppleFallbackEnabled
        self.preferredVoiceIdentifier = settings.preferredVoiceIdentifier
        self.speechProvider = settings.speechProvider
        self.lastNonQuietContentMode = settings.lastNonQuietContentMode
        self.homeCountry = settings.homeCountry
        self.homeRegion = settings.homeRegion
        self.familiarRegions = settings.familiarRegions
        self.customFactInstructions = settings.customFactInstructions
        self.factInterestCategories = settings.factInterestCategories
        self.locationSource = locationSource
        self.placeResolver = placeResolver
        self.rideDistanceMeasurer = rideDistanceMeasurer
        self.announcementCoordinator = announcementCoordinator
        self.inactivityNotifier = inactivityNotifier
        self.audioSession = audioSession
        self.diagnostics = diagnostics
        self.rideSessionController = rideSessionController
        self.aiSharingAllowed = aiSharingAllowed
        super.init()
        configureAnnouncementCoordinator()
        if testMode {
            applyDebugTestModeCampaignDefaults()
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
        self.locationSource.onLocations = { [weak self] locations in self?.handleLocations(locations) }
        self.locationSource.onFailure = { [weak self] error in self?.handleLocationFailure(error) }
        self.locationSource.onAuthorizationChange = { [weak self] in self?.startRideTrackingIfAuthorized() }

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

    private func configureAnnouncementCoordinator() {
        announcementCoordinator.onResult = { [weak self] result in
            self?.handleAnnouncementWorkflowResult(result)
        }
        announcementCoordinator.onDiagnosticNote = { [weak self] note in
            self?.lastSpeechDiagnosticNote = note
        }
    }

#if DEBUG
    convenience init(
        factGenerator: FactClient? = nil,
        speechOutput: SpeechOutput? = nil,
        inactivityNotifier: RideInactivityNotifying? = nil,
        audioSession: AudioSessionManaging? = nil,
        diagnostics: RideDiagnosticsStore? = nil,
        rideSettingsStore: RideSettingsStore? = nil,
        rideSessionController: RideSessionController? = nil,
        aiSharingAllowed: @escaping () -> Bool = { AISharingConsentStore.isGranted() }
    ) {
        let locationAdapter = CoreLocationAdapter()
        let resolvedFactGenerator = factGenerator ?? Self.makeDefaultFactGenerator()
        let resolvedSpeechOutput = speechOutput ?? DefaultSpeechOutputEngine()
        let resolvedAudioSession = audioSession ?? SystemAudioSessionManager()
        let diagnosticsRelay = AnnouncementDiagnosticsRelay()
        let coordinator = AnnouncementCoordinator(
            scheduler: DispatchAnnouncementScheduler(),
            audioReleaseScheduler: DispatchAnnouncementScheduler(),
            factClient: resolvedFactGenerator,
            speechOutput: resolvedSpeechOutput,
            audioSession: resolvedAudioSession,
            diagnostics: diagnosticsRelay
        )
        self.init(
            announcementCoordinator: coordinator,
            inactivityNotifier: inactivityNotifier ?? UserNotificationRideInactivityNotifier(),
            audioSession: resolvedAudioSession,
            diagnostics: diagnostics ?? .shared,
            rideSettingsStore: rideSettingsStore ?? UserDefaultsRideSettingsStore(),
            rideSessionController: rideSessionController ?? RideSessionController(),
            locationSource: locationAdapter,
            placeResolver: locationAdapter,
            rideDistanceMeasurer: CoreLocationRideDistanceMeasurer(),
            aiSharingAllowed: aiSharingAllowed
        )
        diagnosticsRelay.connect { [weak self] signal in
            self?.recordAnnouncementDiagnostic(signal)
        }
    }

    convenience init(
        locationSource: LocationSource,
        placeResolver: PlaceResolver,
        rideDistanceMeasurer: RideDistanceMeasuring,
        aiSharingAllowed: @escaping () -> Bool = { AISharingConsentStore.isGranted() }
    ) {
        let audioSession = SystemAudioSessionManager()
        let diagnosticsRelay = AnnouncementDiagnosticsRelay()
        let coordinator = AnnouncementCoordinator(
            scheduler: DispatchAnnouncementScheduler(),
            audioReleaseScheduler: DispatchAnnouncementScheduler(),
            factClient: Self.makeDefaultFactGenerator(),
            speechOutput: DefaultSpeechOutputEngine(),
            audioSession: audioSession,
            diagnostics: diagnosticsRelay
        )
        self.init(
            announcementCoordinator: coordinator,
            inactivityNotifier: UserNotificationRideInactivityNotifier(),
            audioSession: audioSession,
            diagnostics: .shared,
            rideSettingsStore: UserDefaultsRideSettingsStore(),
            rideSessionController: RideSessionController(),
            locationSource: locationSource,
            placeResolver: placeResolver,
            rideDistanceMeasurer: rideDistanceMeasurer,
            aiSharingAllowed: aiSharingAllowed
        )
        diagnosticsRelay.connect { [weak self] signal in
            self?.recordAnnouncementDiagnostic(signal)
        }
    }
#endif

    private static func makeDefaultFactGenerator() -> PlaceFactGenerating {
        CachedPlaceFactGenerator(generator: ProxyFactGenerator())
    }

    private func persistRideSettings(_ field: RideSettingField) {
        rideSettingsStore.save(rideSettingsSnapshot, changed: field)
    }

    private var rideSettingsSnapshot: RideSettings {
#if DEBUG
        let currentShortInactivityTimeout = shortInactivityTimeout
#else
        let currentShortInactivityTimeout = false
#endif
        return RideSettings(
            boundarySpeechCooldownSeconds: boundarySpeechCooldownSeconds,
            shortInactivityTimeout: currentShortInactivityTimeout,
            testMode: testMode,
            interruptsMusic: interruptsMusic,
            premiumVoiceAppleFallbackEnabled: premiumVoiceAppleFallbackEnabled,
            preferredVoiceIdentifier: preferredVoiceIdentifier,
            speechProvider: speechProvider,
            lastNonQuietContentMode: lastNonQuietContentMode,
            homeCountry: homeCountry,
            homeRegion: homeRegion,
            familiarRegions: familiarRegions,
            customFactInstructions: customFactInstructions,
            factInterestCategories: factInterestCategories
        )
    }

    func requestLocation() {
        locationSource.requestLocation()
    }

    /// Starts a rider-controlled session. Continuous and background work must remain inside this boundary.
    func startRide(at date: Date = Date()) {
        startRide(at: date, startsLocationInput: true)
    }

    private func startRide(at date: Date, startsLocationInput: Bool) {
        guard rideSessionState == .idle else { return }
#if DEBUG
        let lifecycle = shortInactivityTimeout
            ? RideSessionLifecycle(
                inactivityInterval: 30,
                confirmationGracePeriod: 30,
                distanceMeasurer: rideDistanceMeasurer
            )
            : RideSessionLifecycle(distanceMeasurer: rideDistanceMeasurer)
#else
        let lifecycle = RideSessionLifecycle(distanceMeasurer: rideDistanceMeasurer)
#endif
        guard let start = rideSessionController.start(
            at: date,
            wantsLocationInput: startsLocationInput,
            lifecycle: lifecycle,
            onScheduledEvaluation: { [weak self] transition in self?.handleRideSessionTransition(transition) }
        ) else { return }
        activeRideSessionID = start.sessionID
        rideStartedAt = start.startedAt
        rideSessionState = rideSessionController.state
        locationStatus = .checking
        applyRideSessionEffects(start.effects)
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
        handleRideSessionTransition(rideSessionController.continueRide(at: date))
    }

    func pauseRideTracking() {
        finishRideSession()
    }

    private func finishRideSession() {
        let end = rideSessionController.end()
        rideSessionState = rideSessionController.state
        applyRideSessionEffects(end.effects)
    }

    private func applyRideSessionEffects(_ effects: [RideSessionEffect]) {
        for effect in effects {
            switch effect {
            case .requestInactivityAuthorization:
                inactivityNotifier.requestAuthorizationIfNeeded()
            case .refreshLocationInput:
                startTestRouteIfNeeded()
                startRideTrackingIfAuthorized()
            case .cancelRideWork(let intent):
                cancelRideWork(for: intent)
            case .showInactivityPrompt(let deadline):
                inactivityNotifier.showInactivityPrompt(deadline: deadline)
            case .cancelInactivityPrompt:
                inactivityNotifier.cancelInactivityPrompt()
            }
        }
    }

    private func cancelRideWork(for intent: RideSessionCancellationIntent) {
        let reason: RideDiagnosticReason
        switch intent {
        case .inactivityPrompted:
            reason = .inactivityPrompted
        case .rideEnded:
            reason = .rideEnded
        }

        cancelActivePlaceLookup(reason: reason)
        _ = announcementCoordinator.cancelAll(reason: reason)

        guard case .rideEnded(let wasActive) = intent else { return }
        locationSource.stop()
        isTracking = false
        locationStatus = .idle
        announcementStatus = .idle
        currentSpeedMetersPerSecond = nil
        lastUpdateTime = nil
        lastLocationDiagnosticTime = nil
        inactivityNotifier.cancelInactivityPrompt()

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
        _ = announcementCoordinator.cancelAll(reason: .settingsChanged)

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
        placeResolver.cancel()
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
        announcementCoordinator.resetContext()
        lastUpdateTime = nil

        homeCountry = ""
        homeRegion = ""
        familiarRegions = ""
        customFactInstructions = ""
        factInterestCategories = FactInterestCategory.defaultSelections
        contentMode = .shortFacts
        lastNonQuietContentMode = .shortFacts
        speechProvider = .proxyElevenLabs
    }

    private func startRideTrackingIfAuthorized() {
        guard wantsRideTracking else { return }

        if testMode {
            locationSource.stop()
            locationStatus = .active
            isTracking = false
            return
        }

        switch locationSource.authorizationStatus {
        case .notDetermined:
            locationSource.requestAlwaysAuthorization()
            locationStatus = .waitingForPermission
            isTracking = false
        case .authorizedAlways:
            locationSource.start(backgroundUpdates: true)
            locationStatus = .active
            isTracking = true
        case .authorizedWhenInUse:
            locationSource.requestAlwaysAuthorization()
            locationSource.start(backgroundUpdates: false)
            locationStatus = .active
            isTracking = true
        case .denied, .restricted:
            locationSource.stop()
            locationStatus = locationSource.authorizationStatus == .denied ? .denied : .restricted
            isTracking = false
        @unknown default:
            locationSource.stop()
            locationStatus = .locationUnavailable("Location is unavailable on this device.")
            isTracking = false
        }
    }

    func evaluateRideSession(at date: Date = Date()) {
        handleRideSessionTransition(rideSessionController.evaluate(at: date))
    }

    private func handleRideSessionTransition(_ result: RideSessionControllerTransition) {
        rideSessionState = rideSessionController.state
        applyRideSessionEffects(result.effects)
        switch result.transition {
        case .none:
            return
        case .inactivityPrompt:
            recordDiagnostic(.rideInactivityPrompted)
            AppDiagnostics.log("Ride paused after the configured inactivity interval without confirmed movement.")
        case .rideContinued:
            recordDiagnostic(.rideContinued)
            AppDiagnostics.log("Ride continued after inactivity prompt.")
        case .movementResumed:
            recordDiagnostic(.rideMovementResumed)
            AppDiagnostics.log("Ride resumed after confirmed movement.")
        case .automaticEnd:
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
        announcementCoordinator.cancelPending()
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
        let outcome = announcementCoordinator.submit(AnnouncementWorkflowInput(
            address: address,
            settings: boundarySettings,
            mode: contentMode,
            repeatPreferences: legacyRepeatPreferences,
            speakAfterEveryGeocode: speakAfterEveryGeocode,
            riderContext: riderContext,
            delivery: AnnouncementDeliveryContext(
                selectedProvider: { [weak self] in self?.speechProvider ?? .apple },
                aiSharingAllowed: aiSharingAllowed,
                appleVoice: { [weak self] in
                    self?.resolveSpeechVoice().map { SpeechVoiceSelection(identifier: $0.identifier) }
                },
                allowAppleFallback: { [weak self] in self?.premiumVoiceAppleFallbackEnabled ?? false },
                audioPolicy: { [weak self] in self?.audioCoexistencePolicy ?? .mix },
                delay: bluetoothDelaySeconds,
                shouldRecordTestLog: true
            ),
            boundaryCooldown: TimeInterval(boundarySpeechCooldownSeconds),
            now: Date(),
            placeLookupID: placeLookupID
        ))

        switch outcome {
        case .noAnnouncement:
            if testMode { recordTestLog(utteredPhrase: nil) }
            AppDiagnostics.log("No announcement required.")
        case .suppressed(_, let supersededAnnouncementIDs):
            recordSupersededAnnouncements(supersededAnnouncementIDs)
            if testMode { recordTestLog(utteredPhrase: nil) }
            AppDiagnostics.log("Boundary announcement suppressed due cooldown.")
        case .rejected:
            if testMode { recordTestLog(utteredPhrase: nil) }
            AppDiagnostics.log("Dropped lower-priority announcement while higher-priority work remains active.")
        case .accepted(_, let supersededAnnouncementIDs):
            recordSupersededAnnouncements(supersededAnnouncementIDs)
            if !testMode { onAddressChange?(address) }
        }
    }

    private func recordTestLog(utteredPhrase: String?) {
        guard testMode,
              let location = lastKnownLocation,
              let address = lastKnownAddress else { return }
        onRideLog?(location, address, utteredPhrase)
    }

    private func recordSupersededAnnouncements(_ supersededAnnouncementIDs: Set<UUID>) {
        for announcementID in supersededAnnouncementIDs {
            recordDiagnostic(
                .announcementSuperseded,
                announcementID: announcementID,
                reason: .supersededByNewerContext
            )
        }
    }

    func repeatCurrentAnnouncement() {
        guard contentMode != .quiet else { return }
        guard let text = lastSpokenPhrase ?? currentLocationPhrase() else { return }
        if isSpeechOutputActive {
            stopSpeechOutput()
            return
        }

        announcementCoordinator.cancelPending()
        stopSpeechOutput()
        speak(text: text, boundary: announcementCoordinator.currentBoundary, shouldRecordTestLog: false)
    }

    private func currentLocationPhrase() -> String? {
        guard let address = lastKnownAddress else { return nil }
        let speechMode = AnnouncementPhraseBuilder.baseSpeechMode(for: contentMode)
        return AnnouncementPhraseBuilder.locationPhrase(in: address, mode: speechMode)
    }

    private func handleLocations(_ locations: [CLLocation]) {
        guard rideSessionState.isActive else { return }
        if testMode { return }

        if let location = locations.last {
            let currentTime = Date()
            let acceptedLocation = AcceptedRideLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                horizontalAccuracy: location.horizontalAccuracy,
                recordedAt: location.timestamp,
                acceptedAt: currentTime
            )
            let transition = rideSessionController.accept(acceptedLocation)
            let shouldRecordLocationSample = lastLocationDiagnosticTime.map {
                currentTime.timeIntervalSince($0) >= 10
            } ?? true
            if transition.transition != .none || shouldRecordLocationSample {
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
            reverseGeocode(location: acceptedLocation)
        }
    }

    private func handleLocationFailure(_ error: Error) {
        guard rideSessionState.isActive else { return }
        locationStatus = .locationUnavailable("Location update failed. \(ProductIdentity.displayName) will keep trying.")
        AppDiagnostics.log("Location update failed.")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startRideTrackingIfAuthorized()
    }

#if DEBUG
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        handleLocations(locations)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        handleLocationFailure(error)
    }
#endif

    private func reverseGeocode(location: AcceptedRideLocation) {
        applyPlaceResolutionEffects(rideSessionController.beginPlaceResolution(for: location).effects)
    }

    private func applyPlaceResolutionEffects(_ effects: [RidePlaceResolutionEffect]) {
        for effect in effects {
            switch effect {
            case .recordCancellation(let requestID, let reason):
                recordDiagnostic(.placeLookupCancelled, placeLookupID: requestID, reason: reason)
            case .cancelResolver:
                placeResolver.cancel()
            case .recordStart(let requestID):
                recordDiagnostic(.placeLookupStarted, placeLookupID: requestID)
            case .resolve(let request):
                placeResolver.resolve(request.location) { [weak self] result in
                    Task { @MainActor [weak self] in
                        guard let self,
                              let completion = self.rideSessionController.completePlaceResolution(
                                request,
                                result: result
                              ) else { return }
                        self.publishPlaceResolution(completion)
                    }
                }
            }
        }
    }

    private func publishPlaceResolution(_ completion: RidePlaceResolutionCompletion) {
        switch completion.result {
        case .failed:
            recordDiagnostic(.placeLookupFailed, placeLookupID: completion.requestID)
            locationStatus = .placeUnavailable("Place lookup failed. GPS is still active.")
            AppDiagnostics.log("Reverse geocoding failed.")
        case .unavailable:
            recordDiagnostic(.placeLookupFailed, placeLookupID: completion.requestID)
            locationStatus = .placeUnavailable("Place name is unavailable here.")
            AppDiagnostics.log("No placemark was returned.")
        case .resolved(let address):
            lastKnownAddress = address
            recordDiagnostic(.placeLookupFinished, placeLookupID: completion.requestID)
            AppDiagnostics.log("Resolved a place name.")
            processResolvedAddress(address, placeLookupID: completion.requestID)
        }
    }

    private func cancelActivePlaceLookup(reason: RideDiagnosticReason) {
        applyPlaceResolutionEffects(rideSessionController.cancelPlaceResolution(reason: reason))
    }

    private func canAcceptGeocodeResult(
        rideGeneration: UUID,
        requestGeneration: UUID
    ) -> Bool {
        rideSessionController.acceptsPlaceResolution(
            rideGeneration: rideGeneration,
            requestGeneration: requestGeneration
        )
    }

    func recordAnnouncementDiagnostic(_ signal: AnnouncementDiagnosticSignal) {
        recordDiagnostic(
            signal.event,
            announcementID: signal.announcementID,
            reason: signal.reason,
            audioPolicy: signal.audioPolicy,
            playbackPath: signal.playbackPath
        )
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
            recordDiagnostic(
                .audioInterruptionBegan,
                announcementID: announcementCoordinator.activePlan?.id
                    ?? announcementCoordinator.interruptedPlan?.id,
                reason: .interruptionBegan,
                interruptionReason: interruptionReason
            )
            _ = announcementCoordinator.externalAudioBegan(.interruption)
        } else if interruptionType == .ended {
            let optionsValue = (userInfo[AVAudioSessionInterruptionOptionKey] as? NSNumber)?.uintValue ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            let shouldResume = options.contains(.shouldResume)
            recordDiagnostic(
                .audioInterruptionEnded,
                announcementID: announcementCoordinator.interruptedPlan?.id,
                reason: shouldResume ? .interruptionShouldResume : .interruptionMustNotResume,
                interruptionReason: interruptionReason,
                shouldResume: shouldResume
            )
            _ = announcementCoordinator.externalAudioEnded(
                .interruption,
                shouldResume: shouldResume,
                canResume: rideSessionState == .riding
            )
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
            recordDiagnostic(
                .primaryAudioBegan,
                announcementID: announcementCoordinator.activePlan?.id
                    ?? announcementCoordinator.pending?.id
                    ?? announcementCoordinator.interruptedPlan?.id,
                reason: .primaryAudioActive
            )
            _ = announcementCoordinator.externalAudioBegan(.primaryAudio)
        case .end:
            recordDiagnostic(
                .primaryAudioEnded,
                announcementID: announcementCoordinator.interruptedPlan?.id,
                reason: .primaryAudioEnded
            )
            _ = announcementCoordinator.externalAudioEnded(
                .primaryAudio,
                shouldResume: true,
                canResume: rideSessionState == .riding
            )
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
        announcementCoordinator.handleMediaServicesReset()
        recordDiagnostic(.audioMediaServicesReset)
        _ = announcementCoordinator.resumeAfterMediaServicesReset()
    }

    private func handleAnnouncementWorkflowResult(_ result: AnnouncementWorkflowResult) {
        switch result {
        case .boundaryAccepted, .boundaryRejected:
            break
        case .announcementQueued(let plan, let placeLookupID):
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
            AppDiagnostics.log("Queued announcement after configured Bluetooth delay.")
        case .factRequested:
            announcementStatus = .retrievingContent
        case .factResolved:
            announcementStatus = .phraseReady
        case .factCancelled:
            if !isSpeechOutputActive { announcementStatus = .idle }
        case .speechRequested(let plan, _, let shouldRecordTestLog):
            AppDiagnostics.log("Speaking an announcement.")
            lastSpokenPhrase = plan.text
            lastSpokenAt = Date()
            lastSpeechDiagnosticNote = nil
            if shouldRecordTestLog { recordTestLog(utteredPhrase: plan.text) }
            announcementStatus = .preparingVoice
        case .retryScheduled, .fallbackStarted:
            announcementStatus = .preparingVoice
        case .playbackStarted:
            announcementStatus = .speaking
        case .deferred, .interrupted:
            announcementStatus = .waitingForAudio
        case .resumed:
            announcementStatus = .preparingVoice
        case .completed, .cancelled, .failed:
            announcementStatus = .idle
        }
    }

    private func speak(
        announcementID: UUID = UUID(),
        text: String,
        boundary: BoundaryType? = nil,
        shouldRecordTestLog: Bool = true,
        ignoreQuietMode: Bool = false
    ) {
        guard ignoreQuietMode || contentMode != .quiet else { return }
        let plan = AnnouncementPlan(
            id: announcementID,
            text: text,
            boundary: boundary ?? .street
        )
        announcementCoordinator.speak(plan, delivery: AnnouncementDeliveryContext(
            selectedProvider: { [weak self] in self?.speechProvider ?? .apple },
            aiSharingAllowed: aiSharingAllowed,
            appleVoice: { [weak self] in
                self?.resolveSpeechVoice().map { SpeechVoiceSelection(identifier: $0.identifier) }
            },
            allowAppleFallback: { [weak self] in self?.premiumVoiceAppleFallbackEnabled ?? false },
            audioPolicy: { [weak self] in self?.audioCoexistencePolicy ?? .mix },
            delay: 0,
            shouldRecordTestLog: shouldRecordTestLog
        ))
    }

    private func stopSpeechOutput() {
        _ = announcementCoordinator.stop(reason: .playbackCancelled)
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
        let now = Date()
        let lookupID = rideSessionController.beginPlaceResolution(for: AcceptedRideLocation(
            latitude: 0,
            longitude: 0,
            horizontalAccuracy: 0,
            recordedAt: now,
            acceptedAt: now
        )).request.requestGeneration
        recordDiagnostic(.placeLookupStarted, placeLookupID: lookupID)
        return lookupID
    }

    var hasInterruptedSpeechPlanForTesting: Bool {
        announcementCoordinator.interruptedPlan != nil
    }

    var rideSessionGenerationForTesting: UUID {
        rideSessionController.generation
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
        let acceptedLocation = AcceptedRideLocation(
            latitude: sampleLocation.coordinate.latitude,
            longitude: sampleLocation.coordinate.longitude,
            horizontalAccuracy: sampleLocation.horizontalAccuracy,
            recordedAt: sampleLocation.timestamp,
            acceptedAt: sampleDate
        )
        handleRideSessionTransition(rideSessionController.accept(acceptedLocation))
        guard rideSessionState == .riding else { return }

        lastKnownLocation = waypoint.coordinate
        currentSpeedMetersPerSecond = 0
        locationStatus = .active
        AppDiagnostics.log("Test location advanced.")

        reverseGeocode(location: acceptedLocation)
    }

    private func startTestRouteIfNeeded() {
        guard testMode, rideSessionState.isActive, !hasSeededTestRoute else { return }
        hasSeededTestRoute = true
        testIndex = 0
        advanceTestLocation()
    }
}
