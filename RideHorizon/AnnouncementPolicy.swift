import Foundation

enum BoundaryChangeDetector {
    static func changedBoundaries(from previous: Address, to current: Address, settings: BoundaryAnnouncementSettings) -> [BoundaryType] {
        var changes = [BoundaryType]()

        if settings.announceCountry,
           previous.country != current.country,
           Address.isValidPlaceName(current.country) {
            changes.append(.country)
        }
        if settings.announceNation,
           previous.administrativeArea != current.administrativeArea,
           Address.isValidPlaceName(current.administrativeArea) {
            changes.append(.nation)
        }
        if settings.announceCounty,
           previous.county != current.county,
           Address.isValidPlaceName(current.county) {
            changes.append(.county)
        }
        if settings.announceTown,
           previous.town != current.town,
           Address.isValidPlaceName(current.town) {
            changes.append(.town)
        }
        if settings.announceStreet,
           previous.street != current.street,
           Address.isValidPlaceName(current.street) {
            changes.append(.street)
        }

        return changes
    }

    static func highestPriorityChange(
        from previous: Address?,
        to current: Address,
        settings: BoundaryAnnouncementSettings
    ) -> BoundaryType? {
        guard let previous else { return nil }
        return changedBoundaries(from: previous, to: current, settings: settings).min()
    }
}

enum AnnouncementPhraseBuilder {
    static func baseSpeechMode(for mode: ContentMode) -> ContentMode {
        switch mode {
        case .shortFacts, .longFacts:
            return .natural
        case .natural, .namesOnly, .quiet:
            return mode
        }
    }

    static func phrase(
        for changes: [BoundaryType],
        address: Address,
        mode: ContentMode
    ) -> (text: String, boundary: BoundaryType)? {
        let speechMode = baseSpeechMode(for: mode)
        guard speechMode != .quiet, !changes.isEmpty else { return nil }
        guard let boundary = changes.min() else { return nil }

        guard let text = phrase(for: boundary, changes: changes, address: address, mode: speechMode) else {
            return nil
        }
        return (text, boundary)
    }

    static func phrase(
        for boundary: BoundaryType,
        changes: [BoundaryType],
        address: Address,
        mode: ContentMode
    ) -> String? {
        guard mode != .quiet else { return nil }

        if boundary == .street {
            let name = placeName(for: .street, in: address)
            guard Address.isValidPlaceName(name) else { return nil }
            return mode == .namesOnly ? name : name
        }

        let welcomeName = welcomeName(for: changes, in: address)
        let location = locationPhrase(in: address, mode: mode)

        switch mode {
        case .quiet:
            return nil
        case .namesOnly:
            return namesOnlyPhrase(welcomeName: welcomeName, location: location)
        case .natural, .shortFacts, .longFacts:
            return naturalPhrase(welcomeName: welcomeName, location: location)
        }
    }

    static func phrase(for boundary: BoundaryType, address: Address, mode: ContentMode) -> String? {
        phrase(for: boundary, changes: [boundary], address: address, mode: mode)
    }

    static func placeName(for boundary: BoundaryType, in address: Address) -> String {
        switch boundary {
        case .country: return address.country
        case .nation: return address.administrativeArea
        case .county: return address.county
        case .town: return address.town
        case .street: return address.street
        }
    }

    /// Nation/country for UK home nations; country when crossing an international border.
    private static func welcomeName(for changes: [BoundaryType], in address: Address) -> String? {
        if changes.contains(.country) {
            let country = address.country
            return Address.isValidPlaceName(country) ? country : nil
        }
        if changes.contains(.nation) {
            let nation = address.administrativeArea
            return Address.isValidPlaceName(nation) ? nation : nil
        }
        if changes.contains(.county) {
            let county = address.county
            return Address.isValidPlaceName(county) ? county : nil
        }
        return nil
    }

    static func locationPhrase(in address: Address, mode: ContentMode) -> String? {
        let town = Address.isValidPlaceName(address.town) ? address.town : nil
        let county = Address.isValidPlaceName(address.county) ? address.county : nil

        switch mode {
        case .quiet:
            return nil
        case .namesOnly:
            if let town, let county { return "\(town), \(county)" }
            if let town { return town }
            if let county { return county }
            return nil
        case .natural, .shortFacts, .longFacts:
            if let town, let county { return "You are in \(town), \(county)" }
            if let town { return "You are in \(town)" }
            if let county { return "You are in \(county)" }
            return nil
        }
    }

    private static func naturalPhrase(welcomeName: String?, location: String?) -> String? {
        switch (welcomeName, location) {
        case let (welcome?, location?):
            return "Welcome to \(welcome). \(location)"
        case let (welcome?, nil):
            return "Welcome to \(welcome)"
        case let (nil, location?):
            return location
        case (nil, nil):
            return nil
        }
    }

