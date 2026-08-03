#if INTERNAL_AUDIO_CALIBRATION
import Foundation
import SwiftUI
import UIKit
import CryptoKit
import AVFoundation

enum SpeechCalibrationFixture: String, CaseIterable, Identifiable, Codable {
    case placeName
    case boundary
    case shortFact

    var id: String { rawValue }

    var label: String {
        switch self {
        case .placeName: "Place Name"
        case .boundary: "Boundary"
        case .shortFact: "Short Fact"
        }
    }
}

enum SpeechCalibrationProvider: String, CaseIterable, Identifiable {
    case premiumFixture
    case appleVoice

    var id: String { rawValue }

    var label: String {
        switch self {
        case .premiumFixture: "Premium Fixture"
        case .appleVoice: "Apple Voice"
        }
    }
}

struct SpeechCalibrationManifest: Decodable, Equatable {
    struct Fixture: Decodable, Equatable {
        let id: SpeechCalibrationFixture
        let filename: String
        let announcementText: String
        let byteLength: Int
        let sha256: String
        let rawIntegratedLUFS: Double
        let rawTruePeakDBFS: Double
    }

    let schemaVersion: Int
    let fixtureRevision: String
    let generationDate: String
    let proxySpeechContractRevision: String
    let elevenLabsModel: String
    let elevenLabsOutputFormat: String
    let voiceConfigurationRevision: String
    let privacyStatement: String
    let fixtures: [Fixture]
}

struct LoadedSpeechCalibrationFixture: Equatable {
    let metadata: SpeechCalibrationManifest.Fixture
    let rawSpeechAudio: Data
    let revision: String
}

enum SpeechCalibrationError: LocalizedError, Equatable {
    case rideActive
    case missingFixture
    case invalidFixture
    case playbackFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .rideActive: "End the ride before using Speech Calibration."
        case .missingFixture: "The selected calibration fixture is unavailable."
        case .invalidFixture: "The calibration fixture failed its integrity check."
        case .playbackFailed: "Calibration playback failed."
        case .cancelled: "Calibration playback stopped."
        }
    }
}

protocol SpeechCalibrationFixtureLoading {
    func manifest() throws -> SpeechCalibrationManifest
    func load(_ fixture: SpeechCalibrationFixture) throws -> LoadedSpeechCalibrationFixture
}

struct BundleSpeechCalibrationFixtureLoader: SpeechCalibrationFixtureLoading {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func manifest() throws -> SpeechCalibrationManifest {
        guard let url = bundle.url(
            forResource: "speech-calibration-manifest",
            withExtension: "json"
        ) else { throw SpeechCalibrationError.missingFixture }
        return try JSONDecoder().decode(SpeechCalibrationManifest.self, from: Data(contentsOf: url))
    }

    func load(_ fixture: SpeechCalibrationFixture) throws -> LoadedSpeechCalibrationFixture {
        let manifest = try manifest()
        guard let metadata = manifest.fixtures.first(where: { $0.id == fixture }),
              let url = bundle.url(forResource: metadata.filename, withExtension: nil) else {
            throw SpeechCalibrationError.missingFixture
        }
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard data.count == metadata.byteLength, digest == metadata.sha256 else {
            throw SpeechCalibrationError.invalidFixture
        }
        return LoadedSpeechCalibrationFixture(
            metadata: metadata,
            rawSpeechAudio: data,
            revision: manifest.fixtureRevision
        )
    }
}

struct SavedSpeechCalibrationProfile: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let profile: SpeechProcessingProfile
    let fixtureRevision: String
    let savedAt: Date
}

struct SpeechCalibrationProfileStore {
    static let defaultsKey = "RideHorizonInternalSpeechCalibrationProfiles"
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [SavedSpeechCalibrationProfile] {
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([SavedSpeechCalibrationProfile].self, from: data)) ?? []
    }

    func save(_ profiles: [SavedSpeechCalibrationProfile]) throws {
        defaults.set(try JSONEncoder().encode(profiles), forKey: Self.defaultsKey)
    }
}

struct SpeechCalibrationRuntimeProfileStore {
    private static let enabledKey = "RideHorizonInternalSpeechCalibrationRideOverrideEnabled"
    private static let profileKey = "RideHorizonInternalSpeechCalibrationRideOverrideProfile"
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func activeProfile() -> SpeechProcessingProfile? {
        guard defaults.bool(forKey: Self.enabledKey),
              let data = defaults.data(forKey: Self.profileKey) else { return nil }
        return try? JSONDecoder().decode(SpeechProcessingProfile.self, from: data)
    }

    func setActiveProfile(_ profile: SpeechProcessingProfile?) {
        guard let profile else {
            defaults.set(false, forKey: Self.enabledKey)
            defaults.removeObject(forKey: Self.profileKey)
            return
        }
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: Self.profileKey)
        defaults.set(true, forKey: Self.enabledKey)
    }
}

