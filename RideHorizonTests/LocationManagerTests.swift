import XCTest
import CoreLocation
import AVFoundation
@testable import RideHorizon

@MainActor
private final class RecordingSpeechOutputEngine: SpeechOutputEngine {
    struct Request: Equatable {
        let announcementID: UUID
        let text: String
        let provider: SpeechProvider
        let boundary: BoundaryType?
        let allowAppleFallback: Bool
    }

    var isSpeaking = false
    var isPlayingAudio = false
    var onPlaybackWillStart: ((SpeechProvider) -> Bool)?
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDiagnosticNote: ((String) -> Void)?
    var onPipelineEvent: ((SpeechOutputPipelineEvent) -> Void)?
    private(set) var requests: [Request] = []
    private(set) var cancelPendingPreparationCount = 0
    private(set) var stopCount = 0

    func speak(
        text: String,
        boundary: BoundaryType?,
        provider: SpeechProvider,
        appleVoice: AVSpeechSynthesisVoice?,
        allowAppleFallback: Bool,
        announcementID: UUID
    ) {
        onPipelineEvent?(SpeechOutputPipelineEvent(
            announcementID: announcementID,
            provider: provider,
            stage: .ttsRequested
        ))
        isSpeaking = true
        requests.append(
            Request(
                announcementID: announcementID,
                text: text,
                provider: provider,
                boundary: boundary,
                allowAppleFallback: allowAppleFallback
            )
        )
    }

    func stop() {
        let wasActive = isSpeaking
        stopCount += 1
        isSpeaking = false
        isPlayingAudio = false
        if wasActive {
            onCancel?()
        }
    }

    func cancelPendingPreparation() {
        cancelPendingPreparationCount += 1
        isSpeaking = false
        isPlayingAudio = false
        onCancel?()
    }

    func beginPlayback(provider: SpeechProvider = .proxyElevenLabs) {
        if let announcementID = requests.last?.announcementID {
            onPipelineEvent?(SpeechOutputPipelineEvent(
                announcementID: announcementID,
                provider: provider,
                stage: .speechAudioReady
            ))
        }
        guard onPlaybackWillStart?(provider) != false else {
            isSpeaking = false
            isPlayingAudio = false
            onCancel?()
            return
        }
        isPlayingAudio = true
    }

    func finishPlayback() {
        isSpeaking = false
        isPlayingAudio = false
        onFinish?()
    }
}

@MainActor
private final class RecordingAudioSessionManager: AudioSessionManaging {
    var shouldYieldToPrimaryAudio = false
    var snapshot: AudioSessionSnapshot {
        AudioSessionSnapshot(
            outputVolume: 0.5,
            outputRouteTypes: ["test"],
            isOtherAudioPlaying: false,
            shouldYieldToPrimaryAudio: shouldYieldToPrimaryAudio
        )
    }
    private(set) var activationRequests: [AudioCoexistencePolicy] = []
    private(set) var deactivationCount = 0
    private(set) var neutralizationCount = 0
    var activationFailuresRemaining = 0
    var deactivationFailuresRemaining = 0
    var neutralizationSucceeds = true

    func activate(policy: AudioCoexistencePolicy) throws {
        activationRequests.append(policy)
        if activationFailuresRemaining > 0 {
            activationFailuresRemaining -= 1
            throw TestAudioSessionError.expectedFailure
        }
    }

    func deactivate() throws {
        deactivationCount += 1
        if deactivationFailuresRemaining > 0 {
            deactivationFailuresRemaining -= 1
            throw TestAudioSessionError.expectedFailure
        }
    }

    func neutralizeAfterDeactivationFailure() -> Bool {
        neutralizationCount += 1
        return neutralizationSucceeds
    }
}

private enum TestAudioSessionError: Error {
    case expectedFailure
}

@MainActor
private final class RecordingRideInactivityNotifier: RideInactivityNotifying {
    private(set) var authorizationRequestCount = 0
    private(set) var deadlines: [Date] = []
    private(set) var cancelCount = 0

    func requestAuthorizationIfNeeded() {
        authorizationRequestCount += 1
    }

    func showInactivityPrompt(deadline: Date) {
        deadlines.append(deadline)
    }

    func cancelInactivityPrompt() {
        cancelCount += 1
    }
}

private final class RecordingAppleSpeechOutput: AppleSpeechOutputting {
    struct Request: Equatable {
        let text: String
        let boundary: BoundaryType?
        let requestID: UUID
    }

    var isSpeaking = false
    var onPlaybackWillStart: ((UUID) -> Bool)?
    var onFinish: ((UUID) -> Void)?
    var onCancel: ((UUID) -> Void)?
    private(set) var requests: [Request] = []

    func speak(text: String, boundary: BoundaryType?, voice: AVSpeechSynthesisVoice?, requestID: UUID) {
        requests.append(Request(text: text, boundary: boundary, requestID: requestID))
    }

    func stop() {
        isSpeaking = false
    }

    func emitStart(requestID: UUID) {
        isSpeaking = onPlaybackWillStart?(requestID) != false
    }

    func emitCancel(requestID: UUID) {
        isSpeaking = false
        onCancel?(requestID)
    }
}

@MainActor
private final class RecordingPremiumAudioPlayer: PremiumAudioPlaying {
    var isPlaying = false
    var onPlay: (() -> Void)?
    private(set) var playedBuffers: [AVAudioPCMBuffer] = []
    private var completion: ((Result<Void, Error>) -> Void)?

    func play(
        buffer: AVAudioPCMBuffer,
        completion: @escaping @MainActor (Result<Void, Error>) -> Void
    ) throws {
        isPlaying = true
        playedBuffers.append(buffer)
        self.completion = completion
        onPlay?()
    }

    func stop() {
        isPlaying = false
        completion = nil
    }

    func complete(_ result: Result<Void, Error> = .success(())) {
        isPlaying = false
        let completion = completion
        self.completion = nil
        completion?(result)
    }
}

private struct StubProxySpeechGenerator: ProxySpeechGenerating {
    let result: Result<[Data], Error>

    func speechAudios(for text: String) async throws -> [Data] {
        try result.get()
    }
}

private struct DelayedFailingProxySpeechGenerator: ProxySpeechGenerating {
    func speechAudios(for text: String) async throws -> [Data] {
        try await Task.sleep(nanoseconds: 100_000_000)
        throw PlaceFactError.invalidResponse
    }
}

private struct ConstantPlaceFactGenerator: PlaceFactGenerating {
    let fact: String

    func fact(for request: PlaceFactRequest) async throws -> String {
        fact
    }
}