    private static func namesOnlyPhrase(welcomeName: String?, location: String?) -> String? {
        switch (welcomeName, location) {
        case let (welcome?, location?):
            return "\(welcome). \(location)"
        case let (welcome?, nil):
            return welcome
        case let (nil, location?):
            return location
        case (nil, nil):
            return nil
        }
    }
}

enum AnnouncementPolicy {
    static func plan(
        previous: Address?,
        current: Address,
        settings: BoundaryAnnouncementSettings,
        mode: ContentMode
    ) -> AnnouncementPlan? {
        guard mode != .quiet else { return nil }
        guard let previous else { return nil }

        let changes = BoundaryChangeDetector.changedBoundaries(
            from: previous,
            to: current,
            settings: settings
        )
        guard !changes.isEmpty else { return nil }

        guard let result = AnnouncementPhraseBuilder.phrase(
            for: changes,
            address: current,
            mode: mode
        ) else {
            return nil
        }
        return AnnouncementPlan(text: result.text, boundary: result.boundary)
    }

    static func factRequest(
        for plan: AnnouncementPlan,
        address: Address,
        mode: FactMode = .shortFacts,
        riderContext: RiderContext = .empty
    ) -> PlaceFactRequest {
        PlaceFactRequest(
            boundary: plan.boundary,
            placeName: AnnouncementPhraseBuilder.placeName(for: plan.boundary, in: address),
            factMode: mode,
            countryContext: Address.isValidPlaceName(address.country) ? address.country : nil,
            placeHierarchy: PlaceHierarchy(minimizing: address, for: plan.boundary),
            riderContext: riderContext
        )
    }
}

struct AnnouncementRequest: Equatable {
    let id: UUID
    let text: String
    let boundary: BoundaryType
}

struct AnnouncementQueue {
    private(set) var pending: AnnouncementRequest?

    mutating func replacePending(
        id: UUID = UUID(),
        text: String,
        boundary: BoundaryType
    ) -> AnnouncementRequest {
        let request = AnnouncementRequest(id: id, text: text, boundary: boundary)
        pending = request
        return request
    }

    mutating func clearPending(id: UUID) {
        if pending?.id == id {
            pending = nil
        }
    }

    mutating func clearPending() {
        pending = nil
    }
}

enum AnnouncementSupersession: Equatable {
    case rejectLowerPriority
    case supersede(announcementIDs: Set<UUID>)
}

@MainActor
protocol AnnouncementScheduling: AnyObject {
    func schedule(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void)
    func cancel()
}

@MainActor
final class DispatchAnnouncementScheduler: AnnouncementScheduling {
    private var workItem: DispatchWorkItem?

    func schedule(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        cancel()
        let workItem = DispatchWorkItem(block: action)
        self.workItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}

struct AnnouncementFactWork: Equatable {
    let token: UUID
    let announcementID: UUID
    let boundary: BoundaryType
}

struct AnnouncementDiagnosticSignal: Equatable {
    let event: RideDiagnosticEvent
    let announcementID: UUID?
    let reason: RideDiagnosticReason?
    let audioPolicy: AudioCoexistencePolicy?
    let playbackPath: DiagnosticPlaybackPath?

    init(
        event: RideDiagnosticEvent,
        announcementID: UUID? = nil,
        reason: RideDiagnosticReason? = nil,
        audioPolicy: AudioCoexistencePolicy? = nil,
        playbackPath: DiagnosticPlaybackPath? = nil
    ) {
        self.event = event
        self.announcementID = announcementID
        self.reason = reason
        self.audioPolicy = audioPolicy
        self.playbackPath = playbackPath
    }
}

struct SpeechVoiceSelection: Equatable {
    let identifier: String
}

struct AnnouncementDeliveryContext {
    let selectedProvider: @MainActor () -> SpeechProvider
    let aiSharingAllowed: @MainActor () -> Bool
    let appleVoice: @MainActor () -> SpeechVoiceSelection?
    let allowAppleFallback: @MainActor () -> Bool
    let audioPolicy: @MainActor () -> AudioCoexistencePolicy
    let delay: TimeInterval
    let shouldRecordTestLog: Bool
}

struct AnnouncementWorkflowInput {
    let address: Address
    let settings: BoundaryAnnouncementSettings
    let mode: ContentMode
    let repeatPreferences: RepeatPreferences
    let speakAfterEveryGeocode: Bool
    let riderContext: RiderContext
    let delivery: AnnouncementDeliveryContext
    let boundaryCooldown: TimeInterval
    let now: Date
    let placeLookupID: UUID?
}

enum AnnouncementSubmissionOutcome: Equatable {
    case noAnnouncement
    case suppressed(plan: AnnouncementPlan, supersededAnnouncementIDs: Set<UUID>)
    case rejected(plan: AnnouncementPlan)
    case accepted(plan: AnnouncementPlan, supersededAnnouncementIDs: Set<UUID>)
}

@MainActor
protocol DiagnosticsSink: AnyObject {
    func record(_ signal: AnnouncementDiagnosticSignal)
}

@MainActor
final class AnnouncementDiagnosticsRelay: DiagnosticsSink {
    private var recorder: (@MainActor (AnnouncementDiagnosticSignal) -> Void)?