@MainActor
protocol SpeechCalibrationOutputVolumeObserving: AnyObject {
    var currentVolume: Float { get }
    func start(onChange: @escaping @MainActor (Float) -> Void)
}

@MainActor
final class SystemSpeechCalibrationOutputVolumeObserver: SpeechCalibrationOutputVolumeObserving {
    private let session: AVAudioSession
    private var observation: NSKeyValueObservation?

    init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    var currentVolume: Float { session.outputVolume }

    func start(onChange: @escaping @MainActor (Float) -> Void) {
        observation = session.observe(\.outputVolume, options: [.initial, .new]) { session, _ in
            Task { @MainActor in onChange(session.outputVolume) }
        }
    }
}

@MainActor
protocol SpeechCalibrationAudioHosting: AnyObject {
    var isRideActiveForCalibration: Bool { get }
    var calibrationAudioSnapshot: AudioSessionSnapshot { get }
    func playCalibrationApple(
        announcementText: String,
        fixtureID: SpeechCalibrationFixture,
        profileID: String,
        onPlaybackStarted: @escaping @MainActor () -> Void,
        completion: @escaping @MainActor (Result<Void, Error>) -> Void
    )
    func playCalibrationPremium(
        rawSpeechAudio: Data,
        profile: SpeechProcessingProfile,
        fixtureID: SpeechCalibrationFixture,
        profileID: String,
        onPlaybackStarted: @escaping @MainActor () -> Void,
        completion: @escaping @MainActor (Result<PreparedPremiumAudio, Error>) -> Void
    )
    func stopCalibrationPlayback()
}

enum SpeechCalibrationPlaybackState: Equatable {
    case ready
    case preparing
    case playing
    case succeeded
    case stopped
    case failed(String)

    var label: String {
        switch self {
        case .ready: "Ready"
        case .preparing: "Preparing speech audio"
        case .playing: "Playing"
        case .succeeded: "Playback complete"
        case .stopped: "Stopped"
        case .failed(let message): message
        }
    }
}

@MainActor
final class SpeechCalibrationLabModel: ObservableObject {
    @Published var selectedFixture: SpeechCalibrationFixture = .placeName
    @Published var selectedProvider: SpeechCalibrationProvider = .premiumFixture
    @Published private(set) var candidateProfile: SpeechProcessingProfile
    @Published var playbackState: SpeechCalibrationPlaybackState = .ready
    @Published var profileName = "Candidate"
    @Published private(set) var systemOutputVolume: Float
    @Published private(set) var useCandidateForNormalPremiumVoice: Bool
    @Published private(set) var savedProfiles: [SavedSpeechCalibrationProfile]

    private let host: SpeechCalibrationAudioHosting
    private let fixtureLoader: SpeechCalibrationFixtureLoading
    private let profileStore: SpeechCalibrationProfileStore
    private let runtimeProfileStore: SpeechCalibrationRuntimeProfileStore
    private let outputVolumeObserver: SpeechCalibrationOutputVolumeObserving
    private var lastSelection: (
        profile: SpeechProcessingProfile,
        profileID: String,
        fixture: SpeechCalibrationFixture,
        provider: SpeechCalibrationProvider
    )?

    init(
        host: SpeechCalibrationAudioHosting,
        fixtureLoader: SpeechCalibrationFixtureLoading = BundleSpeechCalibrationFixtureLoader(),
        profileStore: SpeechCalibrationProfileStore = SpeechCalibrationProfileStore(),
        runtimeProfileStore: SpeechCalibrationRuntimeProfileStore = SpeechCalibrationRuntimeProfileStore(),
        outputVolumeObserver: SpeechCalibrationOutputVolumeObserving? = nil
    ) {
        let resolvedOutputVolumeObserver = outputVolumeObserver
            ?? SystemSpeechCalibrationOutputVolumeObserver()
        self.host = host
        self.fixtureLoader = fixtureLoader
        self.profileStore = profileStore
        self.runtimeProfileStore = runtimeProfileStore
        self.outputVolumeObserver = resolvedOutputVolumeObserver
        let activeProfile = runtimeProfileStore.activeProfile()
        candidateProfile = activeProfile ?? .production
        useCandidateForNormalPremiumVoice = activeProfile != nil
        systemOutputVolume = resolvedOutputVolumeObserver.currentVolume
        savedProfiles = profileStore.load()
        resolvedOutputVolumeObserver.start { [weak self] volume in
            self?.systemOutputVolume = volume
        }
    }

    var isRideActive: Bool { host.isRideActiveForCalibration }
    var audioSnapshot: AudioSessionSnapshot { host.calibrationAudioSnapshot }

