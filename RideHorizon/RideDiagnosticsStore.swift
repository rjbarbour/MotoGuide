import Foundation
import Network

enum RideDiagnosticEvent: String, Codable, Equatable {
    case appEnteredForeground
    case appEnteredBackground
    case rideStarted
    case rideInactivityPrompted
    case rideContinued
    case rideMovementResumed
    case rideEnded
    case locationSampleObserved
    case placeLookupStarted
    case placeLookupFinished
    case placeLookupFailed
    case placeLookupCancelled
    case factGenerationStarted
    case factGenerationFinished
    case announcementTextReady
    case announcementQueued
    case announcementDeferred
    // Legacy decode-only events retained so exports from superseded beta builds remain readable.
    case announcementRestartScheduled
    case boundedAudioWaitExpired
    case announcementRestarted
    case announcementSuperseded
    case announcementCancelled
    case announcementFailed
    case ttsRequested
    case speechAudioReady
    case audioPlaybackStarted
    case audioPlaybackFinished
    case audioPlaybackCancelled
    case audioSessionActivated
    case audioSessionActivationFailed
    case audioSessionReleased
    case audioSessionReleaseFailed
    case audioSessionNeutralized
    case audioSessionNeutralizationFailed
    case audioInterruptionBegan
    case audioInterruptionEnded
    case primaryAudioBegan
    case primaryAudioEnded
    case audioRouteChanged
    case audioMediaServicesReset
}

enum RideDiagnosticReason: String, Codable, Equatable {
    case factAvailable
    case factUnavailable
    case primaryAudioActive
    case primaryAudioEnded
    // Legacy decode-only reason retained so exports from superseded beta builds remain readable.
    case boundedWaitExpired
    case interruptionBegan
    case interruptionShouldResume
    case interruptionMustNotResume
    case supersededByHigherPriority
    case supersededByNewerContext
    case rideEnded
    case settingsChanged
    case inactivityPrompted
    case playbackCompleted
    case playbackCancelled
    case playbackFailed
    case mediaServicesReset
    case deactivationRetry
    case deactivationRecovery
}

enum DiagnosticRideState: String, Codable, Equatable {
    case idle
    case riding
    case awaitingConfirmation
}

enum DiagnosticPlaybackPath: String, Codable, Equatable {
    case apple
    case premiumVoice
}

enum DiagnosticAppState: String, Codable, Equatable {
    case foreground
    case background
}

struct AudioSessionSnapshot: Codable, Equatable {
    let outputVolume: Float
    let outputRouteTypes: [String]
    let isOtherAudioPlaying: Bool
    let shouldYieldToPrimaryAudio: Bool
    let category: String?
    let mode: String?
    let options: [String]?

    init(
        outputVolume: Float,
        outputRouteTypes: [String],
        isOtherAudioPlaying: Bool,
        shouldYieldToPrimaryAudio: Bool,
        category: String? = nil,
        mode: String? = nil,
        options: [String]? = nil
    ) {
        self.outputVolume = outputVolume
        self.outputRouteTypes = outputRouteTypes
        self.isOtherAudioPlaying = isOtherAudioPlaying
        self.shouldYieldToPrimaryAudio = shouldYieldToPrimaryAudio
        self.category = category
        self.mode = mode
        self.options = options
    }
}

enum DiagnosticNetworkStatus: String, Codable, Equatable, Sendable {
    case satisfied
    case unsatisfied
    case requiresConnection
}

enum DiagnosticNetworkInterface: String, Codable, Equatable, Sendable {
    case cellular
    case wifi
    case wiredEthernet
    case loopback
    case other
}

enum DiagnosticNetworkLinkQuality: String, Codable, Equatable, Sendable {
    case unknown
    case minimal
    case moderate
    case good
}