final class LocationManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearLocationManagerDefaults()
        useLiveLocationByDefaultForTests()
        clearSpeechProviderDefaults()
        clearRiderContextDefaults()
    }

    override func tearDown() {
        super.tearDown()
        clearLocationManagerDefaults()
        clearSpeechProviderDefaults()
        clearRiderContextDefaults()
    }

    @MainActor
    func testDebugAudioInteropCampaignDefaultsToTestModeRoadAndNamesOnly() {
        UserDefaults.standard.removeObject(forKey: "RideHorizonTestMode")
        UserDefaults.standard.removeObject(forKey: "RideHorizonAudioInteropDebugTestModeChoice")
        let locationManager = LocationManager()

        XCTAssertTrue(locationManager.testMode)
        XCTAssertEqual(locationManager.rideSessionState, .idle)
        XCTAssertEqual(locationManager.locationStatus, .idle)
        XCTAssertEqual(locationManager.contentMode, .namesOnly)
        XCTAssertTrue(locationManager.announceStreet)
        XCTAssertEqual(locationManager.speechProvider, .proxyElevenLabs)
        XCTAssertTrue(locationManager.interruptsMusic)
        XCTAssertTrue(locationManager.premiumVoiceAppleFallbackEnabled)
    }

    func testPremiumSpeechPeakNormaliserAppliesBoundedGainWithoutAttenuatingLoudAudio() {
        XCTAssertEqual(SpeechAudioPeakNormaliser.gain(forPeak: 0.1), 2, accuracy: 0.001)
        XCTAssertEqual(SpeechAudioPeakNormaliser.gain(forPeak: 0.39), 2, accuracy: 0.001)
        XCTAssertEqual(SpeechAudioPeakNormaliser.gain(forPeak: 0.6), 1.324, accuracy: 0.001)
        XCTAssertEqual(SpeechAudioPeakNormaliser.gain(forPeak: 0.9), 1, accuracy: 0.001)
        XCTAssertEqual(SpeechAudioPeakNormaliser.gain(forPeak: 0), 1, accuracy: 0.001)
    }

    func testPremiumSpeechPeakNormaliserAppliesCalculatedGainToPcmSamples() throws {
        let format = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        ))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2))
        buffer.frameLength = 2
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        samples[0] = -0.39
        samples[1] = 0.1

        let gainDecibels = try SpeechAudioPeakNormaliser.apply(to: buffer)

        XCTAssertEqual(gainDecibels, 6.021, accuracy: 0.001)
        XCTAssertEqual(samples[0], -0.78, accuracy: 0.001)
        XCTAssertEqual(samples[1], 0.2, accuracy: 0.001)
    }

    func testPremiumAudioPreparerDecodesRealMP3AndNormalisesTheWholeUtterance() async throws {
        let encodedMP3 = "SUQzBAAAAAAAI1RTU0UAAAAPAAADTGF2ZjYyLjEyLjEwMAAAAAAAAAAAAAAA//tAwAAAAAAAAAAAAAAAAAAAAAAASW5mbwAAAA8AAAADAAAB7wCTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5PKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysr///////////////////////////////////////////8AAAAATGF2YzYyLjI4AAAAAAAAAAAAAAAAJAKjAAAAAAAAAe8WobKwAAAAAAD/+xDEAAAEdBNVVJCAMKYJrzcaIAIAAa05QAABWTo9UFAIBgkB8HwfB8oCAIBhEHwf1Ag7E4f4g3AEk/bAYDgcDgAAAAAAKIkqmRRkCOkCSBaj94UB8BMb8CKUL6gaEvwkDSoAAADgCf/7EsQCggUcHS+90AAgo4PmtrgABoAAAOC4IEAFJQRgMbD4SaWFOYlBOYKASCQCLJAoAmvd3f+v1EQCMMMACzE1TjAAMABw5FtzepxMYhkIDaE8vGg+yu32r8U9v/1/96Ouh4wJEa0CI//7EMQDgAVQQ0YZs4AAlwam65gwBAeHTQVwo6rgtPSMSdi31/6PNmsL3g6EnvlxsR8GgW+FSzfxUBi7C4AAAEwlCMTnmSSDUDq8kiSFKlp5KJIoKArGMKd4lulQW4lqTEFNRTMuMTAw"
        let mp3 = try XCTUnwrap(Data(base64Encoded: encodedMP3))

        let prepared = try await PremiumAudioPreparer.prepare(dataSegments: [mp3, mp3])

        XCTAssertEqual(prepared.buffers.count, 2)
        XCTAssertGreaterThan(prepared.buffers[0].frameLength, 0)
        XCTAssertGreaterThanOrEqual(prepared.gainDecibels, 0)
        let firstPeak = try SpeechAudioPeakNormaliser.peak(in: prepared.buffers[0])
        let secondPeak = try SpeechAudioPeakNormaliser.peak(in: prepared.buffers[1])
        XCTAssertEqual(firstPeak, secondPeak, accuracy: 0.001)
        XCTAssertLessThanOrEqual(firstPeak, SpeechAudioPeakNormaliser.targetPeak + 0.001)
    }

    @MainActor
    func testPremiumAudioCompletionReleasesTheOwnedSession() async throws {
        let encodedMP3 = "SUQzBAAAAAAAI1RTU0UAAAAPAAADTGF2ZjYyLjEyLjEwMAAAAAAAAAAAAAAA//tAwAAAAAAAAAAAAAAAAAAAAAAASW5mbwAAAA8AAAADAAAB7wCTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5PKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysr///////////////////////////////////////////8AAAAATGF2YzYyLjI4AAAAAAAAAAAAAAAAJAKjAAAAAAAAAe8WobKwAAAAAAD/+xDEAAAEdBNVVJCAMKYJrzcaIAIAAa05QAABWTo9UFAIBgkB8HwfB8oCAIBhEHwf1Ag7E4f4g3AEk/bAYDgcDgAAAAAAKIkqmRRkCOkCSBaj94UB8BMb8CKUL6gaEvwkDSoAAADgCf/7EsQCggUcHS+90AAgo4PmtrgABoAAAOC4IEAFJQRgMbD4SaWFOYlBOYKASCQCLJAoAmvd3f+v1EQCMMMACzE1TjAAMABw5FtzepxMYhkIDaE8vGg+yu32r8U9v/1/96Ouh4wJEa0CI//7EMQDgAVQQ0YZs4AAlwam65gwBAeHTQVwo6rgtPSMSdi31/6PNmsL3g6EnvlxsR8GgW+FSzfxUBi7C4AAAEwlCMTnmSSDUDq8kiSFKlp5KJIoKArGMKd4lulQW4lqTEFNRTMuMTAw"
        let mp3 = try XCTUnwrap(Data(base64Encoded: encodedMP3))
        let premiumPlayer = RecordingPremiumAudioPlayer()
        let started = expectation(description: "Premium playback starts")
        premiumPlayer.onPlay = { started.fulfill() }
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: StubProxySpeechGenerator(result: .success([mp3])),
            appleSpeechOutput: RecordingAppleSpeechOutput(),
            proxyAudioPlayer: premiumPlayer
        )
        let audioSession = RecordingAudioSessionManager()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            inactivityNotifier: RecordingRideInactivityNotifier(),
            audioSession: audioSession,
            aiSharingAllowed: { true }
        )
        locationManager.testMode = true
        locationManager.speechProvider = .proxyElevenLabs
        locationManager.premiumVoiceAppleFallbackEnabled = false
        locationManager.startRideWithoutLocationInputForTesting()

        locationManager.speakForTesting(text: "Test", boundary: .town)
        await fulfillment(of: [started], timeout: 1)
        XCTAssertEqual(audioSession.activationRequests, [.interrupt])

        premiumPlayer.complete()

        XCTAssertEqual(audioSession.deactivationCount, 1)
        XCTAssertEqual(locationManager.announcementStatus, .idle)
    }

    @MainActor
    func testAudioSessionIsOwnedOnlyWhileSpeechIsActuallyPlaying() {
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            audioSession: audioSession,
            aiSharingAllowed: { true }
        )

        XCTAssertTrue(audioSession.activationRequests.isEmpty)
        XCTAssertEqual(audioSession.deactivationCount, 0)

        locationManager.speakForTesting(text: "Test announcement", boundary: .town)

        XCTAssertTrue(audioSession.activationRequests.isEmpty)

        speechOutput.beginPlayback()

        XCTAssertEqual(audioSession.activationRequests, [.interrupt])

        speechOutput.finishPlayback()

        XCTAssertEqual(audioSession.deactivationCount, 1)
    }

    @MainActor
    func testInterruptMusicSettingUsesNonMixingAudioPolicy() {
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            audioSession: audioSession,
            aiSharingAllowed: { true }
        )
        locationManager.interruptsMusic = true

        locationManager.speakForTesting(text: "Test announcement", boundary: .town)
        speechOutput.beginPlayback()

        XCTAssertEqual(audioSession.activationRequests, [.interrupt])
    }

    @MainActor
    func testDisabledMusicInterruptionUsesMixingAudioPolicy() {
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            audioSession: audioSession,
            aiSharingAllowed: { true }
        )
        locationManager.interruptsMusic = false

        locationManager.speakForTesting(text: "Test announcement", boundary: .town)
        speechOutput.beginPlayback()

        XCTAssertEqual(audioSession.activationRequests, [.mix])
    }

    @MainActor
    func testMixPolicyDoesNotDelayForPrimaryAudioHint() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        audioSession.shouldYieldToPrimaryAudio = true
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            inactivityNotifier: RecordingRideInactivityNotifier(),
            audioSession: audioSession,
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.interruptsMusic = false
        locationManager.startRide()

        locationManager.speakForTesting(text: "Welcome to England.", boundary: .nation)

        XCTAssertEqual(speechOutput.requests.map(\.text), ["Welcome to England."])
        XCTAssertEqual(locationManager.announcementStatus, .preparingVoice)
        let events = diagnostics.entries.filter { $0.announcementID != nil }
        XCTAssertEqual(Set(events.compactMap(\.announcementID)).count, 1)
        XCTAssertEqual(events.map(\.event), [.ttsRequested])
    }

    @MainActor
    func testInterruptPolicyDoesNotDelayForPrimaryAudio() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        audioSession.shouldYieldToPrimaryAudio = true
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            inactivityNotifier: RecordingRideInactivityNotifier(),
            audioSession: audioSession,
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.testMode = true
        locationManager.interruptsMusic = true
        locationManager.startRideWithoutLocationInputForTesting()

        locationManager.speakForTesting(text: "Welcome to England.", boundary: .nation)

        XCTAssertEqual(speechOutput.requests.map(\.text), ["Welcome to England."])
        XCTAssertEqual(locationManager.announcementStatus, .preparingVoice)
        XCTAssertFalse(diagnostics.entries.contains { $0.event == .announcementDeferred })
        XCTAssertFalse(diagnostics.entries.contains { $0.event == .announcementRestarted })
    }

    @MainActor
    func testLiveModeInterruptPolicyDoesNotDelayForPrimaryAudioHint() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        audioSession.shouldYieldToPrimaryAudio = true
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            inactivityNotifier: RecordingRideInactivityNotifier(),
            audioSession: audioSession,
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.testMode = false
        locationManager.interruptsMusic = true
        locationManager.startRideWithoutLocationInputForTesting()

        locationManager.speakForTesting(text: "Welcome to England.", boundary: .nation)

        XCTAssertEqual(speechOutput.requests.map(\.text), ["Welcome to England."])
        XCTAssertEqual(locationManager.announcementStatus, .preparingVoice)
        XCTAssertFalse(diagnostics.entries.contains { $0.event == .announcementDeferred })
    }

    @MainActor
    func testEndRideCancelsInterruptedSpeechWithoutLateRestart() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            inactivityNotifier: RecordingRideInactivityNotifier(),
            audioSession: audioSession,
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.startRideWithoutLocationInputForTesting()
        locationManager.speakForTesting(text: "Welcome to England.", boundary: .nation)
        speechOutput.beginPlayback()
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        locationManager.endRide()
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
            ]
        )

        XCTAssertEqual(speechOutput.requests.map(\.text), ["Welcome to England."])
        XCTAssertEqual(locationManager.announcementStatus, .idle)
        XCTAssertTrue(
            diagnostics.entries.contains {
                $0.event == .announcementCancelled && $0.reason == .rideEnded
            }
        )
    }

    @MainActor
    func testNewSamePriorityBoundaryStopsActiveSpeechBeforeReplacement() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            inactivityNotifier: RecordingRideInactivityNotifier(),
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.contentMode = .namesOnly
        locationManager.boundarySpeechCooldownSeconds = 0
        locationManager.bluetoothDelaySeconds = 0

        locationManager.processResolvedAddressForTesting(Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Bristol Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(speechOutput.requests.map(\.text), ["Stonehouse, Gloucestershire"])
        speechOutput.beginPlayback()
        locationManager.processResolvedAddressForTesting(Address(
            street: "Long Street",
            town: "Dursley",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(speechOutput.stopCount, 1)
        XCTAssertEqual(speechOutput.requests.map(\.text), ["Stonehouse, Gloucestershire", "Dursley, Gloucestershire"])
        XCTAssertTrue(
            diagnostics.entries.contains {
                $0.event == .announcementSuperseded && $0.reason == .supersededByNewerContext
            }
        )
    }

    @MainActor
    func testGenuineAudioInterruptionDoesNotForceSpeechToResumeBeforeItEnds() async {
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            inactivityNotifier: RecordingRideInactivityNotifier(),
            audioSession: audioSession,
            aiSharingAllowed: { true }
        )
        locationManager.startRideWithoutLocationInputForTesting()
        locationManager.speakForTesting(text: "Welcome to England.", boundary: .nation)
        speechOutput.beginPlayback()

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(speechOutput.requests.map(\.text), ["Welcome to England."])
        XCTAssertEqual(locationManager.announcementStatus, .waitingForAudio)
        XCTAssertTrue(locationManager.hasInterruptedSpeechPlanForTesting)
    }

    @MainActor
    func testResumableInterruptionRestartsSameAnnouncementImmediatelyAndOnlyOnce() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            inactivityNotifier: RecordingRideInactivityNotifier(),
            audioSession: audioSession,
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.startRideWithoutLocationInputForTesting()
        locationManager.speakForTesting(text: "Welcome to England.", boundary: .nation)
        speechOutput.beginPlayback()

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        let resumableEnd: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: resumableEnd
        )
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: resumableEnd
        )
        XCTAssertEqual(speechOutput.requests.map(\.text), ["Welcome to England.", "Welcome to England."])
        XCTAssertEqual(Set(speechOutput.requests.map(\.announcementID)).count, 1)
        XCTAssertEqual(
            diagnostics.entries.filter { $0.event == .announcementRestarted }.count,
            1
        )
        XCTAssertTrue(
            diagnostics.entries.contains {
                $0.event == .audioInterruptionEnded && $0.shouldResume == true
            }
        )
    }

    @MainActor
    func testOverlappingAudioPauseReasonsRestartOnlyAfterBothEnd() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            inactivityNotifier: RecordingRideInactivityNotifier(),
            audioSession: RecordingAudioSessionManager(),
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.startRideWithoutLocationInputForTesting()
        locationManager.speakForTesting(text: "Welcome to England.", boundary: .nation)
        speechOutput.beginPlayback()

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        NotificationCenter.default.post(
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionSilenceSecondaryAudioHintTypeKey:
                    AVAudioSession.SilenceSecondaryAudioHintType.begin.rawValue
            ]
        )
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
            ]
        )

        XCTAssertEqual(speechOutput.requests.map(\.text), ["Welcome to England."])
        XCTAssertEqual(locationManager.announcementStatus, .waitingForAudio)
        XCTAssertEqual(
            diagnostics.entries.first { $0.event == .primaryAudioBegan }?.announcementID,
            speechOutput.requests.first?.announcementID
        )

        NotificationCenter.default.post(
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionSilenceSecondaryAudioHintTypeKey:
                    AVAudioSession.SilenceSecondaryAudioHintType.end.rawValue
            ]
        )

        XCTAssertEqual(
            speechOutput.requests.map(\.text),
            ["Welcome to England.", "Welcome to England."]
        )
    }

    @MainActor
    func testAnnouncementWaitsForObservedAudioPauseIntervalButNotPreflightHint() {
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            inactivityNotifier: RecordingRideInactivityNotifier(),
            audioSession: RecordingAudioSessionManager(),
            aiSharingAllowed: { true }
        )
        locationManager.startRideWithoutLocationInputForTesting()
        NotificationCenter.default.post(
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionSilenceSecondaryAudioHintTypeKey:
                    AVAudioSession.SilenceSecondaryAudioHintType.begin.rawValue
            ]
        )

        locationManager.speakForTesting(text: "Welcome to England.", boundary: .nation)

        XCTAssertTrue(speechOutput.requests.isEmpty)
        XCTAssertEqual(locationManager.announcementStatus, .waitingForAudio)

        NotificationCenter.default.post(
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionSilenceSecondaryAudioHintTypeKey:
                    AVAudioSession.SilenceSecondaryAudioHintType.end.rawValue
            ]
        )

        XCTAssertEqual(speechOutput.requests.map(\.text), ["Welcome to England."])
    }

    @MainActor
    func testFactPipelineReportsContentAndPhrasePreparationStates() async {
        let factGenerator = MockPlaceFactGenerator()
        factGenerator.delayNanoseconds = 50_000_000
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let locationManager = LocationManager(
            factGenerator: factGenerator,
            speechOutput: RecordingSpeechOutputEngine(),
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.contentMode = .shortFacts
        locationManager.boundarySpeechCooldownSeconds = 0
        locationManager.bluetoothDelaySeconds = 1

        locationManager.processResolvedAddressForTesting(Address(
            street: "High Street",
            town: "Chester",
            county: "Cheshire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "High Street",
            town: "Chepstow",
            county: "Monmouthshire",
            administrativeArea: "Wales",
            country: "United Kingdom"
        ))

        XCTAssertEqual(locationManager.announcementStatus, .retrievingContent)
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(locationManager.announcementStatus, .phraseReady)
        let pipeline = diagnostics.entries.filter {
            [
                RideDiagnosticEvent.factGenerationStarted,
                .factGenerationFinished,
                .announcementTextReady,
                .announcementQueued
            ].contains($0.event)
        }
        XCTAssertEqual(
            pipeline.map(\.event),
            [.factGenerationStarted, .factGenerationFinished, .announcementTextReady, .announcementQueued]
        )
        XCTAssertEqual(Set(pipeline.compactMap(\.announcementID)).count, 1)
    }

    @MainActor
    func testFactAnnouncementExportCarriesOneIDFromGenerationThroughAudioRelease() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        let locationManager = LocationManager(
            factGenerator: ConstantPlaceFactGenerator(fact: "Known for its wool trade."),
            speechOutput: speechOutput,
            audioSession: audioSession,
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.contentMode = .shortFacts
        locationManager.boundarySpeechCooldownSeconds = 0
        locationManager.bluetoothDelaySeconds = 0
        locationManager.processResolvedAddressForTesting(Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Bristol Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(speechOutput.requests.count, 1)

        speechOutput.beginPlayback()
        speechOutput.finishPlayback()

        let expected: [RideDiagnosticEvent] = [
            .factGenerationStarted,
            .factGenerationFinished,
            .announcementTextReady,
            .announcementQueued,
            .ttsRequested,
            .speechAudioReady,
            .audioSessionActivated,
            .audioPlaybackStarted,
            .audioPlaybackFinished,
            .audioSessionReleased
        ]
        let correlated = diagnostics.entries.filter { expected.contains($0.event) }
        XCTAssertEqual(correlated.map(\.event), expected)
        XCTAssertEqual(Set(correlated.compactMap(\.announcementID)).count, 1)

        diagnostics.flushForTesting()
        let export = String(data: try Data(contentsOf: diagnostics.exportURL), encoding: .utf8) ?? ""
        XCTAssertFalse(export.contains("Known for its wool trade."))
        XCTAssertFalse(export.contains("Stonehouse"))
        XCTAssertFalse(export.contains("51."))
    }

    @MainActor
    func testPlaybackDiagnosticChainIsOrderedAndCorrelatedThroughRelease() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            audioSession: audioSession,
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.startRide()

        locationManager.speakForTesting(text: "Private test announcement", boundary: .town)
        speechOutput.beginPlayback()
        speechOutput.finishPlayback()

        let pipeline = diagnostics.entries.filter { $0.announcementID != nil }
        XCTAssertEqual(
            pipeline.map(\.event),
            [
                .ttsRequested,
                .speechAudioReady,
                .audioSessionActivated,
                .audioPlaybackStarted,
                .audioPlaybackFinished,
                .audioSessionReleased
            ]
        )
        XCTAssertEqual(Set(pipeline.compactMap(\.announcementID)).count, 1)
        XCTAssertEqual(pipeline.map(\.sequenceNumber), pipeline.map(\.sequenceNumber).sorted { ($0 ?? 0) < ($1 ?? 0) })
        XCTAssertTrue(pipeline.allSatisfy { $0.audioPolicy == .interrupt || $0.audioPolicy == nil })
        diagnostics.flushForTesting()
        let export = String(data: try! Data(contentsOf: diagnostics.exportURL), encoding: .utf8) ?? ""
        XCTAssertFalse(export.contains("Private test announcement"))
    }

    @MainActor
    func testStoppingSpeechReleasesOwnedAudioSession() {
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            audioSession: audioSession,
            aiSharingAllowed: { true }
        )

        locationManager.speakForTesting(text: "Test announcement", boundary: .town)
        speechOutput.beginPlayback()
        locationManager.endRide()

        XCTAssertEqual(audioSession.activationRequests, [.interrupt])
        XCTAssertEqual(audioSession.deactivationCount, 1)
    }

    @MainActor
    func testAudioActivationFailureDoesNotCreateFalseOwnership() {
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        audioSession.activationFailuresRemaining = 1
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            audioSession: audioSession,
            aiSharingAllowed: { true }
        )

        locationManager.speakForTesting(text: "Test announcement", boundary: .town)
        speechOutput.beginPlayback()
        speechOutput.finishPlayback()

        XCTAssertEqual(audioSession.activationRequests, [.interrupt])
        XCTAssertEqual(audioSession.deactivationCount, 0)
        XCTAssertFalse(speechOutput.isSpeaking)
    }

    @MainActor
    func testAudioDeactivationFailureIsRetriedUntilReleased() async {
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        audioSession.deactivationFailuresRemaining = 1
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            audioSession: audioSession,
            aiSharingAllowed: { true }
        )

        locationManager.speakForTesting(text: "Test announcement", boundary: .town)
        speechOutput.beginPlayback()
        speechOutput.finishPlayback()
        try? await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertEqual(audioSession.activationRequests, [.interrupt])
        XCTAssertEqual(audioSession.deactivationCount, 2)
    }

    @MainActor
    func testRepeatedAudioDeactivationFailureFallsBackToMixingNeutralization() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        audioSession.deactivationFailuresRemaining = 3
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            audioSession: audioSession,
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )

        locationManager.speakForTesting(text: "Test announcement", boundary: .town)
        speechOutput.beginPlayback()
        speechOutput.finishPlayback()
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        XCTAssertEqual(audioSession.deactivationCount, 3)
        XCTAssertEqual(audioSession.neutralizationCount, 1)
        XCTAssertTrue(
            diagnostics.entries.contains {
                $0.event == .audioSessionNeutralized && $0.audioPolicy == .mix
            }
        )
    }

    @MainActor
    func testNewPlaybackCancelsPendingAudioDeactivationRetry() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        audioSession.deactivationFailuresRemaining = 1
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            audioSession: audioSession,
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )

        locationManager.speakForTesting(text: "First announcement", boundary: .town)
        speechOutput.beginPlayback()
        speechOutput.finishPlayback()
        locationManager.speakForTesting(text: "Second announcement", boundary: .county)
        speechOutput.beginPlayback()
        try? await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertEqual(audioSession.deactivationCount, 1)
        XCTAssertEqual(
            diagnostics.entries.filter { $0.event == .audioPlaybackStarted }.count,
            2
        )

        speechOutput.finishPlayback()
        XCTAssertEqual(audioSession.deactivationCount, 2)
    }

    @MainActor
    func testEndRideCleanupIsIdempotent() {
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            audioSession: audioSession,
            aiSharingAllowed: { true }
        )
        locationManager.startRide()
        locationManager.speakForTesting(text: "Test announcement", boundary: .town)
        speechOutput.beginPlayback()

        locationManager.endRide()
        locationManager.endRide()

        XCTAssertEqual(locationManager.rideSessionState, .idle)
        XCTAssertEqual(audioSession.deactivationCount, 1)
    }

    @MainActor
    func testNonResumableAudioInterruptionReleasesSessionAndDiscardsSpeech() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let speechOutput = RecordingSpeechOutputEngine()
        let audioSession = RecordingAudioSessionManager()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            audioSession: audioSession,
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.startRideWithoutLocationInputForTesting()
        locationManager.speakForTesting(text: "Test announcement", boundary: .town)
        speechOutput.beginPlayback()

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        XCTAssertEqual(audioSession.deactivationCount, 1)
        XCTAssertTrue(locationManager.hasInterruptedSpeechPlanForTesting)

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: UInt(0)
            ]
        )

        XCTAssertFalse(locationManager.hasInterruptedSpeechPlanForTesting)
        XCTAssertEqual(locationManager.announcementStatus, .idle)
        XCTAssertTrue(diagnostics.entries.map(\.event).contains(.audioInterruptionBegan))
        XCTAssertTrue(diagnostics.entries.map(\.event).contains(.audioInterruptionEnded))
        XCTAssertTrue(
            diagnostics.entries.contains {
                $0.event == .announcementCancelled && $0.reason == .interruptionMustNotResume
            }
        )
        locationManager.endRide()
    }

    @MainActor
    func testRouteChangeAndMediaResetAreCapturedWithoutRetainingAudioOwnership() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let locationManager = LocationManager(diagnostics: diagnostics)
        XCTAssertEqual(locationManager.rideSessionState, .idle)

        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance()
        )

        XCTAssertTrue(diagnostics.entries.map(\.event).contains(.audioRouteChanged))
        XCTAssertTrue(diagnostics.entries.map(\.event).contains(.audioMediaServicesReset))
    }

    @MainActor
    func testMediaServicesResetRestartsInterruptedAnnouncementImmediately() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            inactivityNotifier: RecordingRideInactivityNotifier(),
            audioSession: RecordingAudioSessionManager(),
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.startRideWithoutLocationInputForTesting()
        locationManager.speakForTesting(text: "Welcome to England.", boundary: .nation)
        speechOutput.beginPlayback()
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        NotificationCenter.default.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance()
        )

        XCTAssertEqual(
            speechOutput.requests.map(\.text),
            ["Welcome to England.", "Welcome to England."]
        )
        XCTAssertEqual(locationManager.announcementStatus, .preparingVoice)
        XCTAssertTrue(
            diagnostics.entries.contains {
                $0.event == .announcementRestarted && $0.reason == .mediaServicesReset
            }
        )
    }

    @MainActor
    func testReleaseDiagnosticsArePersistedAndBoundedByAgeAndCount() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let now = Date(timeIntervalSince1970: 1_000_000)
        let store = RideDiagnosticsStore(
            directoryURL: directory,
            now: { now },
            maxEntries: 2,
            maxAge: 7 * 24 * 60 * 60,
            maxBytes: 1_048_576
        )

        store.record(.rideStarted, at: now.addingTimeInterval(-8 * 24 * 60 * 60))
        store.record(.audioPlaybackStarted, at: now.addingTimeInterval(-2))
        store.record(.audioSessionActivated, at: now.addingTimeInterval(-1))
        store.record(.audioSessionReleased, at: now)
        store.flushForTesting()

        XCTAssertEqual(store.entries.map(\.event), [.audioSessionActivated, .audioSessionReleased])
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.exportURL.path))

        let restored = RideDiagnosticsStore(
            directoryURL: directory,
            now: { now },
            maxEntries: 2,
            maxAge: 7 * 24 * 60 * 60,
            maxBytes: 1_048_576
        )
        XCTAssertEqual(restored.entries.map(\.event), [.audioSessionActivated, .audioSessionReleased])

        restored.clear()
        XCTAssertTrue(restored.entries.isEmpty)
    }

    @MainActor
    func testReleaseDiagnosticsAttachPrivacySafeNetworkPathSnapshot() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let expected = NetworkPathSnapshot(
            status: .satisfied,
            interfaceTypes: [.cellular],
            isExpensive: true,
            isConstrained: false,
            linkQuality: .moderate
        )
        let store = RideDiagnosticsStore(
            directoryURL: directory,
            networkSnapshotProvider: { expected }
        )

        store.record(.ttsRequested, playbackPath: .premiumVoice)
        store.record(.announcementFailed, playbackPath: .premiumVoice)

        store.record(.rideStarted)

        XCTAssertEqual(store.entries.first?.network, expected)
        XCTAssertEqual(store.entries.dropFirst().first?.network, expected)
        XCTAssertNil(store.entries.last?.network)
    }

    @MainActor
    func testPremiumVoiceFailureCarriesResultNetworkSnapshot() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let expected = NetworkPathSnapshot(
            status: .satisfied,
            interfaceTypes: [.cellular],
            isExpensive: true,
            isConstrained: false,
            linkQuality: .minimal
        )
        let diagnostics = RideDiagnosticsStore(
            directoryURL: directory,
            networkSnapshotProvider: { expected }
        )
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.speechProvider = .proxyElevenLabs
        locationManager.speakForTesting(text: "Welcome to England.", boundary: .nation)

        speechOutput.onDiagnosticNote?("Premium voice failed for test.")

        let failure = diagnostics.entries.last { $0.event == .announcementFailed }
        XCTAssertEqual(failure?.playbackPath, .premiumVoice)
        XCTAssertEqual(failure?.network, expected)
    }

    @MainActor
    func testDiagnosticEntriesHaveStableSessionAndMonotonicSequence() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = RideDiagnosticsStore(directoryURL: directory)

        store.record(.rideStarted)
        store.record(.announcementTextReady)
        store.record(.ttsRequested)

        XCTAssertEqual(store.entries.compactMap(\.sequenceNumber), [1, 2, 3])
        XCTAssertEqual(Set(store.entries.compactMap(\.diagnosticSessionID)).count, 1)
    }

    @MainActor
    func testDiagnosticsPersistSubsecondTimingAndRestoreLegacyIso8601Timestamps() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let timestamp = Date(timeIntervalSince1970: 1_000_000.125)
        let store = RideDiagnosticsStore(directoryURL: directory, now: { timestamp })
        store.record(.ttsRequested, at: timestamp)
        store.flushForTesting()

        let export = try String(contentsOf: store.exportURL, encoding: .utf8)
        XCTAssertTrue(export.contains(".125Z"))

        let legacyEncoder = JSONEncoder()
        legacyEncoder.dateEncodingStrategy = .iso8601
        try legacyEncoder.encode(store.entries).write(to: store.exportURL, options: .atomic)

        let restored = RideDiagnosticsStore(directoryURL: directory, now: { timestamp })
        XCTAssertEqual(restored.entries.map(\.event), [.ttsRequested])
        let restoredTimestamp = try XCTUnwrap(restored.entries.first?.timestamp)
        XCTAssertEqual(restoredTimestamp.timeIntervalSince1970, 1_000_000, accuracy: 0.001)
    }

    @MainActor
    func testClearWaitsForInFlightPersistenceBeforeWritingEmptySnapshot() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let writerStarted = DispatchSemaphore(value: 0)
        let releaseWriter = DispatchSemaphore(value: 0)
        let store = RideDiagnosticsStore(
            directoryURL: directory,
            persistenceDelay: 0,
            persistenceWillWrite: { snapshot in
                guard !snapshot.isEmpty else { return }
                writerStarted.signal()
                _ = releaseWriter.wait(timeout: .now() + 2)
            }
        )

        store.record(.appEnteredBackground)
        XCTAssertEqual(writerStarted.wait(timeout: .now() + 1), .success)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            releaseWriter.signal()
        }

        store.clear()

        let persisted = try JSONDecoder().decode(
            [RideDiagnosticEntry].self,
            from: Data(contentsOf: store.exportURL)
        )
        XCTAssertTrue(persisted.isEmpty)
    }

    @MainActor
    func testReleaseDiagnosticsStayWithinByteLimitAndAreExcludedFromBackup() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = RideDiagnosticsStore(
            directoryURL: directory,
            maxEntries: 2_000,
            maxBytes: 1_024
        )

        for _ in 0..<100 {
            store.record(
                .audioPlaybackStarted,
                audio: AudioSessionSnapshot(
                    outputVolume: 0.5,
                    outputRouteTypes: ["BluetoothA2DPOutput"],
                    isOtherAudioPlaying: true,
                    shouldYieldToPrimaryAudio: false,
                    category: "playback",
                    mode: "spokenAudio",
                    options: ["duckOthers"]
                ),
                audioPolicy: .duck
            )
        }
        store.flushForTesting()

        let data = try Data(contentsOf: store.exportURL)
        XCTAssertLessThanOrEqual(data.count, 1_024)
        XCTAssertEqual(
            try store.exportURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup,
            true
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: store.exportURL.path)
        XCTAssertEqual(
            attributes[.protectionKey] as? FileProtectionType,
            .completeUntilFirstUserAuthentication
        )
    }

    @MainActor
    func testRideStartsOnlyAfterExplicitActionAndManualEndCleansUp() {
        let notifier = RecordingRideInactivityNotifier()
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            speechOutput: speechOutput,
            inactivityNotifier: notifier
        )
        let startedAt = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(locationManager.rideSessionState, .idle)
        XCTAssertEqual(notifier.authorizationRequestCount, 0)

        locationManager.startRide(at: startedAt)

        XCTAssertEqual(locationManager.rideSessionState, .riding)
        XCTAssertEqual(notifier.authorizationRequestCount, 1)

        locationManager.endRide()

        XCTAssertEqual(locationManager.rideSessionState, .idle)
        XCTAssertEqual(locationManager.locationStatus, .idle)
        XCTAssertFalse(locationManager.isTracking)
        XCTAssertEqual(notifier.cancelCount, 1)
        XCTAssertEqual(speechOutput.stopCount, 1)
    }

    @MainActor
    func testEndRideInvalidatesPendingGeocodeResults() {
        let locationManager = LocationManager(inactivityNotifier: RecordingRideInactivityNotifier())
        locationManager.startRide()
        let rideGeneration = locationManager.rideSessionGenerationForTesting
        let requestGeneration = locationManager.geocodeRequestGenerationForTesting
        XCTAssertTrue(
            locationManager.canAcceptGeocodeResultForTesting(
                rideGeneration: rideGeneration,
                requestGeneration: requestGeneration
            )
        )

        locationManager.endRide()

        XCTAssertFalse(
            locationManager.canAcceptGeocodeResultForTesting(
                rideGeneration: rideGeneration,
                requestGeneration: requestGeneration
            )
        )
        XCTAssertEqual(locationManager.locationStatus, .idle)
    }

    @MainActor
    func testInactivityPromptInvalidatesPendingGeocodeAcrossContinue() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let locationManager = LocationManager(
            inactivityNotifier: RecordingRideInactivityNotifier(),
            diagnostics: diagnostics
        )
        let startedAt = Date(timeIntervalSince1970: 1_000)
        locationManager.startRideWithoutLocationInputForTesting(at: startedAt)
        let rideGeneration = locationManager.rideSessionGenerationForTesting
        let requestGeneration = locationManager.beginPlaceLookupDiagnosticForTesting()

        locationManager.evaluateRideSession(at: startedAt.addingTimeInterval(600))
        locationManager.continueRide(at: startedAt.addingTimeInterval(660))

        XCTAssertFalse(
            locationManager.canAcceptGeocodeResultForTesting(
                rideGeneration: rideGeneration,
                requestGeneration: requestGeneration
            )
        )
        XCTAssertEqual(locationManager.rideSessionState, .riding)
        XCTAssertTrue(
            diagnostics.entries.contains {
                $0.event == .placeLookupCancelled
                    && $0.placeLookupID == requestGeneration
                    && $0.reason == .inactivityPrompted
            }
        )
    }

    @MainActor
    func testInactivityPromptCanContinueOrAutomaticallyEndTheRide() {
        let notifier = RecordingRideInactivityNotifier()
        let locationManager = LocationManager(inactivityNotifier: notifier)
        let startedAt = Date(timeIntervalSince1970: 1_000)
        locationManager.startRide(at: startedAt)

        locationManager.evaluateRideSession(at: startedAt.addingTimeInterval(600))

        XCTAssertEqual(
            locationManager.rideSessionState,
            .awaitingConfirmation(deadline: startedAt.addingTimeInterval(720))
        )
        XCTAssertEqual(notifier.deadlines, [startedAt.addingTimeInterval(720)])

        locationManager.continueRide(at: startedAt.addingTimeInterval(660))
        XCTAssertEqual(locationManager.rideSessionState, .riding)

        locationManager.evaluateRideSession(at: startedAt.addingTimeInterval(1_260))
        locationManager.evaluateRideSession(at: startedAt.addingTimeInterval(1_380))

        XCTAssertEqual(locationManager.rideSessionState, .idle)
        XCTAssertEqual(locationManager.locationStatus, .idle)
    }

    @MainActor
    func testExpiredInactivityPromptCannotContinueTheRide() {
        let locationManager = LocationManager(inactivityNotifier: RecordingRideInactivityNotifier())
        let startedAt = Date(timeIntervalSince1970: 1_000)
        locationManager.startRide(at: startedAt)
        locationManager.evaluateRideSession(at: startedAt.addingTimeInterval(600))

        locationManager.continueRide(at: startedAt.addingTimeInterval(721))

        XCTAssertEqual(locationManager.rideSessionState, .idle)
        XCTAssertEqual(locationManager.locationStatus, .idle)
        XCTAssertFalse(locationManager.isTracking)
    }

    @MainActor
    func testTestModeDoesNotSeedUntilRideStarts() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let locationManager = LocationManager(
            inactivityNotifier: RecordingRideInactivityNotifier(),
            diagnostics: diagnostics
        )
        locationManager.testMode = true

        XCTAssertNil(locationManager.lastKnownLocation)

        locationManager.startRide()

        XCTAssertEqual(locationManager.rideSessionState, .riding)
        XCTAssertEqual(
            locationManager.lastKnownLocation?.latitude,
            TestRouteFixture.waypoints[0].latitude
        )
        let lookupStart = diagnostics.entries.first { $0.event == .placeLookupStarted }
        XCTAssertNotNil(lookupStart?.placeLookupID)
        locationManager.endRide()
    }

    @MainActor
    func testAnnouncementTextReadyRetainsItsPlaceLookupCorrelation() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let locationManager = LocationManager(
            speechOutput: RecordingSpeechOutputEngine(),
            diagnostics: diagnostics,
            aiSharingAllowed: { true }
        )
        locationManager.contentMode = .namesOnly
        locationManager.boundarySpeechCooldownSeconds = 0
        locationManager.bluetoothDelaySeconds = 10
        let lookupID = UUID()

        locationManager.processResolvedAddressForTesting(Address(
            street: "High Street",
            town: "Chester",
            county: "Cheshire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(
            Address(
                street: "High Street",
                town: "Chepstow",
                county: "Monmouthshire",
                administrativeArea: "Wales",
                country: "United Kingdom"
            ),
            placeLookupID: lookupID
        )

        let textReady = diagnostics.entries.first {
            $0.event == .announcementTextReady && $0.placeLookupID == lookupID
        }
        XCTAssertNotNil(textReady?.announcementID)
    }

    @MainActor
    func testSupersededPlaceLookupGetsATerminalDiagnostic() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let locationManager = LocationManager(
            inactivityNotifier: RecordingRideInactivityNotifier(),
            diagnostics: diagnostics
        )
        locationManager.testMode = true
        locationManager.startRide()
        let firstLookupID = diagnostics.entries.first {
            $0.event == .placeLookupStarted
        }?.placeLookupID

        locationManager.advanceTestLocation()

        XCTAssertNotNil(firstLookupID)
        XCTAssertTrue(
            diagnostics.entries.contains {
                $0.event == .placeLookupCancelled
                    && $0.placeLookupID == firstLookupID
                    && $0.reason == .supersededByNewerContext
            }
        )
        locationManager.endRide()
    }

    @MainActor
    func testSecondTestModeRideRestartsAtFirstPoint() {
        let locationManager = LocationManager(inactivityNotifier: RecordingRideInactivityNotifier())
        locationManager.testMode = true
        locationManager.startRide()
        locationManager.advanceTestLocation()
        XCTAssertEqual(locationManager.lastKnownLocation?.latitude, TestRouteFixture.waypoints[1].latitude)

        locationManager.endRide()
        locationManager.startRide()

        XCTAssertEqual(locationManager.lastKnownLocation?.latitude, TestRouteFixture.waypoints[0].latitude)
        locationManager.endRide()
    }

    @MainActor
    func testExplicitTestModeChoicePersists() {
        let locationManager = LocationManager()
        locationManager.testMode = true

        let restoredLocationManager = LocationManager()

        XCTAssertTrue(restoredLocationManager.testMode)
    }

    @MainActor
    func testExplicitTestModeOffChoicePersistsDuringDebugCampaign() {
        let locationManager = LocationManager()
        locationManager.testMode = false

        let restoredLocationManager = LocationManager()

        XCTAssertFalse(restoredLocationManager.testMode)
    }

    @MainActor
    func testReenablingTestModeDoesNotOverwriteExplicitCampaignChoices() {
        let locationManager = LocationManager()
        locationManager.testMode = true
        locationManager.contentMode = .natural
        locationManager.announceStreet = false

        locationManager.testMode = false
        locationManager.testMode = true

        XCTAssertEqual(locationManager.contentMode, .natural)
        XCTAssertFalse(locationManager.announceStreet)
    }

    @MainActor
    func testLocationUpdateIntervalThrottlingKeepsVisibleCoordinateFresh() {
        let locationManager = LocationManager()
        locationManager.testMode = false
        locationManager.locationCheckInterval = 60
        locationManager.startRide()

        let firstLocation = CLLocation(latitude: 51.6971, longitude: -2.5830)
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [firstLocation])

        XCTAssertEqual(locationManager.lastKnownLocation?.latitude, firstLocation.coordinate.latitude)
        XCTAssertEqual(locationManager.lastKnownLocation?.longitude, firstLocation.coordinate.longitude)

        let secondLocation = CLLocation(latitude: 51.6751, longitude: -2.6210)
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [secondLocation])

        XCTAssertEqual(locationManager.lastKnownLocation?.latitude, secondLocation.coordinate.latitude)
        XCTAssertEqual(locationManager.lastKnownLocation?.longitude, secondLocation.coordinate.longitude)
    }

    @MainActor
    func testTestModeIgnoresLiveLocationUpdates() {
        let locationManager = LocationManager()
        locationManager.testMode = true
        locationManager.startRide()

        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [location])

        let firstTestWaypoint = TestRouteFixture.waypoints[0]
        XCTAssertEqual(locationManager.lastKnownLocation?.latitude, firstTestWaypoint.latitude)
        XCTAssertEqual(locationManager.lastKnownLocation?.longitude, firstTestWaypoint.longitude)
    }

    @MainActor
    func testClearLocalPrivacyStateRemovesRiderContextAndVisibleRideState() {
        let locationManager = LocationManager()
        locationManager.homeCountry = "United Kingdom"
        locationManager.homeRegion = "Gloucestershire"
        locationManager.familiarRegions = "Cotswolds"
        locationManager.customFactInstructions = "Mention industrial history"
        locationManager.factInterestCategories = [.history]
        locationManager.contentMode = .longFacts
        locationManager.speechProvider = .proxyElevenLabs

        locationManager.clearLocalPrivacyState()

        XCTAssertEqual(locationManager.homeCountry, "")
        XCTAssertEqual(locationManager.homeRegion, "")
        XCTAssertEqual(locationManager.familiarRegions, "")
        XCTAssertEqual(locationManager.customFactInstructions, "")
        XCTAssertEqual(locationManager.factInterestCategories, FactInterestCategory.defaultSelections)
        XCTAssertNil(locationManager.lastKnownLocation)
        XCTAssertNil(locationManager.lastKnownAddress)
        XCTAssertNil(locationManager.lastSpokenPhrase)
        XCTAssertEqual(locationManager.contentMode, .shortFacts)
        XCTAssertEqual(locationManager.speechProvider, .proxyElevenLabs)
        XCTAssertFalse(locationManager.isTracking)
    }

    @MainActor
    func testMovingLocationStillAllowsMapInteraction() {
        let locationManager = LocationManager()
        locationManager.testMode = false
        locationManager.startRide()

        let movingLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 51.6971, longitude: -2.5830),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 12,
            timestamp: Date()
        )
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [movingLocation])

        XCTAssertTrue(locationManager.allowsMapInteraction)
    }

    @MainActor
    func testStationaryLocationAllowsMapInteraction() {
        let locationManager = LocationManager()
        locationManager.testMode = false
        locationManager.startRide()

        let stoppedLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 51.6971, longitude: -2.5830),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 0,
            timestamp: Date()
        )
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [stoppedLocation])

        XCTAssertTrue(locationManager.allowsMapInteraction)
    }

    @MainActor
    func testLocationFailurePublishesRiderStatus() {
        let locationManager = LocationManager()
        locationManager.startRide()

        locationManager.locationManager(CLLocationManager(), didFailWithError: CLError(.locationUnknown))

        XCTAssertEqual(locationManager.locationStatus, .locationUnavailable("Location update failed. RideHorizon will keep trying."))
    }

    @MainActor
    func testLateLocationCallbacksAreIgnoredAfterEndRide() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let diagnostics = RideDiagnosticsStore(directoryURL: directory)
        let locationManager = LocationManager(diagnostics: diagnostics)
        locationManager.startRide()
        locationManager.endRide()
        let eventsBeforeCallbacks = diagnostics.entries
        let lateLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 51.745, longitude: -2.218),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 0,
            timestamp: Date()
        )

        locationManager.locationManager(
            CLLocationManager(),
            didUpdateLocations: [lateLocation]
        )
        locationManager.locationManager(
            CLLocationManager(),
            didFailWithError: CLError(.locationUnknown)
        )

        XCTAssertEqual(locationManager.rideSessionState, .idle)
        XCTAssertEqual(locationManager.locationStatus, .idle)
        XCTAssertEqual(diagnostics.entries, eventsBeforeCallbacks)
    }

    func testLocationSummaryAndHierarchyUseMapDesignLabels() {
        let address = Address(
            street: "B4066",
            town: "Nailsworth",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        )

        XCTAssertEqual(
            LocationSummaryFormatter.summary(for: address),
            "B4066, Nailsworth, Gloucestershire"
        )

        let rows = LocationSummaryFormatter.hierarchyRows(for: address)
        XCTAssertEqual(rows.map(\.label), ["Street", "Town", "County", "Region", "Country"])
        XCTAssertEqual(rows.map(\.value), ["B4066", "Nailsworth", "Gloucestershire", "England", "United Kingdom"])
        XCTAssertEqual(rows.first?.isCurrent, true)
    }

    @MainActor
    func testPremiumVoiceRoutesEveryBoundaryThroughSelectedSpeechProvider() {
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput, aiSharingAllowed: { true })
        locationManager.speechProvider = .proxyElevenLabs

        for boundary in BoundaryType.allCases {
            locationManager.speakForTesting(text: "Boundary test for \(boundary.factLabel)", boundary: boundary)
        }

        XCTAssertEqual(speechOutput.requests.map(\.provider), Array(repeating: .proxyElevenLabs, count: BoundaryType.allCases.count))
        XCTAssertEqual(speechOutput.requests.map(\.boundary), BoundaryType.allCases)
    }

    @MainActor
    func testLegacyAppleSpeechProviderDefaultMigratesToPremiumVoiceForAnnouncements() {
        clearSpeechProviderDefaults()
        UserDefaults.standard.set("apple", forKey: "RideHorizonSpeechProvider")

        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput, aiSharingAllowed: { true })

        locationManager.speakForTesting(text: "Boundary test for town", boundary: .town)

        XCTAssertEqual(locationManager.speechProvider, .proxyElevenLabs)
        XCTAssertEqual(speechOutput.requests.last?.provider, .proxyElevenLabs)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "RideHorizonSpeechProvider"), "proxyElevenLabs")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "RideHorizonSpeechProviderPremiumNoAppleFallbackMigration20260703"))
    }

    @MainActor
    func testAppleSpeechProviderPersistsAfterPremiumDefaultMigration() {
        clearSpeechProviderDefaults()
        UserDefaults.standard.set("apple", forKey: "RideHorizonSpeechProvider")
        UserDefaults.standard.set(true, forKey: "RideHorizonSpeechProviderPremiumNoAppleFallbackMigration20260703")

        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput, aiSharingAllowed: { true })

        locationManager.speakForTesting(text: "Boundary test for town", boundary: .town)

        XCTAssertEqual(locationManager.speechProvider, .apple)
        XCTAssertEqual(speechOutput.requests.last?.provider, .apple)
    }

    @MainActor
    func testTestModeDoesNotEnablePremiumVoiceAppleFallbackByDefault() {
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput, aiSharingAllowed: { true })
        locationManager.testMode = true
        locationManager.premiumVoiceAppleFallbackEnabled = false

        locationManager.speakForTesting(text: "Boundary test for town", boundary: .town)

        XCTAssertEqual(speechOutput.requests.last?.provider, .proxyElevenLabs)
        XCTAssertEqual(speechOutput.requests.last?.allowAppleFallback, false)
    }

    @MainActor
    func testPremiumVoiceAppleFallbackFeatureFlagControlsSpeechFallback() {
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput, aiSharingAllowed: { true })
        locationManager.testMode = true
        locationManager.premiumVoiceAppleFallbackEnabled = true

        locationManager.speakForTesting(text: "Boundary test for town", boundary: .town)

        XCTAssertEqual(speechOutput.requests.last?.provider, .proxyElevenLabs)
        XCTAssertEqual(speechOutput.requests.last?.allowAppleFallback, true)
    }

    @MainActor
    func testPremiumVoiceDoesNotFallbackToAppleWhenProxyFails() async {
        let appleSpeechOutput = RecordingAppleSpeechOutput()
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: StubProxySpeechGenerator(result: .failure(PlaceFactError.invalidResponse)),
            appleSpeechOutput: appleSpeechOutput
        )
        let finished = expectation(description: "Premium voice failure finishes without Apple fallback")
        var diagnosticNote: String?
        speechOutput.onFinish = {
            finished.fulfill()
        }
        speechOutput.onDiagnosticNote = { note in
            diagnosticNote = note
        }

        speechOutput.speak(
            text: "Known for its market square.",
            boundary: .town,
            provider: .proxyElevenLabs,
            appleVoice: nil,
            allowAppleFallback: false
        )

        await fulfillment(of: [finished], timeout: 1.0)
        XCTAssertTrue(appleSpeechOutput.requests.isEmpty)
        XCTAssertEqual(diagnosticNote, "Premium voice failed: invalid proxy response. Apple fallback disabled.")
    }

    @MainActor
    func testPremiumVoiceShowsOnlyOpaqueProviderDiagnosticCode() async {
        let appleSpeechOutput = RecordingAppleSpeechOutput()
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: StubProxySpeechGenerator(
                result: .failure(PlaceFactError.speechServiceUnavailable(code: "RH-TTS-02"))
            ),
            appleSpeechOutput: appleSpeechOutput
        )
        let finished = expectation(description: "Coded premium voice failure finishes")
        var diagnosticNote: String?
        speechOutput.onFinish = {
            finished.fulfill()
        }
        speechOutput.onDiagnosticNote = { note in
            diagnosticNote = note
        }

        speechOutput.speak(
            text: "Known for its market square.",
            boundary: .town,
            provider: .proxyElevenLabs,
            appleVoice: nil,
            allowAppleFallback: false
        )

        await fulfillment(of: [finished], timeout: 1.0)
        XCTAssertTrue(appleSpeechOutput.requests.isEmpty)
        XCTAssertEqual(
            diagnosticNote,
            "Premium voice failed: Premium voice is temporarily unavailable. [RH-TTS-02]. Apple fallback disabled."
        )
        XCTAssertFalse(diagnosticNote?.localizedCaseInsensitiveContains("credit") == true)
        XCTAssertFalse(diagnosticNote?.localizedCaseInsensitiveContains("quota") == true)
    }

    @MainActor
    func testPremiumVoiceDoesNotFallbackToAppleWhenProxyReturnsNoAudio() async {
        let appleSpeechOutput = RecordingAppleSpeechOutput()
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: StubProxySpeechGenerator(result: .success([])),
            appleSpeechOutput: appleSpeechOutput
        )
        let finished = expectation(description: "Empty premium voice response finishes without Apple fallback")
        speechOutput.onFinish = {
            finished.fulfill()
        }

        speechOutput.speak(
            text: "Known for its market square.",
            boundary: .town,
            provider: .proxyElevenLabs,
            appleVoice: nil,
            allowAppleFallback: false
        )

        await fulfillment(of: [finished], timeout: 1.0)
        XCTAssertTrue(appleSpeechOutput.requests.isEmpty)
    }

    @MainActor
    func testPremiumVoiceUsesAppleFallbackWhenFeatureFlagAllowsIt() async {
        let appleSpeechOutput = RecordingAppleSpeechOutput()
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: StubProxySpeechGenerator(result: .failure(PlaceFactError.invalidResponse)),
            appleSpeechOutput: appleSpeechOutput
        )
        var diagnosticNote: String?
        speechOutput.onDiagnosticNote = { note in
            diagnosticNote = note
        }

        speechOutput.speak(
            text: "Known for its market square.",
            boundary: .town,
            provider: .proxyElevenLabs,
            appleVoice: nil,
            allowAppleFallback: true
        )

        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(appleSpeechOutput.requests.map(\.text), ["Known for its market square."])
        XCTAssertEqual(appleSpeechOutput.requests.map(\.boundary), [.town])
        XCTAssertTrue(diagnosticNote?.hasPrefix("Premium voice failed:") == true)
        XCTAssertTrue(diagnosticNote?.hasSuffix("Apple fallback used.") == true)
    }

    @MainActor
    func testSupersededPremiumVoiceRequestDoesNotTriggerDelayedAppleFallback() async {
        let appleSpeechOutput = RecordingAppleSpeechOutput()
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: DelayedFailingProxySpeechGenerator(),
            appleSpeechOutput: appleSpeechOutput
        )
        var diagnosticNote: String?
        speechOutput.onDiagnosticNote = { note in
            diagnosticNote = note
        }

        speechOutput.speak(
            text: "This announcement will be superseded.",
            boundary: .town,
            provider: .proxyElevenLabs,
            appleVoice: nil,
            allowAppleFallback: true
        )
        try? await Task.sleep(nanoseconds: 20_000_000)
        speechOutput.stop()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(appleSpeechOutput.requests.isEmpty)
        XCTAssertNil(diagnosticNote)
    }

    @MainActor
    func testPremiumVoiceReportsActiveWhileWaitingForNetworkAudio() {
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: DelayedFailingProxySpeechGenerator(),
            appleSpeechOutput: RecordingAppleSpeechOutput()
        )

        speechOutput.speak(
            text: "Waiting for network audio.",
            boundary: .town,
            provider: .proxyElevenLabs,
            appleVoice: nil,
            allowAppleFallback: false
        )

        XCTAssertTrue(speechOutput.isSpeaking)
        speechOutput.stop()
    }

    @MainActor
    func testStoppingIdleSpeechEngineDoesNotReportCancellation() {
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: DelayedFailingProxySpeechGenerator(),
            appleSpeechOutput: RecordingAppleSpeechOutput()
        )
        var cancellationCount = 0
        speechOutput.onCancel = {
            cancellationCount += 1
        }

        speechOutput.stop()

        XCTAssertEqual(cancellationCount, 0)
    }

    @MainActor
    func testAppleProviderUsesAppleSpeechOutputOnlyWhenExplicitlySelected() {
        let appleSpeechOutput = RecordingAppleSpeechOutput()
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: StubProxySpeechGenerator(result: .failure(PlaceFactError.invalidResponse)),
            appleSpeechOutput: appleSpeechOutput
        )

        speechOutput.speak(
            text: "Known for its market square.",
            boundary: .town,
            provider: .apple,
            appleVoice: nil,
            allowAppleFallback: false
        )

        XCTAssertEqual(appleSpeechOutput.requests.map(\.text), ["Known for its market square."])
        XCTAssertEqual(appleSpeechOutput.requests.map(\.boundary), [.town])
    }

    @MainActor
    func testStaleAppleCancellationCannotCancelReplacementSpeech() {
        let appleSpeechOutput = RecordingAppleSpeechOutput()
        let speechOutput = DefaultSpeechOutputEngine(
            proxySpeechGenerator: DelayedFailingProxySpeechGenerator(),
            appleSpeechOutput: appleSpeechOutput
        )
        var cancellationCount = 0
        speechOutput.onCancel = {
            cancellationCount += 1
        }

        speechOutput.speak(
            text: "First announcement",
            boundary: .town,
            provider: .apple,
            appleVoice: nil,
            allowAppleFallback: false
        )
        let firstRequestID = appleSpeechOutput.requests[0].requestID
        appleSpeechOutput.emitStart(requestID: firstRequestID)
        speechOutput.stop()

        speechOutput.speak(
            text: "Replacement announcement",
            boundary: .county,
            provider: .apple,
            appleVoice: nil,
            allowAppleFallback: false
        )
        let secondRequestID = appleSpeechOutput.requests[1].requestID
        appleSpeechOutput.emitStart(requestID: secondRequestID)
        appleSpeechOutput.emitCancel(requestID: firstRequestID)

        XCTAssertEqual(cancellationCount, 1)
    }

    @MainActor
    func testDeclinedAISharingSkipsFactProviderAndForcesAppleSpeech() async {
        let factGenerator = MockPlaceFactGenerator()
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            factGenerator: factGenerator,
            speechOutput: speechOutput,
            aiSharingAllowed: { false }
        )
        locationManager.testMode = false
        locationManager.contentMode = .shortFacts
        locationManager.speechProvider = .proxyElevenLabs
        locationManager.bluetoothDelaySeconds = 0

        locationManager.processResolvedAddressForTesting(Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Bristol Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(factGenerator.callCount, 0)
        XCTAssertEqual(speechOutput.requests.last?.provider, .apple)
        XCTAssertEqual(speechOutput.requests.last?.text, "You are in Stonehouse, Gloucestershire")
    }

    @MainActor
    func testNewSuppressedBoundaryCancelsOlderFactInsteadOfSpeakingStalePlace() async {
        let factGenerator = MockPlaceFactGenerator()
        factGenerator.delayNanoseconds = 150_000_000
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            factGenerator: factGenerator,
            speechOutput: speechOutput,
            aiSharingAllowed: { true }
        )
        locationManager.testMode = false
        locationManager.contentMode = .shortFacts
        locationManager.boundarySpeechCooldownSeconds = 60
        locationManager.bluetoothDelaySeconds = 0

        let stroud = Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        )
        let stonehouse = Address(
            street: "Bristol Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        )
        let dursley = Address(
            street: "Long Street",
            town: "Dursley",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        )
        let stonehouseRequest = AnnouncementPolicy.factRequest(
            for: AnnouncementPlan(text: "You are in Stonehouse, Gloucestershire", boundary: .town),
            address: stonehouse,
            mode: .shortFacts,
            riderContext: .empty
        )
        factGenerator.factsByCacheKey[stonehouseRequest.cacheKey] = "Known for its canal-side industry."

        locationManager.processResolvedAddressForTesting(stroud)
        locationManager.processResolvedAddressForTesting(stonehouse)
        locationManager.processResolvedAddressForTesting(dursley)
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(speechOutput.requests.isEmpty)
    }

    @MainActor
    func testStreetOnlyGeocoderChangeDoesNotCancelTownFact() async {
        let factGenerator = MockPlaceFactGenerator()
        factGenerator.delayNanoseconds = 150_000_000
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            factGenerator: factGenerator,
            speechOutput: speechOutput,
            aiSharingAllowed: { true }
        )
        locationManager.testMode = false
        locationManager.contentMode = .shortFacts
        locationManager.boundarySpeechCooldownSeconds = 0
        locationManager.bluetoothDelaySeconds = 0

        locationManager.processResolvedAddressForTesting(Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Bristol Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Bath Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(speechOutput.requests.last?.boundary, .town)
        XCTAssertEqual(speechOutput.requests.last?.text, "You are in Stonehouse, Gloucestershire")
    }

    @MainActor
    func testLowerPriorityTownDoesNotCancelHigherPriorityCountryFact() async {
        let factGenerator = MockPlaceFactGenerator()
        factGenerator.delayNanoseconds = 150_000_000
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(
            factGenerator: factGenerator,
            speechOutput: speechOutput,
            aiSharingAllowed: { true }
        )
        locationManager.testMode = false
        locationManager.contentMode = .shortFacts
        locationManager.boundarySpeechCooldownSeconds = 0
        locationManager.bluetoothDelaySeconds = 0

        locationManager.processResolvedAddressForTesting(Address(
            street: "High Street",
            town: "Dover",
            county: "Kent",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Rue de Paris",
            town: "Calais",
            county: "Pas-de-Calais",
            administrativeArea: "Hauts-de-France",
            country: "France"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Rue Royale",
            town: "Lille",
            county: "Nord",
            administrativeArea: "Hauts-de-France",
            country: "France"
        ))
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(speechOutput.requests.count, 1)
        XCTAssertEqual(speechOutput.requests.first?.boundary, .country)
        XCTAssertTrue(speechOutput.requests.first?.text.hasPrefix("Welcome to France.") == true)
    }

    @MainActor
    func testNewBoundaryCancelsOlderSpeechPreparationBeforeQueuingReplacement() async {
        let speechOutput = RecordingSpeechOutputEngine()
        let locationManager = LocationManager(speechOutput: speechOutput, aiSharingAllowed: { true })
        locationManager.testMode = false
        locationManager.contentMode = .namesOnly
        locationManager.boundarySpeechCooldownSeconds = 0
        locationManager.bluetoothDelaySeconds = 0

        locationManager.processResolvedAddressForTesting(Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        locationManager.processResolvedAddressForTesting(Address(
            street: "Bristol Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))
        try? await Task.sleep(nanoseconds: 50_000_000)
        let cancellationsBeforeNewBoundary = speechOutput.cancelPendingPreparationCount

        locationManager.processResolvedAddressForTesting(Address(
            street: "Long Street",
            town: "Dursley",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))

        XCTAssertEqual(
            speechOutput.cancelPendingPreparationCount,
            cancellationsBeforeNewBoundary + 1
        )
    }

    private func clearSpeechProviderDefaults() {
        UserDefaults.standard.removeObject(forKey: "RideHorizonSpeechProvider")
        UserDefaults.standard.removeObject(forKey: "RideHorizonSpeechProviderPremiumNoAppleFallbackMigration20260703")
        UserDefaults.standard.removeObject(forKey: "RideHorizonPremiumVoiceAppleFallbackEnabled")
    }

    private func clearLocationManagerDefaults() {
        [
            "RideHorizonTestMode",
            "RideHorizonAudioInteropDebugTestModeChoice",
            "RideHorizonInterruptsMusic"
        ].forEach(UserDefaults.standard.removeObject(forKey:))
    }

    private func useLiveLocationByDefaultForTests() {
        UserDefaults.standard.set(false, forKey: "RideHorizonTestMode")
        UserDefaults.standard.set(true, forKey: "RideHorizonAudioInteropDebugTestModeChoice")
    }

    private func clearRiderContextDefaults() {
        [
            "RideHorizonHomeCountry",
            "RideHorizonHomeRegion",
            "RideHorizonFamiliarRegions",
            "RideHorizonCustomFactInstructions",
            "RideHorizonFactInterestCategories"
        ].forEach(UserDefaults.standard.removeObject(forKey:))
    }
}
