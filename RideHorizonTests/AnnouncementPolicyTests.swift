import XCTest
import AVFoundation
@testable import RideHorizon

final class AnnouncementPolicyTests: XCTestCase {
    private let gloucester = Address(
        street: "High Street",
        town: "Stroud",
        county: "Gloucestershire",
        administrativeArea: "England",
        country: "United Kingdom"
    )

    private let stonehouse = Address(
        street: "Bristol Road",
        town: "Stonehouse",
        county: "Gloucestershire",
        administrativeArea: "England",
        country: "United Kingdom"
    )

    private let walesTown = Address(
        street: "High Street",
        town: "Chepstow",
        county: "Monmouthshire",
        administrativeArea: "Wales",
        country: "United Kingdom"
    )

    private let franceTown = Address(
        street: "Rue de la Gare",
        town: "Calais",
        county: "Pas-de-Calais",
        administrativeArea: "Hauts-de-France",
        country: "France"
    )

    private let ridingSettings = BoundaryAnnouncementSettings.ridingDefaults

    func testTownChangeUsesPlainNameInNaturalMode() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: stonehouse,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertEqual(plan?.text, "You are in Stonehouse, Gloucestershire")
        XCTAssertEqual(plan?.boundary, .town)
    }

    func testSubLocalityChangeUsesTheExistingTownAnnouncement() {
        let kingston = Address(
            street: "Brighton Road",
            town: "Kingston upon Thames",
            county: "Greater London",
            administrativeArea: "England",
            country: "United Kingdom",
            locality: "Kingston upon Thames"
        )
        let surbiton = Address(
            street: "Brighton Road",
            town: "Surbiton",
            county: "Greater London",
            administrativeArea: "England",
            country: "United Kingdom",
            subLocality: "Surbiton",
            locality: "Kingston upon Thames"
        )

        let plan = AnnouncementPolicy.plan(
            previous: kingston,
            current: surbiton,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertEqual(plan?.boundary, .town)
        XCTAssertEqual(plan?.text, "You are in Surbiton, Greater London")
    }

    func testCountyChangeUsesWelcomePhrase() {
        let sameTownNewCounty = Address(
            street: "High Street",
            town: "Stroud",
            county: "South Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        )
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: sameTownNewCounty,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertEqual(plan?.text, "Welcome to South Gloucestershire. You are in Stroud, South Gloucestershire")
        XCTAssertEqual(plan?.boundary, .county)
    }

    func testNationAndCountyChangeUsesTwoSentenceWelcomePhrase() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: walesTown,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertEqual(plan?.text, "Welcome to Wales. You are in Chepstow, Monmouthshire")
        XCTAssertEqual(plan?.boundary, .nation)
    }

    func testCountryAndCountyChangeUsesTwoSentenceWelcomePhrase() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: franceTown,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertEqual(plan?.text, "Welcome to France. You are in Calais, Pas-de-Calais")
        XCTAssertEqual(plan?.boundary, .country)
    }

    func testNationChangeUsesWelcomePhrase() {
        let sameCountyNewNation = Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "Wales",
            country: "United Kingdom"
        )
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: sameCountyNewNation,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertEqual(plan?.text, "Welcome to Wales. You are in Stroud, Gloucestershire")
        XCTAssertEqual(plan?.boundary, .nation)
    }

    func testNamesOnlyModeUsesPlainHierarchy() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: walesTown,
            settings: ridingSettings,
            mode: .namesOnly
        )

        XCTAssertEqual(plan?.text, "Wales. Chepstow, Monmouthshire")
        XCTAssertEqual(plan?.boundary, .nation)
    }

    func testWelcomeBoundaryChangeIncludesTownInLocationPhrase() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: walesTown,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertTrue(plan?.text.contains("Chepstow") == true)
    }

    func testQuietModeProducesNoPlan() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: stonehouse,
            settings: ridingSettings,
            mode: .quiet
        )

        XCTAssertNil(plan)
    }

    func testNoPlanOnFirstAddress() {
        let plan = AnnouncementPolicy.plan(
            previous: nil,
            current: gloucester,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertNil(plan)
    }

    func testNoPlanWhenAddressUnchanged() {
        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: gloucester,
            settings: ridingSettings,
            mode: .natural
        )

        XCTAssertNil(plan)
    }

    func testDisabledTownAnnouncementsAreIgnored() {
        var settings = ridingSettings
        settings.announceTown = false

        let plan = AnnouncementPolicy.plan(
            previous: gloucester,
            current: stonehouse,
            settings: settings,
            mode: .natural
        )

        XCTAssertNil(plan)
    }

    func testFactRequestOmitsStreetAndLowerPriorityPlaceData() {
        let countyPlan = AnnouncementPlan(text: "Welcome to Gloucestershire", boundary: .county)

        let request = AnnouncementPolicy.factRequest(for: countyPlan, address: gloucester)

        XCTAssertNil(request.placeHierarchy.street)
        XCTAssertNil(request.placeHierarchy.town)
        XCTAssertEqual(request.placeHierarchy.county, "Gloucestershire")
        XCTAssertEqual(request.placeHierarchy.region, "England")
        XCTAssertEqual(request.placeHierarchy.country, "United Kingdom")
    }
}