    var outputGainDB: Float {
        get { candidateProfile.outputGainDB }
        set {
            guard !host.isRideActiveForCalibration else { return }
            updateCandidate(outputGainDB: newValue)
        }
    }

    var compressionPreset: SpeechCompressionPreset {
        get { candidateProfile.compressionPreset }
        set {
            guard !host.isRideActiveForCalibration else { return }
            updateCandidate(compressionPreset: newValue)
        }
    }

    var presenceGainDB: Float {
        get { candidateProfile.presenceGainDB }
        set {
            guard !host.isRideActiveForCalibration else { return }
            updateCandidate(presenceGainDB: newValue)
        }
    }

    func playCurrentA() {
        play(profile: .production, profileID: "current-a")
    }

    func playCandidateB() {
        play(profile: candidateProfile, profileID: "candidate-b")
    }

    func repeatLast() {
        guard let lastSelection else { return }
        play(
            profile: lastSelection.profile,
            profileID: lastSelection.profileID,
            fixture: lastSelection.fixture,
            provider: lastSelection.provider
        )
    }

    func stop() {
        host.stopCalibrationPlayback()
        playbackState = .stopped
    }

    func resetCandidate() {
        guard !host.isRideActiveForCalibration else { return }
        candidateProfile = .production
        persistActiveCandidateIfNeeded()
    }

    func setUseCandidateForNormalPremiumVoice(_ enabled: Bool) {
        guard !host.isRideActiveForCalibration else { return }
        useCandidateForNormalPremiumVoice = enabled
        runtimeProfileStore.setActiveProfile(enabled ? candidateProfile : nil)
    }

    func saveCandidate(now: Date = Date()) throws {
        guard !host.isRideActiveForCalibration else {
            throw SpeechCalibrationError.rideActive
        }
        let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let revision = try fixtureLoader.manifest().fixtureRevision
        let saved = SavedSpeechCalibrationProfile(
            id: UUID(),
            name: trimmedName.isEmpty ? "Candidate" : trimmedName,
            profile: candidateProfile,
            fixtureRevision: revision,
            savedAt: now
        )
        savedProfiles.append(saved)
        try profileStore.save(savedProfiles)
    }

    func candidateJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(candidateProfile), as: UTF8.self)
    }

    private func play(
        profile: SpeechProcessingProfile,
        profileID: String,
        fixture: SpeechCalibrationFixture? = nil,
        provider: SpeechCalibrationProvider? = nil
    ) {
        guard !host.isRideActiveForCalibration else {
            playbackState = .failed(SpeechCalibrationError.rideActive.localizedDescription)
            return
        }
        host.stopCalibrationPlayback()
        playbackState = .preparing
        let fixtureSelection = fixture ?? selectedFixture
        let providerSelection = provider ?? selectedProvider
        lastSelection = (profile, profileID, fixtureSelection, providerSelection)
        do {
            let loadedFixture = try fixtureLoader.load(fixtureSelection)
            switch providerSelection {
            case .appleVoice:
                host.playCalibrationApple(
                    announcementText: loadedFixture.metadata.announcementText,
                    fixtureID: fixtureSelection,
                    profileID: profileID,
                    onPlaybackStarted: { [weak self] in self?.playbackState = .playing }
                ) { [weak self] result in
                    self?.complete(result.map { _ in () })
                }
            case .premiumFixture:
                host.playCalibrationPremium(
                    rawSpeechAudio: loadedFixture.rawSpeechAudio,
                    profile: profile,
                    fixtureID: fixtureSelection,
                    profileID: profileID,
                    onPlaybackStarted: { [weak self] in self?.playbackState = .playing }
                ) { [weak self] result in
                    if case .success = result { self?.playbackState = .succeeded }
                    if case .failure(let error) = result {
                        self?.playbackState = .failed(error.localizedDescription)
                    }
                }
            }
        } catch {
            playbackState = .failed(error.localizedDescription)
        }
    }

    private func complete(_ result: Result<Void, Error>) {
        switch result {
        case .success: playbackState = .succeeded
        case .failure(let error): playbackState = .failed(error.localizedDescription)
        }
    }

    private func updateCandidate(
        outputGainDB: Float? = nil,
        compressionPreset: SpeechCompressionPreset? = nil,
        presenceGainDB: Float? = nil
    ) {
        candidateProfile = .calibrationCandidate(
            outputGainDB: outputGainDB ?? candidateProfile.outputGainDB,
            compressionPreset: compressionPreset ?? candidateProfile.compressionPreset,
            presenceGainDB: presenceGainDB ?? candidateProfile.presenceGainDB
        )
        persistActiveCandidateIfNeeded()
    }

    private func persistActiveCandidateIfNeeded() {
        guard useCandidateForNormalPremiumVoice else { return }
        runtimeProfileStore.setActiveProfile(candidateProfile)
    }
}