/// Public, coarse connectivity metadata only. This schema deliberately cannot carry
/// carrier identity, SIM/service identifiers, IP addresses or radio signal values.
struct NetworkPathSnapshot: Codable, Equatable, Sendable {
    let status: DiagnosticNetworkStatus
    let interfaceTypes: [DiagnosticNetworkInterface]
    let isExpensive: Bool
    let isConstrained: Bool
    let linkQuality: DiagnosticNetworkLinkQuality?
}

private final class NetworkPathDiagnosticMonitor: @unchecked Sendable {
    static let shared = NetworkPathDiagnosticMonitor()

    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var latestSnapshot: NetworkPathSnapshot?

    var snapshot: NetworkPathSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return latestSnapshot
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let snapshot = Self.makeSnapshot(from: path)
            self.lock.lock()
            self.latestSnapshot = snapshot
            self.lock.unlock()
        }
        monitor.start(queue: DispatchQueue(
            label: "ai.digitalmercenaries.ridehorizon.network-diagnostics",
            qos: .utility
        ))
    }

    deinit {
        monitor.cancel()
    }

    private static func makeSnapshot(from path: NWPath) -> NetworkPathSnapshot {
        let status: DiagnosticNetworkStatus = switch path.status {
        case .satisfied:
            .satisfied
        case .unsatisfied:
            .unsatisfied
        case .requiresConnection:
            .requiresConnection
        @unknown default:
            .unsatisfied
        }

        let candidates: [(NWInterface.InterfaceType, DiagnosticNetworkInterface)] = [
            (.cellular, .cellular),
            (.wifi, .wifi),
            (.wiredEthernet, .wiredEthernet),
            (.loopback, .loopback),
            (.other, .other)
        ]
        let interfaceTypes = candidates.compactMap { type, diagnosticType in
            path.usesInterfaceType(type) ? diagnosticType : nil
        }

        let linkQuality: DiagnosticNetworkLinkQuality?
        if #available(iOS 26.0, *) {
            linkQuality = switch path.linkQuality {
            case .unknown:
                .unknown
            case .minimal:
                .minimal
            case .moderate:
                .moderate
            case .good:
                .good
            @unknown default:
                .unknown
            }
        } else {
            linkQuality = nil
        }

        return NetworkPathSnapshot(
            status: status,
            interfaceTypes: interfaceTypes,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            linkQuality: linkQuality
        )
    }
}

struct RideDiagnosticEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let sequenceNumber: UInt64?
    let diagnosticSessionID: UUID?
    let rideSessionID: UUID?
    let placeLookupID: UUID?
    let announcementID: UUID?
    let event: RideDiagnosticEvent
    let reason: RideDiagnosticReason?
    let appState: DiagnosticAppState?
    let audio: AudioSessionSnapshot?
    let network: NetworkPathSnapshot?
    let audioPolicy: AudioCoexistencePolicy?
    let elapsedRideSeconds: TimeInterval?
    let rideState: DiagnosticRideState?
    let isLocationTracking: Bool?
    let playbackPath: DiagnosticPlaybackPath?
    let interruptionReason: UInt?
    let shouldResume: Bool?
    let routeChangeReason: UInt?
    let horizontalAccuracyMetres: Double?
    let locationSampleAgeSeconds: TimeInterval?
}

/// A privacy-safe, local-only release log. Its typed schema cannot accept coordinates,
/// announcement text, credentials or third-party audio content.
@MainActor
final class RideDiagnosticsStore: ObservableObject {
    private final class PersistenceTicket {
        private let lock = NSLock()
        private var cancelled = false

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }

        var shouldProceed: Bool {
            lock.lock()
            defer { lock.unlock() }
            return !cancelled
        }
    }

    static let shared = RideDiagnosticsStore()

    @Published private(set) var entries: [RideDiagnosticEntry] = []

    let exportURL: URL
    private let now: () -> Date
    private let maxEntries: Int
    private let maxAge: TimeInterval
    private let maxBytes: Int
    private let persistenceDelay: TimeInterval
    private let persistenceWillWrite: (([RideDiagnosticEntry]) -> Void)?
    private let networkSnapshotProvider: () -> NetworkPathSnapshot?
    private let persistenceQueue = DispatchQueue(
        label: "ai.digitalmercenaries.ridehorizon.diagnostics",
        qos: .utility
    )
    private var pendingPersistence: (workItem: DispatchWorkItem, ticket: PersistenceTicket)?
    private var encodedSizes: [UUID: Int] = [:]
    private let diagnosticSessionID = UUID()
    private var nextSequenceNumber: UInt64 = 1

    init(
        directoryURL: URL? = nil,
        now: @escaping () -> Date = Date.init,
        maxEntries: Int = 2_000,
        maxAge: TimeInterval = 7 * 24 * 60 * 60,
        maxBytes: Int = 1_048_576,
        persistenceDelay: TimeInterval = 1,
        persistenceWillWrite: (([RideDiagnosticEntry]) -> Void)? = nil,
        networkSnapshotProvider: @escaping () -> NetworkPathSnapshot? = {
            NetworkPathDiagnosticMonitor.shared.snapshot
        }
    ) {
        let directory = directoryURL ?? FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("RideHorizon", isDirectory: true)
        self.exportURL = directory.appendingPathComponent("ride-diagnostics.json")
        self.now = now
        self.maxEntries = maxEntries
        self.maxAge = maxAge
        self.maxBytes = maxBytes
        self.persistenceDelay = persistenceDelay
        self.persistenceWillWrite = persistenceWillWrite
        self.networkSnapshotProvider = networkSnapshotProvider

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        Self.excludeFromBackup(directory)
        loadAndPrune()
    }

    func record(
        _ event: RideDiagnosticEvent,
        rideSessionID: UUID? = nil,
        placeLookupID: UUID? = nil,
        announcementID: UUID? = nil,
        reason: RideDiagnosticReason? = nil,
        appState: DiagnosticAppState? = nil,
        audio: AudioSessionSnapshot? = nil,
        audioPolicy: AudioCoexistencePolicy? = nil,
        elapsedRideSeconds: TimeInterval? = nil,
        rideState: DiagnosticRideState? = nil,
        isLocationTracking: Bool? = nil,
        playbackPath: DiagnosticPlaybackPath? = nil,
        interruptionReason: UInt? = nil,
        shouldResume: Bool? = nil,
        routeChangeReason: UInt? = nil,
        horizontalAccuracyMetres: Double? = nil,
        locationSampleAgeSeconds: TimeInterval? = nil,
        at timestamp: Date? = nil
    ) {
        let shouldCaptureNetwork = switch event {
        case .factGenerationStarted, .factGenerationFinished:
            true
        case .ttsRequested, .speechAudioReady, .announcementFailed:
            playbackPath == .premiumVoice
        default:
            false
        }
        let entry = RideDiagnosticEntry(
            id: UUID(),
            timestamp: timestamp ?? now(),
            sequenceNumber: nextSequenceNumber,
            diagnosticSessionID: diagnosticSessionID,
            rideSessionID: rideSessionID,
            placeLookupID: placeLookupID,
            announcementID: announcementID,
            event: event,
            reason: reason,
            appState: appState,
            audio: audio,
            network: shouldCaptureNetwork ? networkSnapshotProvider() : nil,
            audioPolicy: audioPolicy,
            elapsedRideSeconds: elapsedRideSeconds,
            rideState: rideState,
            isLocationTracking: isLocationTracking,
            playbackPath: playbackPath,
            interruptionReason: interruptionReason,
            shouldResume: shouldResume,
            routeChangeReason: routeChangeReason,
            horizontalAccuracyMetres: horizontalAccuracyMetres,
            locationSampleAgeSeconds: locationSampleAgeSeconds
        )
        nextSequenceNumber += 1
        entries.append(entry)
        encodedSizes[entry.id] = Self.encodedSize(of: entry)
        prune(referenceDate: now())
        let terminalEvent: Bool = switch event {
        case .appEnteredBackground,
             .rideEnded,
             .placeLookupFailed,
             .placeLookupCancelled,
             .announcementCancelled,
             .announcementFailed,
             .audioPlaybackFinished,
             .audioPlaybackCancelled,
             .audioSessionActivationFailed,
             .audioSessionReleased,
             .audioSessionReleaseFailed,
             .audioSessionNeutralized,
             .audioSessionNeutralizationFailed:
            true
        default:
            false
        }
        schedulePersistence(immediately: terminalEvent)
    }

    func clear() {
        entries.removeAll()
        encodedSizes.removeAll()
        pendingPersistence?.ticket.cancel()
        pendingPersistence?.workItem.cancel()
        pendingPersistence = nil
        let url = exportURL
        persistenceQueue.sync {
            Self.persist([], to: url)
        }
    }