final class AnnouncementQueueTests: XCTestCase {
    func testReplacePendingKeepsOnlyLatestRequest() {
        var queue = AnnouncementQueue()
        let first = queue.replacePending(text: "You are in Stroud, Gloucestershire", boundary: .town)
        let second = queue.replacePending(text: "Welcome to Gloucestershire. You are in Stroud, Gloucestershire", boundary: .county)

        XCTAssertEqual(queue.pending?.id, second.id)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(queue.pending?.text, "Welcome to Gloucestershire. You are in Stroud, Gloucestershire")
    }

    func testShouldDropLowerPriorityWhileSpeaking() {
        XCTAssertTrue(
            AnnouncementQueue.shouldDropWhileSpeaking(
                newBoundary: .town,
                currentlySpeaking: .county
            )
        )
        XCTAssertFalse(
            AnnouncementQueue.shouldDropWhileSpeaking(
                newBoundary: .county,
                currentlySpeaking: .town
            )
        )
    }

    func testShouldInterruptForHigherPriorityBoundary() {
        XCTAssertTrue(
            AnnouncementQueue.shouldInterrupt(
                newBoundary: .nation,
                currentlySpeaking: .town
            )
        )
        XCTAssertFalse(
            AnnouncementQueue.shouldInterrupt(
                newBoundary: .town,
                currentlySpeaking: .nation
            )
        )
    }

    func testClearPendingOnlyClearsMatchingRequest() {
        var queue = AnnouncementQueue()
        let request = queue.replacePending(text: "Welcome to Wales. You are in Chepstow, Monmouthshire", boundary: .nation)

        queue.clearPending(id: UUID())
        XCTAssertEqual(queue.pending?.id, request.id)

        queue.clearPending(id: request.id)
        XCTAssertNil(queue.pending)
    }
}

@MainActor
final class AnnouncementCoordinatorTests: XCTestCase {
    private func makeCoordinator(
        scheduler: AnnouncementScheduling? = nil,
        audioReleaseScheduler: AnnouncementScheduling? = nil,
        factClient: FactClient? = nil,
        speechOutput: SpeechOutput? = nil,
        audioSession: AudioSessionManaging? = nil,
        diagnostics: DiagnosticsSink? = nil
    ) -> AnnouncementCoordinator {
        AnnouncementCoordinator(
            scheduler: scheduler ?? RecordingAnnouncementScheduler(),
            audioReleaseScheduler: audioReleaseScheduler ?? RecordingAnnouncementScheduler(),
            factClient: factClient ?? StubFactClient(result: nil),
            speechOutput: speechOutput ?? RecordingCoordinatorSpeechOutput(),
            audioSession: audioSession ?? RecordingCoordinatorAudioSession(),
            diagnostics: diagnostics ?? RecordingDiagnosticsSink()
        )
    }

    func testEnqueueKeepsOneSupersedablePendingAnnouncement() {
        let coordinator = makeCoordinator()
        let town = coordinator.enqueue(text: "Stroud", boundary: .town)
        let county = coordinator.enqueue(text: "Gloucestershire", boundary: .county)

        XCTAssertEqual(coordinator.pending, county)
        XCTAssertNotEqual(town.id, county.id)
        coordinator.cancelPending(id: town.id)
        XCTAssertEqual(coordinator.pending, county)
        coordinator.cancelPending(id: county.id)
        XCTAssertNil(coordinator.pending)
    }