struct SpeechCalibrationLabView: View {
    @StateObject private var model: SpeechCalibrationLabModel
    @State private var feedback: String?

    init(locationManager: LocationManager) {
        _model = StateObject(wrappedValue: SpeechCalibrationLabModel(host: locationManager))
    }

    var body: some View {
        Form {
            Section("Stationary calibration only") {
                Text("Stop the motorcycle and end the active ride before using this lab. Start YouTube Music manually before each comparison.")
                if model.isRideActive {
                    Label("End the active ride to enable playback.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Section("Output") {
                LabeledContent("Route", value: model.audioSnapshot.outputRouteTypes.joined(separator: ", ").nilIfEmpty ?? "No output")
                LabeledContent("System output volume (read-only)", value: String(format: "%.0f%%", model.systemOutputVolume * 100))
            }

            Section("Comparison") {
                Picker("Fixture", selection: $model.selectedFixture) {
                    ForEach(SpeechCalibrationFixture.allCases) { Text($0.label).tag($0) }
                }
                Picker("Provider", selection: $model.selectedProvider) {
                    ForEach(SpeechCalibrationProvider.allCases) { Text($0.label).tag($0) }
                }
                HStack {
                    Button("Current A") { model.playCurrentA() }
                        .buttonStyle(.borderedProminent)
                    Button("Candidate B") { model.playCandidateB() }
                        .buttonStyle(.borderedProminent)
                }
                .disabled(model.isRideActive)
                HStack {
                    Button("Repeat") { model.repeatLast() }
                    Button("Stop", role: .destructive) { model.stop() }
                }
                Text(model.playbackState.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Candidate B") {
                Picker("Output gain", selection: Binding(
                    get: { model.outputGainDB },
                    set: { model.outputGainDB = $0 }
                )) {
                    ForEach([Float(0), 6, 12, 18, 24], id: \.self) { value in
                        Text(value == 0 ? "0 dB" : "+\(Int(value)) dB").tag(value)
                    }
                }
                Picker("Compression", selection: Binding(
                    get: { model.compressionPreset },
                    set: { model.compressionPreset = $0 }
                )) {
                    ForEach(SpeechCompressionPreset.allCases) { Text($0.label).tag($0) }
                }
                Picker("Presence", selection: Binding(
                    get: { model.presenceGainDB },
                    set: { model.presenceGainDB = $0 }
                )) {
                    ForEach([Float(0), 6, 12, 18], id: \.self) { value in
                        Text(value == 0 ? "0 dB" : "+\(Int(value)) dB").tag(value)
                    }
                }
                Button("Reset to Current A") { model.resetCandidate() }
                Text("Output gain, compression and presence affect Candidate B only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Higher gain settings drive the safety limiter harder and may add audible distortion. Compare them while stopped before enabling a ride test.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .disabled(model.isRideActive)

            Section("Normal Premium Voice ride test") {
                Toggle(
                    "Use Candidate B for normal Premium Voice",
                    isOn: Binding(
                        get: { model.useCandidateForNormalPremiumVoice },
                        set: { model.setUseCandidateForNormalPremiumVoice($0) }
                    )
                )
                .disabled(model.isRideActive)
                Text(
                    model.useCandidateForNormalPremiumVoice
                        ? "Active in this internal build. Normal Premium Voice announcements will use the current Candidate B settings after you leave this screen."
                        : "Off. Normal announcements use Current A. Pressing Candidate B does not enable this switch."
                )
                .font(.footnote)
                .foregroundStyle(model.useCandidateForNormalPremiumVoice ? .orange : .secondary)
            }

            Section("Save or export") {
                TextField("Profile name", text: $model.profileName)
                Button("Save Candidate B locally") {
                    do {
                        try model.saveCandidate()
                        feedback = "Saved locally. Production remains unchanged."
                    } catch {
                        feedback = error.localizedDescription
                    }
                }
                Button("Copy Candidate B JSON") {
                    do {
                        UIPasteboard.general.string = try model.candidateJSON()
                        feedback = "Candidate JSON copied."
                    } catch {
                        feedback = error.localizedDescription
                    }
                }
                if let json = try? model.candidateJSON() {
                    ShareLink("Export Candidate B JSON", item: json)
                }
                if !model.savedProfiles.isEmpty {
                    ForEach(model.savedProfiles) { saved in
                        Text("\(saved.name) · \(saved.savedAt.formatted(date: .numeric, time: .shortened))")
                            .font(.footnote)
                    }
                }
                if let feedback {
                    Text(feedback).font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Candidate values are experimental. The ride-test switch affects only this internal build and never changes the production profile.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Speech Calibration")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.stop() }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension LocationManager: SpeechCalibrationAudioHosting {}
#endif
