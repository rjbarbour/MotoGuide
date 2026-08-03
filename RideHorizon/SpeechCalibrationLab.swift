#if INTERNAL_AUDIO_CALIBRATION
import Foundation
import SwiftUI
import UIKit
import CryptoKit

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
    @Published var candidateProfile: SpeechProcessingProfile = .production
    @Published var playbackState: SpeechCalibrationPlaybackState = .ready
    @Published var profileName = "Candidate"
    @Published private(set) var savedProfiles: [SavedSpeechCalibrationProfile]

    private let host: SpeechCalibrationAudioHosting
    private let fixtureLoader: SpeechCalibrationFixtureLoading
    private let profileStore: SpeechCalibrationProfileStore
    private var lastSelection: (
        profile: SpeechProcessingProfile,
        profileID: String,
        fixture: SpeechCalibrationFixture,
        provider: SpeechCalibrationProvider
    )?

    init(
        host: SpeechCalibrationAudioHosting,
        fixtureLoader: SpeechCalibrationFixtureLoading = BundleSpeechCalibrationFixtureLoader(),
        profileStore: SpeechCalibrationProfileStore = SpeechCalibrationProfileStore()
    ) {
        self.host = host
        self.fixtureLoader = fixtureLoader
        self.profileStore = profileStore
        savedProfiles = profileStore.load()
    }

    var isRideActive: Bool { host.isRideActiveForCalibration }
    var audioSnapshot: AudioSessionSnapshot { host.calibrationAudioSnapshot }

    var outputGainDB: Float {
        get { candidateProfile.outputGainDB }
        set { updateCandidate(outputGainDB: newValue) }
    }

    var compressionPreset: SpeechCompressionPreset {
        get { candidateProfile.compressionPreset }
        set { updateCandidate(compressionPreset: newValue) }
    }

    var presenceGainDB: Float {
        get { candidateProfile.presenceGainDB }
        set { updateCandidate(presenceGainDB: newValue) }
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
        candidateProfile = .production
    }

    func saveCandidate(now: Date = Date()) throws {
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
                LabeledContent("System output volume (read-only)", value: String(format: "%.0f%%", model.audioSnapshot.outputVolume * 100))
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
                VStack(alignment: .leading) {
                    Text("Output gain: \(model.outputGainDB, specifier: "%.1f") dB")
                    Slider(
                        value: Binding(get: { Double(model.outputGainDB) }, set: { model.outputGainDB = Float($0) }),
                        in: 0...12,
                        step: 0.5
                    )
                }
                Picker("Compression", selection: Binding(
                    get: { model.compressionPreset },
                    set: { model.compressionPreset = $0 }
                )) {
                    ForEach(SpeechCompressionPreset.allCases) { Text($0.label).tag($0) }
                }
                VStack(alignment: .leading) {
                    Text("Presence: \(model.presenceGainDB, specifier: "%.0f") dB")
                    Slider(
                        value: Binding(get: { Double(model.presenceGainDB) }, set: { model.presenceGainDB = Float($0) }),
                        in: 0...4,
                        step: 1
                    )
                }
                Button("Reset to Current A") { model.resetCandidate() }
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
                Text("Candidate values are experimental and never replace the production profile automatically.")
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