    func connect(_ recorder: @escaping @MainActor (AnnouncementDiagnosticSignal) -> Void) {
        self.recorder = recorder
    }

    func record(_ signal: AnnouncementDiagnosticSignal) {
        recorder?(signal)
    }
}

enum AnnouncementWorkflowResult: Equatable {
    case boundaryAccepted(announcementID: UUID, supersededAnnouncementIDs: Set<UUID>)
    case boundaryRejected(announcementID: UUID)
    case factRequested(announcementID: UUID)
    case factResolved(announcementID: UUID, factAvailable: Bool)
    case factCancelled(announcementID: UUID?)
    case announcementQueued(plan: AnnouncementPlan, placeLookupID: UUID?)
    case speechRequested(plan: AnnouncementPlan, provider: SpeechProvider, shouldRecordTestLog: Bool)
    case retryScheduled(announcementID: UUID, provider: SpeechProvider)
    case fallbackStarted(announcementID: UUID, provider: SpeechProvider)
    case playbackStarted(announcementID: UUID, provider: SpeechProvider)
    case deferred(announcementID: UUID, reason: RideDiagnosticReason)
    case interrupted(announcementID: UUID?, reason: RideDiagnosticReason)
    case resumed(announcementID: UUID)
    case completed(announcementID: UUID?)
    case cancelled(announcementID: UUID?, reason: RideDiagnosticReason)
    case failed(announcementID: UUID?, reason: RideDiagnosticReason)
}

enum AnnouncementPauseSource: Hashable {
    case interruption
    case primaryAudio

    var beganReason: RideDiagnosticReason {
        switch self {
        case .interruption: .interruptionBegan
        case .primaryAudio: .primaryAudioActive
        }
    }
}

/// Owns deterministic announcement queue and supersession sequencing. Provider,
/// audio-session and diagnostic adapters remain at the application composition edge.
@MainActor
final class AnnouncementCoordinator {
    private var queue = AnnouncementQueue()
    private(set) var factWork: AnnouncementFactWork?
    private let scheduler: AnnouncementScheduling
    private let audioReleaseScheduler: AnnouncementScheduling
    private let factClient: FactClient
    private let speechOutput: SpeechOutput
    private let audioSession: AudioSessionManaging
    private let diagnostics: DiagnosticsSink
    private var factTask: Task<Void, Never>?
    private var ownsAudioSession = false
    private var audioSessionReleaseRetryAttempts = 0
    private var audioPolicy: AudioCoexistencePolicy = .mix
    private var pendingCancellationReason: RideDiagnosticReason?
    private var fallbackInProgress = false
    private var terminalFailureInProgress = false
    private var pauseSources: Set<AnnouncementPauseSource> = []
    private var previousAddress: Address?
    private var lastBoundaryAnnouncementAt: Date?
    private var pendingDeliveryContext: AnnouncementDeliveryContext?
    private var pendingDeliveryReady = false
    private var activeDeliveryContext: AnnouncementDeliveryContext?
    private var interruptedDeliveryContext: AnnouncementDeliveryContext?
    private(set) var interruptedPlan: AnnouncementPlan?
    private(set) var activePlan: AnnouncementPlan?

    var onResult: ((AnnouncementWorkflowResult) -> Void)?
    var onDiagnosticNote: ((String) -> Void)?

    init(
        scheduler: AnnouncementScheduling,
        audioReleaseScheduler: AnnouncementScheduling,
        factClient: FactClient,
        speechOutput: SpeechOutput,
        audioSession: AudioSessionManaging,
        diagnostics: DiagnosticsSink
    ) {
        self.scheduler = scheduler
        self.audioReleaseScheduler = audioReleaseScheduler
        self.factClient = factClient
        self.speechOutput = speechOutput
        self.audioSession = audioSession
        self.diagnostics = diagnostics
        configureSpeechOutput()
    }

    var pending: AnnouncementRequest? { queue.pending }
    var isSpeaking: Bool { speechOutput.isSpeaking }
    var isPlayingAudio: Bool { speechOutput.isPlayingAudio }
    var isPausedForExternalAudio: Bool { !pauseSources.isEmpty }
    var currentBoundary: BoundaryType? { activePlan?.boundary ?? interruptedPlan?.boundary }

