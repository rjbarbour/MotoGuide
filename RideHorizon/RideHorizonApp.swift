//
//  RideHorizonApp.swift
//  RideHorizon
//
//  Created by Robert Barbour on 10/07/2024.
//

import SwiftUI

@main
struct RideHorizonApp: App {
    @StateObject private var locationManager: LocationManager
    @StateObject private var rideDiagnostics: RideDiagnosticsStore
    @StateObject private var firstRunState: FirstRunState
    @StateObject private var aiSharingConsent: AISharingConsentStore
#if DEBUG
    @StateObject private var debugLog: DebugLogStore
#endif

    init() {
        let rideDiagnostics = RideDiagnosticsStore.shared
        let firstRunState = FirstRunState()
        let aiSharingConsent = AISharingConsentStore()
        let locationAdapter = CoreLocationAdapter()
        let factClient = CachedPlaceFactGenerator(generator: ProxyFactGenerator())
        let speechOutput = DefaultSpeechOutputEngine()
        let audioSession = SystemAudioSessionManager()
        let announcementDiagnostics = AnnouncementDiagnosticsRelay()
        let announcementCoordinator = AnnouncementCoordinator(
            scheduler: DispatchAnnouncementScheduler(),
            audioReleaseScheduler: DispatchAnnouncementScheduler(),
            factClient: factClient,
            speechOutput: speechOutput,
            audioSession: audioSession,
            diagnostics: announcementDiagnostics
        )
        let locationManager = LocationManager(
            announcementCoordinator: announcementCoordinator,
            inactivityNotifier: UserNotificationRideInactivityNotifier(),
            audioSession: audioSession,
            diagnostics: rideDiagnostics,
            rideSettingsStore: UserDefaultsRideSettingsStore(),
            locationSource: locationAdapter,
            placeResolver: locationAdapter,
            rideDistanceMeasurer: CoreLocationRideDistanceMeasurer(),
            aiSharingAllowed: { aiSharingConsent.isGranted }
        )
        announcementDiagnostics.connect { [weak locationManager] signal in
            locationManager?.recordAnnouncementDiagnostic(signal)
        }

        _locationManager = StateObject(wrappedValue: locationManager)
        _rideDiagnostics = StateObject(wrappedValue: rideDiagnostics)
        _firstRunState = StateObject(wrappedValue: firstRunState)
        _aiSharingConsent = StateObject(wrappedValue: aiSharingConsent)
#if DEBUG
        _debugLog = StateObject(wrappedValue: DebugLogStore.shared)
#endif
    }

    var body: some Scene {
        WindowGroup {
            appContent
        }
    }

    private var appContent: some View {
#if DEBUG
        ContentView(
            locationManager: locationManager,
            rideDiagnostics: rideDiagnostics,
            firstRunState: firstRunState,
            aiSharingConsent: aiSharingConsent,
            debugLog: debugLog
        )
#else
        ContentView(
            locationManager: locationManager,
            rideDiagnostics: rideDiagnostics,
            firstRunState: firstRunState,
            aiSharingConsent: aiSharingConsent
        )
#endif
    }
}