#if DEBUG
    func flushForTesting() {
        pendingPersistence?.ticket.cancel()
        pendingPersistence?.workItem.cancel()
        pendingPersistence = nil
        let snapshot = entries
        let url = exportURL
        persistenceQueue.sync {
            Self.persist(snapshot, to: url)
        }
    }
#endif

    private func loadAndPrune() {
        if let data = try? Data(contentsOf: exportURL),
           let decoded = try? Self.makeDecoder().decode([RideDiagnosticEntry].self, from: data) {
            entries = decoded
            encodedSizes = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, Self.encodedSize(of: $0)) })
            nextSequenceNumber = (decoded.compactMap(\.sequenceNumber).max() ?? 0) + 1
        }
        prune(referenceDate: now())
        Self.persist(entries, to: exportURL)
    }

    private func prune(referenceDate: Date) {
        let cutoff = referenceDate.addingTimeInterval(-maxAge)
        entries.removeAll { entry in
            guard entry.timestamp < cutoff else { return false }
            encodedSizes[entry.id] = nil
            return true
        }
        while entries.count > maxEntries {
            encodedSizes[entries.removeFirst().id] = nil
        }
        while !entries.isEmpty, encodedByteCount > maxBytes {
            encodedSizes[entries.removeFirst().id] = nil
        }
    }

    private var encodedByteCount: Int {
        guard !entries.isEmpty else { return 2 }
        return 2 + entries.reduce(0) { $0 + (encodedSizes[$1.id] ?? 0) } + entries.count - 1
    }

    private func schedulePersistence(immediately: Bool) {
        pendingPersistence?.ticket.cancel()
        pendingPersistence?.workItem.cancel()
        let ticket = PersistenceTicket()
        let snapshot = entries
        let url = exportURL
        let persistenceWillWrite = persistenceWillWrite
        let workItem = DispatchWorkItem {
            guard ticket.shouldProceed else { return }
            persistenceWillWrite?(snapshot)
            Self.persist(snapshot, to: url)
        }
        pendingPersistence = (workItem, ticket)
        persistenceQueue.asyncAfter(
            deadline: .now() + (immediately ? 0 : persistenceDelay),
            execute: workItem
        )
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601String(from: date, includingFractionalSeconds: true))
        }
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = iso8601Date(from: value, includingFractionalSeconds: true)
                ?? iso8601Date(from: value, includingFractionalSeconds: false) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO-8601 timestamp."
            )
        }
        return decoder
    }

    private nonisolated static func iso8601String(
        from date: Date,
        includingFractionalSeconds: Bool
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = includingFractionalSeconds
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private nonisolated static func iso8601Date(
        from value: String,
        includingFractionalSeconds: Bool
    ) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = includingFractionalSeconds
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func encodedSize(of entry: RideDiagnosticEntry) -> Int {
        (try? makeEncoder().encode(entry).count) ?? 0
    }

    private static func persist(_ entries: [RideDiagnosticEntry], to url: URL) {
        guard let data = try? makeEncoder().encode(entries) else { return }
        do {
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            excludeFromBackup(url)
        } catch {
            AppDiagnostics.log("Release diagnostics persistence failed.")
        }
    }

    private static func excludeFromBackup(_ url: URL) {
        var resourceURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? resourceURL.setResourceValues(values)
    }
}