    @discardableResult
    func submit(_ input: AnnouncementWorkflowInput) -> AnnouncementSubmissionOutcome {
        let plan: AnnouncementPlan?
        if input.speakAfterEveryGeocode {
            plan = AnnouncementDecision.speechText(
                for: input.address,
                previous: previousAddress,
                preferences: input.repeatPreferences,
                speakAfterEveryGeocode: true
            ).map { AnnouncementPlan(text: $0, boundary: .town) }
        } else {
            plan = AnnouncementPolicy.plan(
                previous: previousAddress,
                current: input.address,
                settings: input.settings,
                mode: input.mode
            )
        }

        defer { previousAddress = input.address }
        guard let plan else { return .noAnnouncement }

        let acceptance = acceptBoundary(plan)
        guard case .boundaryAccepted(_, let supersededAnnouncementIDs) = acceptance else {
            return .rejected(plan: plan)
        }

        cancelSupersededWork(announcementIDs: supersededAnnouncementIDs)

        if !input.speakAfterEveryGeocode,
           input.boundaryCooldown > 0,
           let lastBoundaryAnnouncementAt,
           input.now.timeIntervalSince(lastBoundaryAnnouncementAt) < input.boundaryCooldown {
            return .suppressed(
                plan: plan,
                supersededAnnouncementIDs: supersededAnnouncementIDs
            )
        }

        lastBoundaryAnnouncementAt = input.now
        if let factMode = input.mode.factMode,
           input.delivery.aiSharingAllowed(),
           plan.boundary != .street {
            requestFact(
                for: plan,
                request: AnnouncementPolicy.factRequest(
                    for: plan,
                    address: input.address,
                    mode: factMode,
                    riderContext: input.riderContext
                ),
                mode: factMode,
                aiSharingAllowed: input.delivery.aiSharingAllowed
            ) { [weak self] resolvedPlan in
                self?.queueForDelivery(
                    resolvedPlan,
                    placeLookupID: input.placeLookupID,
                    delivery: input.delivery
                )
            }
        } else if input.mode != .quiet {
            queueForDelivery(
                plan,
                placeLookupID: input.placeLookupID,
                delivery: input.delivery
            )
        }

        return .accepted(plan: plan, supersededAnnouncementIDs: supersededAnnouncementIDs)
    }

    func resetContext() {
        previousAddress = nil
        lastBoundaryAnnouncementAt = nil
    }

    @discardableResult
    func acceptBoundary(
        _ plan: AnnouncementPlan,
        additionalActivePlans: [AnnouncementPlan] = []
    ) -> AnnouncementWorkflowResult {
        let supersedablePlans = [
            factWork.map { AnnouncementPlan(id: $0.announcementID, text: "", boundary: $0.boundary) },
            pending.map { AnnouncementPlan(id: $0.id, text: $0.text, boundary: $0.boundary) }
        ].compactMap { $0 }
        let protectedPlans = [
            activePlan,
            interruptedPlan
        ].compactMap { $0 }
        let activePlans = supersedablePlans + protectedPlans + additionalActivePlans
        let supersession = Self.supersession(
            newBoundary: plan.boundary,
            activeBoundaries: activePlans.map(\.boundary),
            supersedableAnnouncementIDs: supersedablePlans.map(\.id)
        )
        switch supersession {
        case .rejectLowerPriority:
            let result = AnnouncementWorkflowResult.boundaryRejected(announcementID: plan.id)
            onResult?(result)
            return result
        case .supersede(let announcementIDs):
            let result = AnnouncementWorkflowResult.boundaryAccepted(
                announcementID: plan.id,
                supersededAnnouncementIDs: announcementIDs
            )
            onResult?(result)
            return result
        }
    }

    func deferIfPaused(_ plan: AnnouncementPlan) -> AnnouncementWorkflowResult? {
        let source: AnnouncementPauseSource?
        if pauseSources.contains(.interruption) {
            source = .interruption
        } else if pauseSources.contains(.primaryAudio) {
            source = .primaryAudio
        } else {
            source = nil
        }
        guard let source else { return nil }
        interruptedPlan = plan
        let result = AnnouncementWorkflowResult.deferred(
            announcementID: plan.id,
            reason: source.beganReason
        )
        diagnostics.record(AnnouncementDiagnosticSignal(
            event: .announcementDeferred,
            announcementID: plan.id,
            reason: source.beganReason
        ))
        onResult?(result)
        return result
    }