    func testLowerPriorityContextCannotSupersedeHigherPriorityWork() {
        XCTAssertEqual(
            AnnouncementCoordinator.supersession(
                newBoundary: .town,
                activeBoundaries: [.county],
                activeAnnouncementIDs: [UUID()]
            ),
            .rejectLowerPriority
        )
    }

    func testHigherPriorityContextReturnsEveryWorkItemToCancel() {
        let factID = UUID()
        let speechID = UUID()

        XCTAssertEqual(
            AnnouncementCoordinator.supersession(
                newBoundary: .country,
                activeBoundaries: [.town, .county],
                activeAnnouncementIDs: [factID, speechID, factID]
            ),
            .supersede(announcementIDs: [factID, speechID])
        )
    }


    func testCancelledFactWorkCannotCompleteAfterSupersession() {
        let coordinator = makeCoordinator()
        let work = coordinator.beginFact(
            for: AnnouncementPlan(text: "Stroud", boundary: .town)
        )
        XCTAssertTrue(coordinator.acceptsFactCompletion(token: work.token))

        coordinator.invalidateAll()

        XCTAssertFalse(coordinator.acceptsFactCompletion(token: work.token))
        XCTAssertNil(coordinator.factWork)
    }

    func testScheduledReplacementDeliversOnlyLatestAnnouncement() {
        let scheduler = RecordingAnnouncementScheduler()
        let coordinator = makeCoordinator(scheduler: scheduler)
        var delivered: [UUID] = []
        let first = AnnouncementPlan(text: "Stroud", boundary: .town)
        let second = AnnouncementPlan(text: "Gloucestershire", boundary: .county)

        coordinator.schedule(first, after: 0.5) { delivered.append($0) }
        coordinator.schedule(second, after: 0.5) { delivered.append($0) }
        scheduler.fire()

        XCTAssertEqual(delivered, [second.id])
        XCTAssertEqual(coordinator.pending?.id, second.id)
    }

    func testCancellationPreventsScheduledDelivery() {
        let scheduler = RecordingAnnouncementScheduler()
        let coordinator = makeCoordinator(scheduler: scheduler)
        var delivered: [UUID] = []
        coordinator.schedule(
            AnnouncementPlan(text: "Stroud", boundary: .town),
            after: 0.5
        ) { delivered.append($0) }

        coordinator.cancelPending()
        scheduler.fire()

        XCTAssertTrue(delivered.isEmpty)
        XCTAssertTrue(scheduler.didCancel)
    }

    func testDeliveryDecisionMakesInterruptionExplicit() {
        XCTAssertEqual(
            AnnouncementCoordinator.deliveryDecision(newBoundary: .country, activeBoundary: .town),
            .interruptThenDeliver
        )
        XCTAssertEqual(
            AnnouncementCoordinator.deliveryDecision(newBoundary: .town, activeBoundary: .country),
            .drop
        )
        XCTAssertEqual(
            AnnouncementCoordinator.deliveryDecision(newBoundary: .town, activeBoundary: nil),
            .deliver
        )
    }

    func testFactClientIsOwnedByCoordinatorAndProducesResolvedPlan() async {
        let factClient = StubFactClient(result: "Stroud grew around its woollen mills")
        let speechOutput = RecordingCoordinatorSpeechOutput()
        let audioSession = RecordingCoordinatorAudioSession()
        let diagnostics = RecordingDiagnosticsSink()
        let coordinator = makeCoordinator(
            factClient: factClient,
            speechOutput: speechOutput,
            audioSession: audioSession,
            diagnostics: diagnostics
        )
        let plan = AnnouncementPlan(text: "You are in Stroud", boundary: .town)
        let request = PlaceFactRequest(
            boundary: .town,
            placeName: "Stroud",
            countryContext: "United Kingdom"
        )

        let resolved = await withCheckedContinuation { continuation in
            coordinator.requestFact(
                for: plan,
                request: request,
                mode: .shortFacts,
                aiSharingAllowed: { true }
            ) { continuation.resume(returning: $0) }
        }

        XCTAssertEqual(factClient.requests, [request])
        XCTAssertEqual(resolved.id, plan.id)
        XCTAssertTrue(resolved.text.contains("woollen mills"))
        XCTAssertTrue(diagnostics.signals.contains {
            $0.event == .factGenerationFinished && $0.reason == .factAvailable
        })
    }