    func externalAudioBegan(
        _ source: AnnouncementPauseSource,
        fallbackPlan: AnnouncementPlan? = nil
    ) -> AnnouncementWorkflowResult? {
        pauseSources.insert(source)
        let plan = activePlan
            ?? pending.map { AnnouncementPlan(id: $0.id, text: $0.text, boundary: $0.boundary) }
            ?? fallbackPlan
        guard let plan else { return nil }
        interruptedPlan = plan
        interruptedDeliveryContext = activeDeliveryContext ?? pendingDeliveryContext
        cancelPending()
        if isSpeaking || activePlan != nil {
            _ = cancelSpeech(reason: source.beganReason)
        }
        let result = AnnouncementWorkflowResult.interrupted(
            announcementID: plan.id,
            reason: source.beganReason
        )
        onResult?(result)
        return result
    }

    func externalAudioEnded(
        _ source: AnnouncementPauseSource,
        shouldResume: Bool,
        canResume: Bool = true
    ) -> AnnouncementWorkflowResult? {
        pauseSources.remove(source)
        if !shouldResume, let plan = interruptedPlan {
            interruptedPlan = nil
            interruptedDeliveryContext = nil
            let result = AnnouncementWorkflowResult.cancelled(
                announcementID: plan.id,
                reason: .interruptionMustNotResume
            )
            diagnostics.record(AnnouncementDiagnosticSignal(
                event: .announcementCancelled,
                announcementID: plan.id,
                reason: .interruptionMustNotResume
            ))
            onResult?(result)
            return result
        }
        guard pauseSources.isEmpty, let plan = interruptedPlan else { return nil }
        interruptedPlan = nil
        guard canResume, let delivery = interruptedDeliveryContext else {
            interruptedDeliveryContext = nil
            return nil
        }
        interruptedDeliveryContext = nil
        let result = AnnouncementWorkflowResult.resumed(announcementID: plan.id)
        diagnostics.record(AnnouncementDiagnosticSignal(
            event: .announcementRestarted,
            announcementID: plan.id,
            reason: source == .interruption ? .interruptionShouldResume : .primaryAudioEnded
        ))
        onResult?(result)
        _ = speak(plan, delivery: delivery)
        return result
    }

    func enqueue(id: UUID = UUID(), text: String, boundary: BoundaryType) -> AnnouncementRequest {
        queue.replacePending(id: id, text: text, boundary: boundary)
    }

    @discardableResult
    func schedule(
        _ plan: AnnouncementPlan,
        after delay: TimeInterval,
        delivery: @escaping @MainActor (UUID) -> Void
    ) -> AnnouncementRequest {
        let request = queue.replacePending(id: plan.id, text: plan.text, boundary: plan.boundary)
        pendingDeliveryReady = false
        scheduler.schedule(after: delay) { [weak self] in
            guard let self, self.pending?.id == request.id else { return }
            self.pendingDeliveryReady = true
            delivery(request.id)
        }
        return request
    }

    func cancelPending(id: UUID) {
        queue.clearPending(id: id)
        if queue.pending == nil {
            pendingDeliveryReady = false
            pendingDeliveryContext = nil
            scheduler.cancel()
        }
    }

    func cancelPending() {
        scheduler.cancel()
        queue.clearPending()
        pendingDeliveryReady = false
        pendingDeliveryContext = nil
    }

    func beginFact(for plan: AnnouncementPlan) -> AnnouncementFactWork {
        let work = AnnouncementFactWork(
            token: UUID(),
            announcementID: plan.id,
            boundary: plan.boundary
        )
        factWork = work
        return work
    }

    func requestFact(
        for plan: AnnouncementPlan,
        request: PlaceFactRequest,
        mode: FactMode,
        aiSharingAllowed: @escaping @MainActor () -> Bool,
        completion: @escaping @MainActor (AnnouncementPlan) -> Void
    ) {
        cancelFact(reason: .supersededByNewerContext)
        let work = beginFact(for: plan)
        diagnostics.record(AnnouncementDiagnosticSignal(
            event: .factGenerationStarted,
            announcementID: plan.id
        ))
        onResult?(.factRequested(announcementID: plan.id))
        factTask = Task { [weak self] in
            let fact = await PlaceFactFetcher.fact(for: request, using: factClient)
            await MainActor.run {
                guard let self,
                      !Task.isCancelled,
                      self.acceptsFactCompletion(token: work.token) else { return }
                self.factTask = nil
                self.finishFact(token: work.token)
                let factIsAvailable = aiSharingAllowed() && fact != nil
                self.diagnostics.record(AnnouncementDiagnosticSignal(
                    event: .factGenerationFinished,
                    announcementID: plan.id,
                    reason: factIsAvailable ? .factAvailable : .factUnavailable
                ))
                self.onResult?(.factResolved(
                    announcementID: plan.id,
                    factAvailable: factIsAvailable
                ))
                if aiSharingAllowed(), fact == nil {
                    self.diagnostics.record(AnnouncementDiagnosticSignal(
                        event: .announcementFailed,
                        announcementID: plan.id,
                        reason: .factUnavailable
                    ))
                }
                guard factIsAvailable, let fact else {
                    completion(plan)
                    return
                }
                completion(AnnouncementPlan(
                    id: plan.id,
                    text: FactPhraseBuilder.utterance(basePhrase: plan.text, fact: fact, mode: mode),
                    boundary: plan.boundary
                ))
            }
        }
    }