    func testSpeechSelectionAudioOwnershipAndCompletionAreCoordinatorResults() {
        let speechOutput = RecordingCoordinatorSpeechOutput()
        let audioSession = RecordingCoordinatorAudioSession()
        let diagnostics = RecordingDiagnosticsSink()
        let coordinator = makeCoordinator(
            factClient: StubFactClient(result: nil),
            speechOutput: speechOutput,
            audioSession: audioSession,
            diagnostics: diagnostics
        )
        var results: [AnnouncementWorkflowResult] = []
        coordinator.onResult = { results.append($0) }
        let plan = AnnouncementPlan(text: "Welcome to Wales", boundary: .nation)

        coordinator.speak(
            plan,
            selectedProvider: .proxyElevenLabs,
            aiSharingAllowed: true,
            appleVoice: nil,
            allowAppleFallback: true,
            audioPolicy: .mix
        )
        XCTAssertEqual(speechOutput.requests.last?.provider, .proxyElevenLabs)
        XCTAssertTrue(speechOutput.beginPlayback(provider: .proxyElevenLabs))
        XCTAssertEqual(audioSession.activatedPolicies, [.mix])
        speechOutput.finish()

        XCTAssertEqual(audioSession.deactivateCount, 1)
        XCTAssertTrue(results.contains(.speechRequested(
            plan: plan,
            provider: .proxyElevenLabs,
            shouldRecordTestLog: true
        )))
        XCTAssertTrue(results.contains(.playbackStarted(
            announcementID: plan.id,
            provider: .proxyElevenLabs
        )))
        XCTAssertTrue(results.contains(.completed(announcementID: plan.id)))
    }

    func testSubmitOwnsBoundarySelectionQueueDeliveryAndSpeech() {
        let scheduler = RecordingAnnouncementScheduler()
        let speechOutput = RecordingCoordinatorSpeechOutput()
        let coordinator = makeCoordinator(scheduler: scheduler, speechOutput: speechOutput)
        var results: [AnnouncementWorkflowResult] = []
        coordinator.onResult = { results.append($0) }

        XCTAssertEqual(coordinator.submit(workflowInput(address: Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ))), .noAnnouncement)

        let outcome = coordinator.submit(workflowInput(address: Address(
            street: "Bristol Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        )))
        guard case .accepted(let plan, _) = outcome else {
            return XCTFail("Expected an accepted announcement")
        }

        XCTAssertTrue(results.contains(.announcementQueued(plan: plan, placeLookupID: nil)))
        XCTAssertTrue(speechOutput.requests.isEmpty)
        scheduler.fire()
        XCTAssertEqual(speechOutput.requests.last?.announcementID, plan.id)
        XCTAssertTrue(results.contains(.speechRequested(
            plan: plan,
            provider: .apple,
            shouldRecordTestLog: true
        )))
    }

    func testSubmitOwnsCooldownAndSupersessionWithoutQueuingSuppressedPlan() {
        let scheduler = RecordingAnnouncementScheduler()
        let coordinator = makeCoordinator(scheduler: scheduler)
        _ = coordinator.submit(workflowInput(address: Address(
            street: "High Street",
            town: "Stroud",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ), now: Date(timeIntervalSince1970: 1_000)))
        _ = coordinator.submit(workflowInput(address: Address(
            street: "Bristol Road",
            town: "Stonehouse",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ), now: Date(timeIntervalSince1970: 1_001)))

        let outcome = coordinator.submit(workflowInput(address: Address(
            street: "Long Street",
            town: "Dursley",
            county: "Gloucestershire",
            administrativeArea: "England",
            country: "United Kingdom"
        ), cooldown: 60, now: Date(timeIntervalSince1970: 1_002)))

        guard case .suppressed = outcome else {
            return XCTFail("Expected cooldown suppression")
        }
        XCTAssertNil(coordinator.pending)
    }

    private func workflowInput(
        address: Address,
        cooldown: TimeInterval = 0,
        now: Date = Date(timeIntervalSince1970: 1_000)
    ) -> AnnouncementWorkflowInput {
        AnnouncementWorkflowInput(
            address: address,
            settings: .ridingDefaults,
            mode: .namesOnly,
            repeatPreferences: .allRepeats,
            speakAfterEveryGeocode: false,
            riderContext: .empty,
            delivery: AnnouncementDeliveryContext(
                selectedProvider: .apple,
                aiSharingAllowed: { true },
                appleVoice: nil,
                allowAppleFallback: true,
                audioPolicy: .mix,
                delay: 0,
                shouldRecordTestLog: true
            ),
            boundaryCooldown: cooldown,
            now: now,
            placeLookupID: nil
        )
    }

    func testPrivacyFallbackRetryAndEndRideAreExplicitCoordinatorOutcomes() {
        let scheduler = RecordingAnnouncementScheduler()
        let speechOutput = RecordingCoordinatorSpeechOutput()
        let audioSession = RecordingCoordinatorAudioSession()
        let diagnostics = RecordingDiagnosticsSink()
        let coordinator = makeCoordinator(
            scheduler: scheduler,
            audioReleaseScheduler: RecordingAnnouncementScheduler(),
            factClient: StubFactClient(result: nil),
            speechOutput: speechOutput,
            audioSession: audioSession,
            diagnostics: diagnostics
        )
        var results: [AnnouncementWorkflowResult] = []
        coordinator.onResult = { results.append($0) }
        let plan = AnnouncementPlan(text: "You are in Stroud", boundary: .town)

        coordinator.schedule(plan, after: 0.5) { _ in }
        coordinator.speak(
            plan,
            selectedProvider: .proxyElevenLabs,
            aiSharingAllowed: false,
            appleVoice: nil,
            allowAppleFallback: true,
            audioPolicy: .mix
        )
        XCTAssertEqual(speechOutput.requests.last?.provider, .apple)
        speechOutput.emitPipeline(
            announcementID: plan.id,
            provider: .proxyElevenLabs,
            stage: .retryScheduled
        )
        speechOutput.emitPipeline(
            announcementID: plan.id,
            provider: .proxyElevenLabs,
            stage: .fallbackStarted
        )
        _ = coordinator.cancelAll(reason: .rideEnded)

        XCTAssertNil(coordinator.pending)
        XCTAssertTrue(speechOutput.stopCount > 0)
        XCTAssertTrue(results.contains(.retryScheduled(
            announcementID: plan.id,
            provider: .proxyElevenLabs
        )))
        XCTAssertTrue(results.contains(.fallbackStarted(
            announcementID: plan.id,
            provider: .apple
        )))
        XCTAssertTrue(results.contains(.cancelled(
            announcementID: plan.id,
            reason: .rideEnded
        )))
    }

    func testRealFallbackOrderingDoesNotProduceTerminalFailureBeforeAppleStarts() {
        let speechOutput = RecordingCoordinatorSpeechOutput()
        let coordinator = makeCoordinator(
            factClient: StubFactClient(result: nil),
            speechOutput: speechOutput,
            audioSession: RecordingCoordinatorAudioSession(),
            diagnostics: RecordingDiagnosticsSink()
        )
        var results: [AnnouncementWorkflowResult] = []
        coordinator.onResult = { results.append($0) }
        let plan = AnnouncementPlan(text: "Welcome to Wales", boundary: .nation)
        coordinator.speak(
            plan,
            selectedProvider: .proxyElevenLabs,
            aiSharingAllowed: true,
            appleVoice: nil,
            allowAppleFallback: true,
            audioPolicy: .mix
        )

        speechOutput.emitFallbackWithDiagnostic(announcementID: plan.id)

        XCTAssertTrue(results.contains(.fallbackStarted(
            announcementID: plan.id,
            provider: .apple
        )))
        XCTAssertFalse(results.contains(.failed(
            announcementID: plan.id,
            reason: .playbackFailed
        )))
        XCTAssertEqual(coordinator.activePlan, plan)
    }

    func testBoundaryAcceptanceAndInterruptionResumeAreCoordinatorOwned() {
        let speechOutput = RecordingCoordinatorSpeechOutput()
        let coordinator = makeCoordinator(
            factClient: StubFactClient(result: nil),
            speechOutput: speechOutput,
            audioSession: RecordingCoordinatorAudioSession(),
            diagnostics: RecordingDiagnosticsSink()
        )
        let town = AnnouncementPlan(text: "Stroud", boundary: .town)
        let country = AnnouncementPlan(text: "Welcome to Wales", boundary: .country)
        coordinator.schedule(town, after: 1) { _ in }

        XCTAssertEqual(
            coordinator.acceptBoundary(country),
            .boundaryAccepted(
                announcementID: country.id,
                supersededAnnouncementIDs: [town.id]
            )
        )
        coordinator.speak(
            country,
            selectedProvider: .apple,
            aiSharingAllowed: true,
            appleVoice: nil,
            allowAppleFallback: false,
            audioPolicy: .mix
        )
        XCTAssertEqual(
            coordinator.externalAudioBegan(.interruption),
            .interrupted(announcementID: country.id, reason: .interruptionBegan)
        )
        let resumed = coordinator.externalAudioEnded(.interruption, shouldResume: true)
        XCTAssertEqual(resumed.plan, country)
        XCTAssertEqual(resumed.result, .resumed(announcementID: country.id))
    }

    func testAudioReleaseRetryIsOwnedAndDiagnosedByCoordinator() {
        let retryScheduler = RecordingAnnouncementScheduler()
        let speechOutput = RecordingCoordinatorSpeechOutput()
        let audioSession = RecordingCoordinatorAudioSession()
        audioSession.deactivationFailuresRemaining = 1
        let diagnostics = RecordingDiagnosticsSink()
        let coordinator = makeCoordinator(
            audioReleaseScheduler: retryScheduler,
            factClient: StubFactClient(result: nil),
            speechOutput: speechOutput,
            audioSession: audioSession,
            diagnostics: diagnostics
        )
        let plan = AnnouncementPlan(text: "Stroud", boundary: .town)
        coordinator.speak(
            plan,
            selectedProvider: .apple,
            aiSharingAllowed: true,
            appleVoice: nil,
            allowAppleFallback: false,
            audioPolicy: .mix
        )
        XCTAssertTrue(speechOutput.beginPlayback(provider: .apple))

        speechOutput.finish()
        XCTAssertEqual(audioSession.deactivateCount, 1)
        retryScheduler.fire()

        XCTAssertEqual(audioSession.deactivateCount, 2)
        XCTAssertTrue(diagnostics.signals.contains { $0.event == .audioSessionReleaseFailed })
        XCTAssertTrue(diagnostics.signals.contains { $0.event == .audioSessionReleased })
    }

    func testFallbackDisabledFailureHasOnlyFailedTerminalResult() {
        let speechOutput = RecordingCoordinatorSpeechOutput()
        let coordinator = makeCoordinator(
            factClient: StubFactClient(result: nil),
            speechOutput: speechOutput,
            audioSession: RecordingCoordinatorAudioSession(),
            diagnostics: RecordingDiagnosticsSink()
        )
        var results: [AnnouncementWorkflowResult] = []
        coordinator.onResult = { results.append($0) }
        let plan = AnnouncementPlan(text: "Stroud", boundary: .town)
        coordinator.speak(
            plan,
            selectedProvider: .proxyElevenLabs,
            aiSharingAllowed: true,
            appleVoice: nil,
            allowAppleFallback: false,
            audioPolicy: .mix
        )

        speechOutput.emitFailureWithoutFallback()

        XCTAssertTrue(results.contains(.failed(
            announcementID: plan.id,
            reason: .playbackFailed
        )))
        XCTAssertFalse(results.contains(.completed(announcementID: plan.id)))
    }

    func testMustNotResumeInterruptionCancelsAcrossOverlappingPauseSources() {
        let coordinator = makeCoordinator(
            factClient: StubFactClient(result: nil),
            speechOutput: RecordingCoordinatorSpeechOutput(),
            audioSession: RecordingCoordinatorAudioSession(),
            diagnostics: RecordingDiagnosticsSink()
        )
        let plan = AnnouncementPlan(text: "Welcome to Wales", boundary: .nation)
        coordinator.speak(
            plan,
            selectedProvider: .apple,
            aiSharingAllowed: true,
            appleVoice: nil,
            allowAppleFallback: false,
            audioPolicy: .mix
        )
        _ = coordinator.externalAudioBegan(.primaryAudio)
        _ = coordinator.externalAudioBegan(.interruption)

        let interruptionEnd = coordinator.externalAudioEnded(
            .interruption,
            shouldResume: false
        )
        let primaryAudioEnd = coordinator.externalAudioEnded(
            .primaryAudio,
            shouldResume: true
        )

        XCTAssertEqual(
            interruptionEnd.result,
            .cancelled(announcementID: plan.id, reason: .interruptionMustNotResume)
        )
        XCTAssertNil(primaryAudioEnd.plan)
        XCTAssertNil(coordinator.interruptedPlan)
    }

    func testDeferredReasonPrefersInterruptionWhenPauseSourcesOverlap() {
        let coordinator = makeCoordinator(
            factClient: StubFactClient(result: nil),
            speechOutput: RecordingCoordinatorSpeechOutput(),
            audioSession: RecordingCoordinatorAudioSession(),
            diagnostics: RecordingDiagnosticsSink()
        )
        _ = coordinator.externalAudioBegan(.primaryAudio)
        _ = coordinator.externalAudioBegan(.interruption)
        let plan = AnnouncementPlan(text: "Stroud", boundary: .town)

        XCTAssertEqual(
            coordinator.deferIfPaused(plan),
            .deferred(announcementID: plan.id, reason: .interruptionBegan)
        )
    }

    func testRepeatedAudioReleaseFailureUsesNeutralisation() {
        let retryScheduler = RecordingAnnouncementScheduler()
        let speechOutput = RecordingCoordinatorSpeechOutput()
        let audioSession = RecordingCoordinatorAudioSession()
        audioSession.deactivationFailuresRemaining = 3
        let diagnostics = RecordingDiagnosticsSink()
        let coordinator = makeCoordinator(
            audioReleaseScheduler: retryScheduler,
            factClient: StubFactClient(result: nil),
            speechOutput: speechOutput,
            audioSession: audioSession,
            diagnostics: diagnostics
        )
        let plan = AnnouncementPlan(text: "Stroud", boundary: .town)
        coordinator.speak(
            plan,
            selectedProvider: .apple,
            aiSharingAllowed: true,
            appleVoice: nil,
            allowAppleFallback: false,
            audioPolicy: .interrupt
        )
        XCTAssertTrue(speechOutput.beginPlayback(provider: .apple))
        speechOutput.finish()
        retryScheduler.fire()
        retryScheduler.fire()

        XCTAssertEqual(audioSession.neutralizeCount, 1)
        XCTAssertTrue(diagnostics.signals.contains { $0.event == .audioSessionNeutralized })
    }

    func testFactCancellationDiagnosticsRemainTerminalOnly() {
        let diagnostics = RecordingDiagnosticsSink()
        let coordinator = makeCoordinator(diagnostics: diagnostics)
        let plan = AnnouncementPlan(text: "Stroud", boundary: .town)

        _ = coordinator.beginFact(for: plan)
        _ = coordinator.cancelAll(reason: .supersededByNewerContext)
        XCTAssertFalse(diagnostics.signals.contains { $0.event == .announcementCancelled })

        _ = coordinator.beginFact(for: plan)
        _ = coordinator.cancelAll(reason: .inactivityPrompted)
        XCTAssertFalse(diagnostics.signals.contains { $0.event == .announcementCancelled })

        _ = coordinator.beginFact(for: plan)
        _ = coordinator.cancelAll(reason: .rideEnded)
        XCTAssertTrue(diagnostics.signals.contains {
            $0.event == .announcementCancelled
                && $0.announcementID == plan.id
                && $0.reason == .rideEnded
        })
    }

    func testPendingCancellationDiagnosticsRemainTerminalOnly() {
        let diagnostics = RecordingDiagnosticsSink()
        let coordinator = makeCoordinator(diagnostics: diagnostics)

        let superseded = coordinator.enqueue(text: "Stroud", boundary: .town)
        _ = coordinator.cancelAll(reason: .supersededByNewerContext)
        XCTAssertFalse(diagnostics.signals.contains {
            $0.event == .announcementCancelled && $0.announcementID == superseded.id
        })

        let inactive = coordinator.enqueue(text: "Gloucestershire", boundary: .county)
        _ = coordinator.cancelAll(reason: .inactivityPrompted)
        XCTAssertFalse(diagnostics.signals.contains {
            $0.event == .announcementCancelled && $0.announcementID == inactive.id
        })

        let ended = coordinator.enqueue(text: "Wales", boundary: .nation)
        _ = coordinator.cancelAll(reason: .rideEnded)
        XCTAssertTrue(diagnostics.signals.contains {
            $0.event == .announcementCancelled
                && $0.announcementID == ended.id
                && $0.reason == .rideEnded
        })
    }
}

@MainActor
private final class RecordingAnnouncementScheduler: AnnouncementScheduling {
    private var action: (@MainActor () -> Void)?
    private(set) var didCancel = false

    func schedule(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        self.action = action
        didCancel = false
    }

    func cancel() {
        action = nil
        didCancel = true
    }

    func fire() { action?() }
}

private final class StubFactClient: FactClient {
    private let result: String?
    private(set) var requests: [PlaceFactRequest] = []

    init(result: String?) {
        self.result = result
    }

    func fact(for request: PlaceFactRequest) async throws -> String {
        requests.append(request)
        if let result { return result }
        throw PlaceFactError.invalidResponse
    }
}

@MainActor
private final class RecordingDiagnosticsSink: DiagnosticsSink {
    private(set) var signals: [AnnouncementDiagnosticSignal] = []
    func record(_ signal: AnnouncementDiagnosticSignal) { signals.append(signal) }
}

@MainActor
private final class RecordingCoordinatorAudioSession: AudioSessionManaging {
    var shouldYieldToPrimaryAudio = false
    var snapshot = AudioSessionSnapshot(
        outputVolume: 1,
        outputRouteTypes: [],
        isOtherAudioPlaying: false,
        shouldYieldToPrimaryAudio: false
    )
    private(set) var activatedPolicies: [AudioCoexistencePolicy] = []
    private(set) var deactivateCount = 0
    var deactivationFailuresRemaining = 0
    private(set) var neutralizeCount = 0

    func activate(policy: AudioCoexistencePolicy) throws { activatedPolicies.append(policy) }
    func deactivate() throws {
        deactivateCount += 1
        if deactivationFailuresRemaining > 0 {
            deactivationFailuresRemaining -= 1
            throw CoordinatorTestError.deactivationFailed
        }
    }
    func neutralizeAfterDeactivationFailure() -> Bool {
        neutralizeCount += 1
        return true
    }
}

@MainActor
private final class RecordingCoordinatorSpeechOutput: SpeechOutput {
    struct Request {
        let announcementID: UUID
        let provider: SpeechProvider
    }

    var isSpeaking = false
    var isPlayingAudio = false
    var onPlaybackWillStart: ((SpeechProvider) -> Bool)?
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDiagnosticNote: ((String) -> Void)?
    var onPipelineEvent: ((SpeechOutputPipelineEvent) -> Void)?
    private(set) var requests: [Request] = []
    private(set) var stopCount = 0

    func speak(
        text: String,
        boundary: BoundaryType?,
        provider: SpeechProvider,
        appleVoice: SpeechVoiceSelection?,
        allowAppleFallback: Bool,
        announcementID: UUID
    ) {
        requests.append(Request(announcementID: announcementID, provider: provider))
        isSpeaking = true
    }

    func cancelPendingPreparation() { stop() }

    func stop() {
        stopCount += 1
        let wasSpeaking = isSpeaking
        isSpeaking = false
        isPlayingAudio = false
        if wasSpeaking { onCancel?() }
    }

    func beginPlayback(provider: SpeechProvider) -> Bool {
        let started = onPlaybackWillStart?(provider) ?? true
        isPlayingAudio = started
        return started
    }

    func finish() {
        isSpeaking = false
        isPlayingAudio = false
        onFinish?()
    }

    func emitPipeline(
        announcementID: UUID,
        provider: SpeechProvider,
        stage: SpeechOutputPipelineStage
    ) {
        onPipelineEvent?(SpeechOutputPipelineEvent(
            announcementID: announcementID,
            provider: provider,
            stage: stage
        ))
    }

    func emitFallbackWithDiagnostic(announcementID: UUID) {
        emitPipeline(
            announcementID: announcementID,
            provider: .proxyElevenLabs,
            stage: .fallbackStarted
        )
        onDiagnosticNote?("Premium voice failed. Apple fallback used.")
    }

    func emitFailureWithoutFallback() {
        onDiagnosticNote?("Premium voice failed. Apple fallback disabled.")
        finish()
    }
}

private enum CoordinatorTestError: Error {
    case deactivationFailed
}