    func cancelFact(reason: RideDiagnosticReason) {
        let announcementID = factWork?.announcementID
        factTask?.cancel()
        factTask = nil
        factWork = nil
        guard announcementID != nil else { return }
        onResult?(.factCancelled(announcementID: announcementID))
        if reason == .rideEnded {
            diagnostics.record(AnnouncementDiagnosticSignal(
                event: .announcementCancelled,
                announcementID: announcementID,
                reason: reason
            ))
        }
    }

    func acceptsFactCompletion(token: UUID) -> Bool {
        factWork?.token == token
    }

    func finishFact(token: UUID) {
        guard factWork?.token == token else { return }
        factWork = nil
    }

    func invalidateAll() {
        cancelFact(reason: .rideEnded)
    }

    @discardableResult
    func speak(
        _ plan: AnnouncementPlan,
        selectedProvider: SpeechProvider,
        aiSharingAllowed: Bool,
        appleVoice: SpeechVoiceSelection?,
        allowAppleFallback: Bool,
        audioPolicy: AudioCoexistencePolicy,
        shouldRecordTestLog: Bool = true
    ) -> AnnouncementWorkflowResult {
        speak(
            plan,
            delivery: AnnouncementDeliveryContext(
                selectedProvider: { selectedProvider },
                aiSharingAllowed: { aiSharingAllowed },
                appleVoice: { appleVoice },
                allowAppleFallback: { allowAppleFallback },
                audioPolicy: { audioPolicy },
                delay: 0,
                shouldRecordTestLog: shouldRecordTestLog
            )
        )
    }

    @discardableResult
    func speak(
        _ plan: AnnouncementPlan,
        delivery: AnnouncementDeliveryContext
    ) -> AnnouncementWorkflowResult {
        if let deferred = deferIfPaused(plan) {
            interruptedDeliveryContext = delivery
            return deferred
        }
        activePlan = plan
        activeDeliveryContext = delivery
        fallbackInProgress = false
        terminalFailureInProgress = false
        self.audioPolicy = delivery.audioPolicy()
        let aiSharingAllowed = delivery.aiSharingAllowed()
        let provider: SpeechProvider = aiSharingAllowed ? delivery.selectedProvider() : .apple
        let result = AnnouncementWorkflowResult.speechRequested(
            plan: plan,
            provider: provider,
            shouldRecordTestLog: delivery.shouldRecordTestLog
        )
        onResult?(result)
        speechOutput.speak(
            text: plan.text,
            boundary: plan.boundary,
            provider: provider,
            appleVoice: delivery.appleVoice(),
            allowAppleFallback: aiSharingAllowed ? delivery.allowAppleFallback() : false,
            announcementID: plan.id
        )
        return result
    }

    @discardableResult
    func stop(reason: RideDiagnosticReason) -> AnnouncementWorkflowResult {
        let announcementID = activePlan?.id
        let wasSpeaking = isSpeaking
        pendingCancellationReason = reason
        speechOutput.stop()
        let result = AnnouncementWorkflowResult.cancelled(
            announcementID: announcementID,
            reason: reason
        )
        if wasSpeaking {
            return result
        }
        pendingCancellationReason = nil
        releaseAudioSession(announcementID: announcementID)
        activePlan = nil
        onResult?(result)
        return result
    }

    func cancelAll(reason: RideDiagnosticReason) -> [AnnouncementWorkflowResult] {
        var results: [AnnouncementWorkflowResult] = []
        if factWork != nil {
            let announcementID = factWork?.announcementID
            cancelFact(reason: reason)
            results.append(.factCancelled(announcementID: announcementID))
        }
        if pending != nil {
            let announcementID = pending?.id
            cancelPending()
            let result = AnnouncementWorkflowResult.cancelled(
                announcementID: announcementID,
                reason: reason
            )
            onResult?(result)
            if reason == .rideEnded {
                diagnostics.record(AnnouncementDiagnosticSignal(
                    event: .announcementCancelled,
                    announcementID: announcementID,
                    reason: reason
                ))
            }
            results.append(result)
        }
        if isSpeaking || activePlan != nil {
            results.append(cancelSpeech(reason: reason))
        } else if reason != .supersededByNewerContext {
            results.append(stop(reason: reason))
        }
        if let interruptedPlan {
            let result = AnnouncementWorkflowResult.cancelled(
                announcementID: interruptedPlan.id,
                reason: reason
            )
            if reason == .rideEnded {
                diagnostics.record(AnnouncementDiagnosticSignal(
                    event: .announcementCancelled,
                    announcementID: interruptedPlan.id,
                    reason: reason
                ))
            }
            onResult?(result)
            results.append(result)
        }
        interruptedPlan = nil
        interruptedDeliveryContext = nil
        pauseSources.removeAll()
        return results
    }

    func handleMediaServicesReset() {
        audioReleaseScheduler.cancel()
        audioSessionReleaseRetryAttempts = 0
        ownsAudioSession = false
    }

    private func queueForDelivery(
        _ plan: AnnouncementPlan,
        placeLookupID: UUID?,
        delivery: AnnouncementDeliveryContext
    ) {
        pendingDeliveryContext = delivery
        schedule(plan, after: delivery.delay) { [weak self] id in
            self?.deliver(id: id)
        }
        onResult?(.announcementQueued(plan: plan, placeLookupID: placeLookupID))
    }

    private func deliver(id: UUID) {
        guard let pending,
              pending.id == id,
              let delivery = pendingDeliveryContext else { return }
        guard !isSpeaking, (pauseSources.isEmpty || interruptedPlan == nil) else { return }
        let plan = AnnouncementPlan(id: pending.id, text: pending.text, boundary: pending.boundary)

        cancelPending(id: id)
        _ = speak(plan, delivery: delivery)
    }

    func resumeAfterMediaServicesReset() -> AnnouncementWorkflowResult? {
        pauseSources.removeAll()
        guard let plan = interruptedPlan else { return nil }
        interruptedPlan = nil
        let delivery = interruptedDeliveryContext
        interruptedDeliveryContext = nil
        let result = AnnouncementWorkflowResult.resumed(announcementID: plan.id)
        diagnostics.record(AnnouncementDiagnosticSignal(
            event: .announcementRestarted,
            announcementID: plan.id,
            reason: .mediaServicesReset
        ))
        onResult?(result)
        if let delivery { _ = speak(plan, delivery: delivery) }
        return result
    }

    private func cancelSpeech(reason: RideDiagnosticReason) -> AnnouncementWorkflowResult {
        guard !speechOutput.isPlayingAudio else {
            return stop(reason: reason)
        }
        let announcementID = activePlan?.id
        pendingCancellationReason = reason
        speechOutput.cancelPendingPreparation()
        return .cancelled(announcementID: announcementID, reason: reason)
    }

    static func supersession(
        newBoundary: BoundaryType,
        activeBoundaries: [BoundaryType],
        supersedableAnnouncementIDs: [UUID]
    ) -> AnnouncementSupersession {
        if let highestPriorityBoundary = activeBoundaries.min(), newBoundary > highestPriorityBoundary {
            return .rejectLowerPriority
        }
        return .supersede(announcementIDs: Set(supersedableAnnouncementIDs))
    }

    private func cancelSupersededWork(announcementIDs: Set<UUID>) {
        if let factWork, announcementIDs.contains(factWork.announcementID) {
            cancelFact(reason: .supersededByNewerContext)
        }
        if let pending, announcementIDs.contains(pending.id) {
            let announcementID = pending.id
            cancelPending()
            let result = AnnouncementWorkflowResult.cancelled(
                announcementID: announcementID,
                reason: .supersededByNewerContext
            )
            onResult?(result)
        }
    }

    private func configureSpeechOutput() {
        speechOutput.onPlaybackWillStart = { [weak self] provider in
            self?.acquireAudioSession(provider: provider) ?? false
        }
        speechOutput.onFinish = { [weak self] in
            self?.finishSpeech(cancelled: false)
        }
        speechOutput.onCancel = { [weak self] in
            self?.finishSpeech(cancelled: true)
        }
        speechOutput.onDiagnosticNote = { [weak self] note in
            guard let self else { return }
            self.onDiagnosticNote?(note)
            guard !self.fallbackInProgress else { return }
            self.terminalFailureInProgress = true
            let announcementID = self.activePlan?.id
            self.diagnostics.record(AnnouncementDiagnosticSignal(
                event: .announcementFailed,
                announcementID: announcementID,
                reason: .playbackFailed,
                playbackPath: .premiumVoice
            ))
            self.onResult?(.failed(announcementID: announcementID, reason: .playbackFailed))
        }
        speechOutput.onPipelineEvent = { [weak self] event in
            self?.handlePipelineEvent(event)
        }
    }

    private func acquireAudioSession(provider: SpeechProvider) -> Bool {
        audioReleaseScheduler.cancel()
        do {
            if !ownsAudioSession {
                try audioSession.activate(policy: audioPolicy)
                ownsAudioSession = true
                diagnostics.record(AnnouncementDiagnosticSignal(
                    event: .audioSessionActivated,
                    announcementID: activePlan?.id,
                    audioPolicy: audioPolicy
                ))
            }
            diagnostics.record(AnnouncementDiagnosticSignal(
                event: .audioPlaybackStarted,
                announcementID: activePlan?.id,
                audioPolicy: audioPolicy,
                playbackPath: provider == .apple ? .apple : .premiumVoice
            ))
            if let announcementID = activePlan?.id {
                onResult?(.playbackStarted(announcementID: announcementID, provider: provider))
            }
            return true
        } catch {
            diagnostics.record(AnnouncementDiagnosticSignal(
                event: .audioSessionActivationFailed,
                announcementID: activePlan?.id,
                audioPolicy: audioPolicy
            ))
            onResult?(.failed(announcementID: activePlan?.id, reason: .playbackFailed))
            return false
        }
    }

    private func finishSpeech(cancelled: Bool) {
        let announcementID = activePlan?.id
        let cancellationReason = pendingCancellationReason ?? .playbackCancelled
        let terminalFailure = terminalFailureInProgress
        pendingCancellationReason = nil
        fallbackInProgress = false
        terminalFailureInProgress = false
        activePlan = nil
        activeDeliveryContext = nil
        diagnostics.record(AnnouncementDiagnosticSignal(
            event: cancelled ? .audioPlaybackCancelled : .audioPlaybackFinished,
            announcementID: announcementID,
            reason: cancelled ? cancellationReason : .playbackCompleted
        ))
        releaseAudioSession(announcementID: announcementID)
        if cancelled {
            onResult?(.cancelled(announcementID: announcementID, reason: cancellationReason))
        } else if !terminalFailure {
            onResult?(.completed(announcementID: announcementID))
        }
        if !cancelled, pendingDeliveryReady, let pending {
            deliver(id: pending.id)
        }
    }

    private func releaseAudioSession(announcementID: UUID?) {
        guard ownsAudioSession else { return }
        audioReleaseScheduler.cancel()
        do {
            try audioSession.deactivate()
            ownsAudioSession = false
            audioSessionReleaseRetryAttempts = 0
            diagnostics.record(AnnouncementDiagnosticSignal(
                event: .audioSessionReleased,
                announcementID: announcementID,
                audioPolicy: audioPolicy
            ))
        } catch {
            diagnostics.record(AnnouncementDiagnosticSignal(
                event: .audioSessionReleaseFailed,
                announcementID: announcementID,
                reason: .deactivationRetry,
                audioPolicy: audioPolicy
            ))
            guard audioSessionReleaseRetryAttempts < 2 else {
                let neutralized = audioSession.neutralizeAfterDeactivationFailure()
                if neutralized {
                    ownsAudioSession = false
                    audioSessionReleaseRetryAttempts = 0
                }
                diagnostics.record(AnnouncementDiagnosticSignal(
                    event: neutralized ? .audioSessionNeutralized : .audioSessionNeutralizationFailed,
                    announcementID: announcementID,
                    reason: .deactivationRecovery,
                    audioPolicy: neutralized ? .mix : audioPolicy
                ))
                return
            }
            audioSessionReleaseRetryAttempts += 1
            audioReleaseScheduler.schedule(after: 0.5) { [weak self] in
                self?.releaseAudioSession(announcementID: announcementID)
            }
        }
    }

    private func handlePipelineEvent(_ event: SpeechOutputPipelineEvent) {
        let diagnosticEvent: RideDiagnosticEvent
        let result: AnnouncementWorkflowResult?
        switch event.stage {
        case .ttsRequested:
            diagnosticEvent = .ttsRequested
            result = nil
        case .speechAudioReady:
            diagnosticEvent = .speechAudioReady
            result = nil
        case .retryScheduled:
            diagnosticEvent = .ttsRequested
            result = .retryScheduled(announcementID: event.announcementID, provider: event.provider)
        case .fallbackStarted:
            diagnosticEvent = .ttsRequested
            fallbackInProgress = true
            result = .fallbackStarted(announcementID: event.announcementID, provider: .apple)
        }
        diagnostics.record(AnnouncementDiagnosticSignal(
            event: diagnosticEvent,
            announcementID: event.announcementID,
            playbackPath: event.provider == .apple ? .apple : .premiumVoice
        ))
        if let result { onResult?(result) }
    }
}
