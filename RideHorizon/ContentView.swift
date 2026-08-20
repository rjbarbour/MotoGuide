import SwiftUI
import CoreLocation
import MapKit
import UIKit

private struct RoundedCornerShape: Shape {
    let topLeadingRadius: CGFloat
    let topTrailingRadius: CGFloat
    let bottomLeadingRadius: CGFloat
    let bottomTrailingRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var corners: UIRectCorner = []
        if topLeadingRadius > 0 { corners.insert(.topLeft) }
        if topTrailingRadius > 0 { corners.insert(.topRight) }
        if bottomLeadingRadius > 0 { corners.insert(.bottomLeft) }
        if bottomTrailingRadius > 0 { corners.insert(.bottomRight) }
        let radius = [topLeadingRadius, topTrailingRadius, bottomLeadingRadius, bottomTrailingRadius].max() ?? 0

        let bezier = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(bezier.cgPath)
    }
}

private struct RideLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let location: CLLocationCoordinate2D
    let address: Address
    let utteredPhrase: String?
}

struct LocationHierarchyRow: Equatable, Identifiable {
    let id: String
    let label: String
    let value: String
    let isCurrent: Bool
    let isAvailable: Bool
}

enum LocationSummaryFormatter {
    static func summaryLines(for address: Address?) -> [String] {
        guard let address else { return [] }
        let firstRow = dedupe([valid(address.street), valid(address.town)]).joined(separator: ", ")
        let secondRow = dedupe([
            enclosingLocality(for: address),
            valid(address.county),
            valid(address.administrativeArea),
            valid(address.country)
        ]).joined(separator: " · ")

        return [
            firstRow.isEmpty ? nil : firstRow,
            secondRow.isEmpty ? nil : secondRow
        ].compactMap { $0 }
    }

    static func summary(for address: Address?) -> String {
        guard let address else { return "Waiting for location" }
        let parts = [
            valid(address.street),
            valid(address.town),
            valid(address.county)
        ].compactMap { $0 }

        return parts.isEmpty ? "Updating place..." : parts.joined(separator: ", ")
    }

    static func contextLine(for address: Address?) -> String? {
        guard let address else { return nil }
        let components = [
            valid(address.town),
            enclosingLocality(for: address),
            valid(address.county),
            valid(address.administrativeArea),
            valid(address.country)
        ].compactMap { $0 }

        let deduped = components.reduce(into: [String]()) { result, component in
            let normalized = component.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !result.contains(where: { $0.lowercased() == normalized }) {
                result.append(component)
            }
        }

        return deduped.isEmpty ? nil : deduped.joined(separator: " · ")
    }

    static func hierarchyRows(for address: Address?) -> [LocationHierarchyRow] {
        let values: [(id: String, label: String, value: String?)] = [
            ("name", "Name", address.flatMap { valid($0.name) }),
            ("houseNumber", "House number", address.flatMap { valid($0.houseNumber) }),
            ("street", "Road", address.flatMap { valid($0.street) }),
            ("subLocality", "Sub-locality", address.flatMap { valid($0.subLocality) }),
            ("locality", "Locality", address.flatMap { valid($0.locality) }),
            ("town", "Current place", address.flatMap { valid($0.town) }),
            ("county", "District / county", address.flatMap { valid($0.county) }),
            ("region", "Region", address.flatMap { valid($0.administrativeArea) }),
            ("postcode", "Postcode", address.flatMap { valid($0.postalCode) }),
            ("countryCode", "Country code", address.flatMap { valid($0.isoCountryCode) }),
            ("country", "Country", address.flatMap { valid($0.country) }),
            ("inlandWater", "Inland water", address.flatMap { valid($0.inlandWater) }),
            ("ocean", "Ocean", address.flatMap { valid($0.ocean) }),
            ("areasOfInterest", "Areas of interest", address.flatMap { areasOfInterestText($0.areasOfInterest) }),
            ("timeZone", "Timezone", address.flatMap { valid($0.timeZoneIdentifier) }),
            ("appleRegion", "Apple region", address.flatMap { valid($0.regionIdentifier) })
        ]
        let availableValues = values.compactMap { item -> (id: String, label: String, value: String)? in
            guard let value = item.value else { return nil }
            return (item.id, item.label, value)
        }
        let currentID = availableValues.first?.id

        return availableValues.map { item in
            LocationHierarchyRow(
                id: item.id,
                label: item.label,
                value: item.value,
                isCurrent: item.id == currentID,
                isAvailable: true
            )
        }
    }

    private static func valid(_ value: String) -> String? {
        Address.isValidPlaceName(value) ? value : nil
    }

    private static func areasOfInterestText(_ values: [String]) -> String? {
        let validValues = values.compactMap(valid)
        return validValues.isEmpty ? nil : dedupe(validValues.map(Optional.some)).joined(separator: " · ")
    }

    private static func enclosingLocality(for address: Address) -> String? {
        guard let locality = valid(address.locality) else { return nil }
        guard let currentPlace = valid(address.town) else { return locality }
        return normalized(locality) == normalized(currentPlace) ? nil : locality
    }

    private static func dedupe(_ values: [String?]) -> [String] {
        var valuesSeen: [String] = []
        for value in values.compactMap({ $0 }) {
            if !valuesSeen.contains(where: { normalized($0) == normalized(value) }) {
                valuesSeen.append(value)
            }
        }
        return valuesSeen
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var locationManager: LocationManager
    @ObservedObject private var rideDiagnostics: RideDiagnosticsStore
    @ObservedObject private var firstRunState: FirstRunState
    @ObservedObject private var aiSharingConsent: AISharingConsentStore
    @AppStorage("RideHorizonMapLabelScale") private var mapLabelScale = 1.0
#if DEBUG
    @ObservedObject private var debugLog: DebugLogStore
#endif
    @State private var logs: [RideLogEntry] = []
    @State private var showOnboarding = false
    @State private var showAISharingChoice = false
    @State private var showResetConfirmation = false
    @State private var showResetCompleteMessage = false
    @State private var showSettings = false
    @State private var showLog = false
    @State private var settingsDetent: PresentationDetent = .large
    @State private var logDetent: PresentationDetent = .large

#if DEBUG
    init(
        locationManager: LocationManager,
        rideDiagnostics: RideDiagnosticsStore,
        firstRunState: FirstRunState,
        aiSharingConsent: AISharingConsentStore,
        debugLog: DebugLogStore
    ) {
        _locationManager = ObservedObject(wrappedValue: locationManager)
        _rideDiagnostics = ObservedObject(wrappedValue: rideDiagnostics)
        _firstRunState = ObservedObject(wrappedValue: firstRunState)
        _aiSharingConsent = ObservedObject(wrappedValue: aiSharingConsent)
        _debugLog = ObservedObject(wrappedValue: debugLog)
    }
#else
    init(
        locationManager: LocationManager,
        rideDiagnostics: RideDiagnosticsStore,
        firstRunState: FirstRunState,
        aiSharingConsent: AISharingConsentStore
    ) {
        _locationManager = ObservedObject(wrappedValue: locationManager)
        _rideDiagnostics = ObservedObject(wrappedValue: rideDiagnostics)
        _firstRunState = ObservedObject(wrappedValue: firstRunState)
        _aiSharingConsent = ObservedObject(wrappedValue: aiSharingConsent)
    }
#endif

    var body: some View {
        NavigationStack {
            LocationScreenView(
                locationManager: locationManager,
                onRepeat: {
                    locationManager.repeatCurrentAnnouncement()
                },
                mapLabelScale: mapLabelScale
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if locationManager.rideSessionState.isActive {
                            locationManager.endRide()
                        } else {
                            locationManager.startRide()
                        }
                    } label: {
                        Text(locationManager.rideSessionState.isActive ? "End ride" : "Start ride")
                            .fontWeight(.bold)
                    }
                    .accessibilityIdentifier("rideSessionControl")
                    .accessibilityHint(
                        locationManager.rideSessionState.isActive
                            ? "Stops location, announcements and background activity."
                            : "Starts location and announcements. Set up while stopped."
                    )
                }

                ToolbarItem(placement: .principal) {
                    Label(navigationStatus.label, systemImage: navigationStatus.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.75), radius: 2, x: 0, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: 178)
                    .accessibilityIdentifier("announcementPipelineStatus")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showLog = true
                    } label: {
                        Label("Log", systemImage: "clock.arrow.circlepath")
                    }

                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
        }
        .onAppear {
            configureRideCallbacks()
            showOnboarding = firstRunState.needsOnboarding
            if !firstRunState.needsOnboarding, aiSharingConsent.decision == .notDetermined {
                showAISharingChoice = true
            }
        }
        .sheet(isPresented: $showSettings) {
#if DEBUG
            SettingsView(
                locationManager: locationManager,
                showResetConfirmation: $showResetConfirmation,
                aiSharingConsent: aiSharingConsent,
                onClearLocalData: clearAllLocalData,
                rideDiagnostics: rideDiagnostics,
                debugLog: debugLog
            )
            .presentationDetents([.medium, .large], selection: $settingsDetent)
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.resizes)
#else
            SettingsView(
                locationManager: locationManager,
                showResetConfirmation: $showResetConfirmation,
                aiSharingConsent: aiSharingConsent,
                onClearLocalData: clearAllLocalData,
                rideDiagnostics: rideDiagnostics
            )
            .presentationDetents([.medium, .large], selection: $settingsDetent)
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.resizes)
#endif
        }
        .sheet(isPresented: $showLog) {
            LogHistoryView(locationManager: locationManager, logs: $logs)
                .presentationDetents([.medium, .large], selection: $logDetent)
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.resizes)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(firstRunState: firstRunState, aiSharingConsent: aiSharingConsent) {
                showOnboarding = false
                locationManager.applyAISharingDecision(isGranted: aiSharingConsent.isGranted)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                locationManager.evaluateRideSession()
                locationManager.recordAppLifecycle(isForeground: true)
            case .background:
                locationManager.recordAppLifecycle(isForeground: false)
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .fullScreenCover(isPresented: $showAISharingChoice) {
            AISharingChoiceView(consent: aiSharingConsent) {
                showAISharingChoice = false
                locationManager.applyAISharingDecision(isGranted: aiSharingConsent.isGranted)
            }
        }
        .alert("Reset First-Time Experience?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetFirstRunExperience()
            }
        } message: {
            Text("Clears onboarding state so \(ProductIdentity.displayName) behaves like a fresh install. Onboarding will appear again immediately.")
        }
        .alert("First-time experience reset", isPresented: $showResetCompleteMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Onboarding is showing again. No app restart needed.")
        }
        .alert(
            "Still riding?",
            isPresented: Binding(
                get: {
                    if case .awaitingConfirmation = locationManager.rideSessionState {
                        return true
                    }
                    return false
                },
                set: { _ in }
            )
        ) {
            Button("Continue ride") {
                locationManager.continueRide()
            }
            Button("End ride", role: .destructive) {
                locationManager.endRide()
            }
        } message: {
            Text("RideHorizon has not confirmed 50 metres of movement in 10 minutes. Continue only while stopped; otherwise this ride will end automatically.")
        }
    }

    private var navigationStatus: (label: String, systemImage: String) {
        if locationManager.announcementStatus != .idle {
            return (
                locationManager.announcementStatus.riderLabel,
                locationManager.announcementStatus.systemImage
            )
        }

        return (
            locationManager.rideSessionState.riderLabel,
            locationManager.rideSessionState.isActive ? "location.fill" : "location.slash"
        )
    }

    private func configureRideCallbacks() {
        locationManager.onAddressChange = { address in
            guard !locationManager.testMode else { return }
            if let location = locationManager.lastKnownLocation {
                appendLog(location: location, address: address, utteredPhrase: nil)
            }
        }
        locationManager.onRideLog = { location, address, utteredPhrase in
            appendLog(location: location, address: address, utteredPhrase: utteredPhrase)
        }
    }

    private func resetFirstRunExperience() {
        firstRunState.reset()
        locationManager.pauseRideTracking()
        showOnboarding = true
        showResetCompleteMessage = true
    }

    private func clearAllLocalData() {
        locationManager.clearLocalPrivacyState()
        logs.removeAll()
        PlaceFactCache.shared.clear()
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
        rideDiagnostics.clear()
#if DEBUG
        debugLog.clear()
#endif
        firstRunState.reset()
        aiSharingConsent.reset()
        KeychainCredentialLoader.deleteRideHorizonDeviceId()
        ProxyCredentialLifecycle.invalidate()
        showSettings = false
        showLog = false
        showAISharingChoice = false
        showOnboarding = true
    }

    private func appendLog(
        location: CLLocationCoordinate2D,
        address: Address,
        utteredPhrase: String?
    ) {
        let entry = RideLogEntry(
            timestamp: Date(),
            location: location,
            address: address,
            utteredPhrase: utteredPhrase
        )
        logs.insert(entry, at: 0)
        AppDiagnostics.log("Ride log entry added.")
    }
}

private struct LocationScreenView: View {
    @ObservedObject var locationManager: LocationManager
    let onRepeat: () -> Void
    let mapLabelScale: Double
    @AppStorage("RideHorizonRepeatHintDismissed") private var repeatHintDismissed = false
    @AppStorage("RideHorizonNightMode") private var nightMode = false
    @State private var isInfoPanelExpanded = false
    @State private var panelDragOffset: CGFloat = 0
    private static let compactPanelBaseFactor: CGFloat = 0.24
    private static let expandedPanelBaseFactor: CGFloat = 0.58

    private enum OverlayLayout {
        static let verticalPad: CGFloat = 8
        static let cornerRadius: CGFloat = 12
        static let handleHeight: CGFloat = 24
        static let summaryLineLimit: Int = 2
        static let hierarchyLineLimit: Int = 2
        static let phraseLineLimit: Int = 3
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                LocationMapView(
                    coordinate: locationManager.lastKnownLocation,
                    locationStatus: locationManager.locationStatus,
                    allowsInteraction: true,
                    mapLabelScale: mapLabelScale
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    handleBar

                    VStack(alignment: .leading, spacing: 0) {
                        compactInfoPanel
                            .contentShape(Rectangle())
                            .onTapGesture {
                                repeatHintDismissed = true
                                onRepeat()
                            }
                        Divider()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        if isInfoPanelExpanded {
                            ScrollView {
                                expandedInfoPanel
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        repeatHintDismissed = true
                                        onRepeat()
                                    }
                            }
                            .scrollIndicators(.visible)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, OverlayLayout.verticalPad * 2)
                }
                .frame(
                    height: panelHeight(for: geometry.size.height),
                    alignment: .top
                )
                .frame(maxWidth: .infinity)
                .background(panelStyle.background)
                .clipShape(
                    RoundedCornerShape(
                        topLeadingRadius: OverlayLayout.cornerRadius,
                        topTrailingRadius: OverlayLayout.cornerRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0
                    )
                )
                .overlay(
                    RoundedCornerShape(
                        topLeadingRadius: OverlayLayout.cornerRadius,
                        topTrailingRadius: OverlayLayout.cornerRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0
                    )
                        .stroke(panelStyle.divider.opacity(0.22), lineWidth: 1)
                )
                .padding(.horizontal, 0)
                .ignoresSafeArea(edges: .bottom)
                .offset(y: panelDragOffset)
                .gesture(panelDragGesture(totalHeight: geometry.size.height))
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var compactInfoPanel: some View {
            VStack(alignment: .leading, spacing: 12) {
            let summaryLines = LocationSummaryFormatter.summaryLines(for: locationManager.lastKnownAddress)

            if let topLine = summaryLines.first {
                Text(topLine)
                    .font(.system(size: scaledFont(31), weight: .bold))
                    .textCase(.none)
                    .foregroundStyle(panelStyle.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(OverlayLayout.summaryLineLimit)
            } else {
                Text("Waiting for location")
                    .font(.system(size: scaledFont(31), weight: .bold))
                    .textCase(.none)
                    .foregroundStyle(panelStyle.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if summaryLines.indices.contains(1) {
                let contextLine = summaryLines[1]
                Text(contextLine)
                    .font(.system(size: scaledFont(21), weight: .semibold))
                    .foregroundStyle(panelStyle.secondaryText)
                    .lineLimit(OverlayLayout.hierarchyLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let contextLine = LocationSummaryFormatter.contextLine(for: locationManager.lastKnownAddress) {
                Text(contextLine)
                    .font(.system(size: scaledFont(21), weight: .semibold))
                    .foregroundStyle(panelStyle.secondaryText)
                    .lineLimit(OverlayLayout.hierarchyLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !repeatHintDismissed {
                Label("Tap here to repeat the phrase, or tap again to stop speech", systemImage: "speaker.wave.2")
                    .font(.system(size: scaledFont(17), weight: .semibold))
                    .fontWeight(.medium)
                    .foregroundStyle(panelStyle.secondaryText)
                    .padding(.top, 2)
            }

            speechDiagnosticWarning
        }
        .padding()
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to repeat when finished; tap while speaking to stop.")
    }

    private var expandedInfoPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusPanel

            applePlaceDataPanel

            VStack(alignment: .leading, spacing: 6) {
                Text("Last spoken phrase")
                    .font(.system(size: scaledFont(15), weight: .bold))
                    .foregroundStyle(panelStyle.secondaryText)
                    .textCase(.uppercase)
                Text(locationManager.lastSpokenPhrase ?? "No spoken phrase yet")
                    .font(.system(size: scaledFont(22), weight: .semibold))
                    .foregroundStyle(panelStyle.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(OverlayLayout.phraseLineLimit)
                if let timestamp = locationManager.lastSpokenAt {
                    Text(isoDateFormatter.string(from: timestamp))
                        .font(.system(size: scaledFont(14)))
                        .foregroundStyle(panelStyle.secondaryText)
                        .padding(.top, 1)
                }
                speechDiagnosticWarning
            }

            if locationManager.testMode && locationManager.rideSessionState.isActive {
                Button {
                    locationManager.advanceTestLocation()
                } label: {
                    Label("Next test location", systemImage: "arrow.forward.circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(panelStyle.accent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var applePlaceDataPanel: some View {
        let rows = LocationSummaryFormatter.hierarchyRows(for: locationManager.lastKnownAddress)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Apple place data")
                    .font(.system(size: scaledFont(15), weight: .bold))
                    .foregroundStyle(panelStyle.secondaryText)
                    .textCase(.uppercase)

                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(row.label)
                            .font(.system(size: scaledFont(15), weight: .semibold))
                            .foregroundStyle(panelStyle.secondaryText)
                            .frame(width: 120, alignment: .leading)
                        Text(row.value)
                            .font(.system(size: scaledFont(16), weight: .medium))
                            .foregroundStyle(panelStyle.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var speechDiagnosticWarning: some View {
        if locationManager.testMode, let note = locationManager.lastSpeechDiagnosticNote {
            Label(note, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: scaledFont(17), weight: .bold))
                .foregroundStyle(panelStyle.warningText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(locationManager.contentMode.label)
                    .font(.system(size: scaledFont(20), weight: .bold))
                    .fontWeight(.semibold)
                    .foregroundStyle(panelStyle.primaryText)
                Spacer()
                if locationManager.contentMode == .quiet {
                    Label("Quiet", systemImage: "speaker.slash.fill")
                        .font(.system(size: scaledFont(14)))
                        .foregroundStyle(panelStyle.warningText)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Label(
                            locationManager.rideSessionState.riderLabel,
                            systemImage: locationManager.rideSessionState.isActive ? "location.fill" : "location.slash"
                        )
#if INTERNAL_AUDIO_CALIBRATION
                        if SpeechCalibrationRuntimeProfileStore().activeProfile() != nil {
                            Label("Candidate B active", systemImage: "waveform.badge.checkmark")
                                .foregroundStyle(panelStyle.warningText)
                        }
#endif
                    }
                    .font(.system(size: scaledFont(14)))
                    .foregroundStyle(panelStyle.primaryText)
                }
            }

            Divider()

            if locationManager.testMode && locationManager.locationStatus != .active {
                Label(locationManager.locationStatus.riderMessage, systemImage: locationManager.locationStatus.needsSettingsAction ? "location.slash" : "location")
                    .font(.system(size: scaledFont(18), weight: .semibold))
                    .foregroundStyle(
                        locationManager.locationStatus.needsSettingsAction
                        ? panelStyle.warningText
                        : panelStyle.primaryText
                    )
                    .padding(.bottom, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func scaledFont(_ points: CGFloat) -> CGFloat {
        max(14, points * CGFloat(mapLabelScale))
    }

    private var handleBar: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(panelStyle.divider.opacity(isInfoPanelExpanded ? 0.9 : 0.7))
                .frame(width: 86, height: 8)
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(height: OverlayLayout.handleHeight)
        .contentShape(Capsule())
    }

    private func panelHeight(for totalHeight: CGFloat) -> CGFloat {
        let compact = max(188, totalHeight * Self.compactPanelBaseFactor)
        let expanded = min(totalHeight * Self.expandedPanelBaseFactor, 620)
        let dragInfluence = max(-100, min(100, panelDragOffset))
        let height = isInfoPanelExpanded ? expanded : compact
        return min(expanded, max(compact, height - dragInfluence))
    }

    private func panelDragGesture(totalHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                panelDragOffset = max(-90, min(72, value.translation.height))
            }
            .onEnded { value in
                let translation = value.translation.height
                let predicted = value.predictedEndTranslation.height
                withAnimation(.easeInOut(duration: 0.2)) {
                    panelDragOffset = 0
                    if translation < -22 || predicted < -66 {
                        isInfoPanelExpanded = true
                    } else if translation > 22 || predicted > 66 {
                        isInfoPanelExpanded = false
                    }
                }
            }
    }

    private var panelStyle: LocationInfoPanelStyle {
        LocationInfoPanelStyle(nightMode: nightMode)
    }
}

private struct LocationInfoPanelStyle {
    let background: Color
    let primaryText: Color
    let secondaryText: Color
    let divider: Color
    let warningText: Color
    let accent: Color

    init(nightMode: Bool) {
        background = Color.black.opacity(0.94)
        divider = Color.white.opacity(0.85)
        warningText = .orange
        primaryText = nightMode ? Color(red: 1.0, green: 0.38, blue: 0.30) : .white
        secondaryText = nightMode ? Color(red: 1.0, green: 0.72, blue: 0.66) : Color(white: 0.94)
        accent = nightMode ? Color(red: 1.0, green: 0.46, blue: 0.35) : .blue
    }
}

private struct LocationMapView: View {
    let coordinate: CLLocationCoordinate2D?
    let locationStatus: LocationServiceStatus
    let allowsInteraction: Bool
    let mapLabelScale: Double
    @Environment(\.openURL) private var openURL
    @State private var hasInitializedCamera = false
    @State private var followsLocation = false
    @State private var isProgrammaticCameraUpdate = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapSpanMeters: CLLocationDistance = MapZoom.area

    private enum MapZoom {
        static let area: CLLocationDistance = 3_600
        static let minimum: CLLocationDistance = 600
        static let maximum: CLLocationDistance = 150_000
    }

    private let controlButtonSize: CGFloat = 93
    private let controlHitArea: CGFloat = 114
    private let controlButtonSpacing: CGFloat = 10
    /// Distance from the top edge. Decrease this value to move the controls up.
    private let controlOffsetTop: CGFloat = 100
    private let zoomStep: CLLocationDistance = 1.3

    private var snapshot: CoordinateSnapshot? {
        coordinate.map(CoordinateSnapshot.init)
    }

    var body: some View {
        Group {
            if let snapshot {
                ZStack(alignment: .topTrailing) {
                    Map(
                        position: $cameraPosition,
                        interactionModes: .all
                    ) {
                        Annotation("Current Location", coordinate: snapshot.coordinate) {
                            VStack(spacing: 2) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: scaledFont(28), weight: .semibold))
                                    .foregroundStyle(.blue)
                                    .shadow(radius: 2)
                                Text("You")
                                    .font(.system(size: scaledFont(20), weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.22))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        centerOnCurrentLocationIfNeeded(snapshot, shouldReset: true)
                    }
                    .onChange(of: snapshot) { _, newValue in
                        centerOnCurrentLocationIfNeeded(newValue, shouldReset: followsLocation)
                    }
                    .onChange(of: cameraPosition) { _, newValue in
                        guard !isProgrammaticCameraUpdate else {
                            isProgrammaticCameraUpdate = false
                            return
                        }
                        guard newValue.camera != nil || newValue.region != nil else { return }
                        followsLocation = false
                    }
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 5) {
                            Image(systemName: "road.lanes")
                            Text(ProductIdentity.displayName)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white.opacity(0.94))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.38), in: Capsule())
                        .padding(.top, 14)
                        .padding(.leading, 14)
                        .accessibilityHidden(true)
                    }

                    VStack(spacing: controlButtonSpacing) {
                        Text(mapScaleLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55), in: Capsule())
                            .accessibilityLabel("Map width \(mapScaleLabel)")

                        mapControlButton(systemName: "plus") {
                            adjustMapZoom(by: 1 / zoomStep)
                        }

                        mapControlButton(systemName: "minus") {
                            adjustMapZoom(by: zoomStep)
                        }

                        resetMapButton
                    }
                    .padding(.top, controlOffsetTop)
                    .padding(.trailing, 12)
                }
            } else {
                unavailableLocationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
            }
        }
    }

    private var unavailableLocationView: some View {
        ContentUnavailableView {
            Label(unavailableTitle, systemImage: locationStatus.needsSettingsAction ? "location.slash" : "location")
        } description: {
            Text(unavailableDescription)
        } actions: {
            if locationStatus.needsSettingsAction {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var unavailableTitle: String {
        switch locationStatus {
        case .idle:
            return "Start a Ride"
        case .denied, .restricted:
            return "Location Access Needed"
        case .placeUnavailable:
            return "Place Name Unavailable"
        case .locationUnavailable:
            return "Location Unavailable"
        case .checking, .waitingForPermission, .active:
            return "Waiting for GPS"
        }
    }

    private var unavailableDescription: String {
        switch locationStatus {
        case .idle:
            return "Tap Start ride when you are ready to begin."
        case .denied:
            return "Enable location access in Settings so \(ProductIdentity.displayName) can show where you are."
        case .restricted:
            return "Location access is restricted on this device."
        case .placeUnavailable, .locationUnavailable:
            return locationStatus.riderMessage
        case .checking, .waitingForPermission, .active:
            return "Location appears here once permission and GPS are available."
        }
    }

    private var currentMapCenter: CLLocationCoordinate2D? {
        if let region = cameraPosition.region {
            return region.center
        }

        if let camera = cameraPosition.camera {
            return camera.centerCoordinate
        }

        return nil
    }

    private func centerOnCurrentLocationIfNeeded(_ snapshot: CoordinateSnapshot, shouldReset: Bool) {
        if !hasInitializedCamera {
            hasInitializedCamera = true
            setCamera(to: snapshot.coordinate, spanMeters: mapSpanMeters)
            followsLocation = false
            return
        }

        guard shouldReset else { return }
        resetMap(to: snapshot.coordinate)
    }

    private func resetMap(to center: CLLocationCoordinate2D) {
        followsLocation = true
        moveCamera(to: center)
    }

    private func adjustMapZoom(by factor: CLLocationDistance) {
        guard let center = currentMapCenter ?? snapshot?.coordinate else { return }
        mapSpanMeters = clampSpan(mapSpanMeters * factor)
        setCamera(to: center, spanMeters: mapSpanMeters)
    }

    private func moveCamera(to coordinate: CLLocationCoordinate2D) {
        setCamera(to: coordinate, spanMeters: mapSpanMeters)
    }

    private func setCamera(to coordinate: CLLocationCoordinate2D, spanMeters: CLLocationDistance) {
        isProgrammaticCameraUpdate = true
        mapSpanMeters = clampSpan(spanMeters)
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: mapSpanMeters,
            longitudinalMeters: mapSpanMeters
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            cameraPosition = .region(region)
        }
    }

    private func mapControlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Color.clear
                    .frame(width: controlHitArea, height: controlHitArea)
                    .contentShape(Rectangle())

                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(red: 0.98, green: 0.98, blue: 0.98), lineWidth: 2.0)
                    .background(Color.clear)
                    .frame(width: controlButtonSize, height: controlButtonSize)
                    .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1)

                RoundedRectangle(cornerRadius: 12)
                    .inset(by: 3)
                    .stroke(Color(red: 0.86, green: 0.86, blue: 0.86), lineWidth: 1.2)
                    .frame(width: controlButtonSize, height: controlButtonSize)
                    .shadow(color: .black.opacity(0.75), radius: 2, x: 0, y: 1)

                Image(systemName: systemName)
                    .font(.system(size: scaledFont(29), weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.white)
                    .shadow(color: .black.opacity(0.9), radius: 2, x: 0, y: 1)
            }
            .frame(width: controlHitArea, height: controlHitArea, alignment: .center)
            .accessibilityLabel(systemName == "plus" ? "Zoom in" : "Zoom out")
            .accessibilityHint("Adjust map zoom")
        }
        .buttonStyle(.plain)
        .frame(width: controlHitArea, height: controlHitArea)
    }

    @ViewBuilder
    private var resetMapButton: some View {
        if let snapshot {
            Button(action: { resetMap(to: snapshot.coordinate) }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.98, green: 0.98, blue: 0.98), lineWidth: 2.0)
                        .background(Color.clear)
                        .frame(width: controlButtonSize, height: controlButtonSize)
                        .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1)

                    RoundedRectangle(cornerRadius: 12)
                        .inset(by: 3)
                        .stroke(Color(red: 0.86, green: 0.86, blue: 0.86), lineWidth: 1.2)
                        .frame(width: controlButtonSize, height: controlButtonSize)
                        .shadow(color: .black.opacity(0.75), radius: 2, x: 0, y: 1)

                    Image(systemName: "location.north")
                        .font(.system(size: scaledFont(26), weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.white)
                        .shadow(color: .black.opacity(0.9), radius: 2, x: 0, y: 1)
                }
                .frame(width: controlHitArea, height: controlHitArea, alignment: .center)
                .contentShape(Rectangle())
                .accessibilityHint("Move map center back to your current location and restore map following.")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset map to current location")
            .accessibilityHint("Moves map center back to your current location.")
        } else {
            EmptyView()
        }
    }

    private func clampSpan(_ meters: CLLocationDistance) -> CLLocationDistance {
        max(MapZoom.minimum, min(MapZoom.maximum, meters))
    }

    private var mapScaleLabel: String {
        if mapSpanMeters >= 1_000 {
            return String(format: "%.1f km", mapSpanMeters / 1_000)
        }
        return "\(Int(mapSpanMeters.rounded())) m"
    }

    private func scaledFont(_ points: CGFloat) -> CGFloat {
        max(15, points * CGFloat(mapLabelScale))
    }
}

private struct CoordinateSnapshot: Equatable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees

    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationManager: LocationManager
    @Binding var showResetConfirmation: Bool
    @ObservedObject var aiSharingConsent: AISharingConsentStore
    let onClearLocalData: () -> Void
    @ObservedObject var rideDiagnostics: RideDiagnosticsStore
    @State private var lastNonQuietMode: ContentMode = .shortFacts
    @State private var showPrivacyNotice = false
    @State private var showClearLocalDataConfirmation = false
    @AppStorage("RideHorizonMapLabelScale") private var mapLabelScale = 1.0
    @AppStorage("RideHorizonNightMode") private var nightMode = false
#if DEBUG
    @ObservedObject var debugLog: DebugLogStore
    @AppStorage(ProxyDiagnostics.enabledKey) private var proxyDiagnosticsEnabled = false
#endif

    let intervals = [1, 2, 5, 10, 15, 30, 60, 120, 300]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SettingsCard(title: "Build", palette: palette) {
                        Text(AppBuildMetadata.titlePrimaryLabel)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(palette.primaryText)

                        Text(AppBuildMetadata.titleTimestampLabel)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)

                        Text("Use this version and build when reporting beta feedback.")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)
                    }

                    SettingsCard(title: "Announcements", palette: palette) {
                    Text("Choose when and how \(ProductIdentity.displayName) should speak while you ride.")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.secondaryText)
                        .listRowBackground(palette.rowBackground)

                    SettingsToggleRow(
                        title: "Quiet mode",
                        subtitle: "Stop \(ProductIdentity.displayName) speaking.",
                        isOn: Binding(
                            get: { locationManager.contentMode == .quiet },
                            set: { isQuiet in
                                if isQuiet {
                                    if locationManager.contentMode != .quiet {
                                        lastNonQuietMode = locationManager.contentMode
                                        locationManager.lastNonQuietContentMode = lastNonQuietMode
                                    }
                                    locationManager.contentMode = .quiet
                                } else {
                                    locationManager.contentMode = locationManager.lastNonQuietContentMode
                                }
                            }
                        ),
                        palette: palette
                    )

                    SettingsToggleRow(
                        title: "Interrupt music while speaking",
                        subtitle: "Pause other audio while RideHorizon is visible. Background announcements mix so navigation keeps priority.",
                        isOn: $locationManager.interruptsMusic,
                        palette: palette
                    )

                    Text("Defaults: other audio is interrupted only while RideHorizon is speaking.")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.secondaryText)
                        .padding(.bottom, 2)
                        .listRowBackground(palette.rowBackground)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Announcement style")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(palette.primaryText)
                        Picker("Announcement style", selection: $locationManager.contentMode) {
                            ForEach(ContentMode.allCases) { mode in
                                Text(mode.label)
                                    .tag(mode)
                                    .disabled(mode.factMode != nil && !aiSharingConsent.isGranted)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.title3.weight(.semibold))
                        .tint(palette.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(palette.rowBackground)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Apple voice")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(palette.primaryText)
                        Picker("Apple voice", selection: $locationManager.preferredVoiceIdentifier) {
                            ForEach(locationManager.availableSpeechVoices()) { voice in
                                Text(voice.pickerLabel).tag(voice.identifier)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(locationManager.speechProvider != .apple)
                        .font(.title3.weight(.semibold))
                        .tint(palette.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(palette.rowBackground)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speech provider")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(palette.primaryText)
                        Picker("Speech provider", selection: $locationManager.speechProvider) {
                            ForEach(SpeechProvider.allCases) { provider in
                                Text(provider.label)
                                    .tag(provider)
                                    .disabled(provider == .proxyElevenLabs && !aiSharingConsent.isGranted)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.title3.weight(.semibold))
                        .tint(palette.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(palette.rowBackground)

                    if let recommendation = locationManager.recommendedSpeechVoice() {
                        Text("Recommended: \(recommendation.displayName) \(recommendation.localeIdentifier)")
                            .font(.body)
                            .foregroundStyle(palette.secondaryText)
                            .padding(.vertical, 2)
                            .listRowBackground(palette.rowBackground)
                    }

                    Button("Preview voice") {
                        locationManager.previewSelectedVoice()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.title3.weight(.semibold))
                    .tint(palette.accent)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
                    .listRowBackground(palette.rowBackground)
                    }

                    SettingsCard(title: "When to announce", palette: palette) {
                    Text("Set which new boundary should trigger speech.")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.secondaryText)
                        .listRowBackground(palette.rowBackground)

                    SectionToggleRows(locationManager: locationManager, palette: palette)

                    Text("Set the minimum delay after one boundary announcement before \(ProductIdentity.displayName) can announce again.")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.secondaryText)
                        .listRowBackground(palette.rowBackground)

                    Text(
                        boundarySpeechSummary(seconds: locationManager.boundarySpeechCooldownSeconds)
                    )
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.secondaryText)
                    .listRowBackground(palette.rowBackground)

                    HStack {
                        Text("Boundary trigger delay")
                            .font(.title3)
                        Spacer()
                        Text("\(locationManager.boundarySpeechCooldownSeconds) sec")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(palette.primaryText)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(locationManager.boundarySpeechCooldownSeconds) },
                            set: { locationManager.boundarySpeechCooldownSeconds = Int($0) }
                        ),
                        in: 0...60,
                        step: 1
                    )
                    .tint(palette.accent)
                    .listRowBackground(palette.rowBackground)
                    }

                    SettingsCard(title: "Rider Context", palette: palette) {
                    Text("Help \(ProductIdentity.displayName) avoid obvious facts about places you already know.")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.secondaryText)
                        .listRowBackground(palette.rowBackground)

                    SettingsTextFieldRow(
                        title: "Which country are you most familiar with?",
                        example: "Example: United Kingdom",
                        text: $locationManager.homeCountry,
                        palette: palette
                    )

                    SettingsTextFieldRow(
                        title: "Which region do you know best?",
                        example: "Example: Cornwall",
                        text: $locationManager.homeRegion,
                        palette: palette
                    )

                    SettingsTextFieldRow(
                        title: "Which places should \(ProductIdentity.displayName) treat as familiar?",
                        example: "Example: Somerset, Devon, London",
                        text: $locationManager.familiarRegions,
                        palette: palette
                    )

                    Text("Use these values to prioritise useful local context.")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.secondaryText)
                        .listRowBackground(palette.rowBackground)
                    FactInterestCategoryPicker(selectedCategories: $locationManager.factInterestCategories, palette: palette)
                    }

                    SettingsCard(title: "Privacy", palette: palette) {
                    Text("Choose whether RideHorizon may send place information and optional preferences to OpenAI, and announcement text to ElevenLabs for Premium Voice.")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.secondaryText)

                    SettingsToggleRow(
                        title: "Third-party AI features",
                        subtitle: aiSharingConsent.isGranted
                            ? "Allowed. You can withdraw permission at any time."
                            : "Off. Facts use place names and speech uses Apple Voice on this device.",
                        isOn: Binding(
                            get: { aiSharingConsent.isGranted },
                            set: { isAllowed in
                                if isAllowed {
                                    aiSharingConsent.grant()
                                } else {
                                    aiSharingConsent.decline()
                                }
                                locationManager.applyAISharingDecision(isGranted: isAllowed)
                            }
                        ),
                        palette: palette
                    )

                    Button("Read privacy notice") {
                        showPrivacyNotice = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 50)

                    Button("Clear local data and access", role: .destructive) {
                        showClearLocalDataConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 50)

                    Text("Clearing removes settings, cached facts, ride history, release diagnostics, consent, the installation identifier and the proxy access credential. Access will be provisioned automatically when needed.")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                    }

                    SettingsCard(title: "Advanced", palette: palette) {
                    SettingsToggleRow(
                        title: "Night mode",
                        subtitle: "Use red text on black for night riding.",
                        isOn: $nightMode,
                        palette: palette
                    )

                    Text("Location update frequency")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(palette.primaryText)
                        .listRowBackground(palette.rowBackground)

                    Picker("Location update frequency", selection: $locationManager.locationCheckInterval) {
                        ForEach(intervals, id: \.self) { interval in
                            Text("\(interval) seconds").tag(interval)
                        }
                    }
                    .font(.title3)
                    .tint(palette.accent)
                    .listRowBackground(palette.rowBackground)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Map label scale: \(mapLabelScale, specifier: "%.1f")x")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(palette.primaryText)
                        Slider(value: $mapLabelScale, in: 0.8...1.8, step: 0.1)
                        Text("Larger values make map and overlay text easier to read while riding.")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(palette.secondaryText)
                        .listRowBackground(palette.rowBackground)
                    }
                    .listRowBackground(palette.rowBackground)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bluetooth audio delay: \(locationManager.bluetoothDelaySeconds, specifier: "%.1f")s")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(palette.primaryText)
                        Slider(
                            value: $locationManager.bluetoothDelaySeconds,
                            in: 0...3,
                            step: 0.1
                        )
                        .padding(.bottom, 2)
                    }
                    .listRowBackground(palette.rowBackground)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom fact focus")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(palette.primaryText)

                        SettingsTextFieldRow(
                            title: "What else should facts focus on?",
                            example: "Example: engineering details, old roads, old rail.",
                            text: $locationManager.customFactInstructions,
                            palette: palette
                        )

                        Text("Optional: add one short note to change fact focus across all themes.")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(palette.secondaryText)
                            .listRowBackground(palette.rowBackground)
                    }
                    .listRowBackground(palette.rowBackground)

                    DisclosureGroup("Release diagnostics") {
                        Text("Local audio, ride-session and app-lifecycle events. Retained for at most 7 days, 2,000 events or 1 MiB. Coordinates, spoken text and credentials are never recorded.")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)

                        Text("View, export or clear diagnostics only while safely stopped.")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)

                        Text("\(rideDiagnostics.entries.count) retained events")
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)

                        ForEach(Array(rideDiagnostics.entries.suffix(20).reversed())) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.event.rawValue)
                                    .font(.callout.monospaced())
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ShareLink(item: rideDiagnostics.exportURL) {
                            Label("Export diagnostics", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)

                        Button("Clear diagnostics", role: .destructive) {
                            rideDiagnostics.clear()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }

                    DisclosureGroup("Developer") {
                        SettingsToggleRow(
                            title: "Test Mode",
                            subtitle: "Use the Gloucestershire test route.",
                            isOn: $locationManager.testMode,
                            palette: palette
                        )
#if DEBUG
                        SettingsToggleRow(
                            title: "Short inactivity timeout",
                            subtitle: "Next ride: 30 seconds inactive, then 30 seconds to respond.",
                            isOn: $locationManager.shortInactivityTimeout,
                            palette: palette
                        )
                        .disabled(locationManager.rideSessionState.isActive)
#endif
                        SettingsToggleRow(
                            title: "Allow Apple fallback for Premium Voice",
                            subtitle: "Feature flag. Off shows Premium Voice errors instead of speaking Apple.",
                            isOn: $locationManager.premiumVoiceAppleFallbackEnabled,
                            palette: palette
                        )
                        SettingsToggleRow(
                            title: "Speak after every location lookup",
                            subtitle: "Developer-only noisy speech mode.",
                            isOn: $locationManager.speakAfterEveryGeocode,
                            palette: palette
                        )

#if INTERNAL_AUDIO_CALIBRATION
                        NavigationLink {
                            SpeechCalibrationLabView(locationManager: locationManager)
                        } label: {
                            Label("Speech Calibration", systemImage: "waveform.badge.magnifyingglass")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
#endif

#if DEBUG
                        DisclosureGroup("Proxy Diagnostics") {
                            SettingsToggleRow(
                                title: "Enabled",
                                subtitle: "Show proxy HTTP diagnostics in the app.",
                                isOn: $proxyDiagnosticsEnabled,
                                palette: palette
                            )
                                .onChange(of: proxyDiagnosticsEnabled) { _, isEnabled in
                                    if !isEnabled {
                                        debugLog.clear()
                                    }
                                }

                            if proxyDiagnosticsEnabled {
                                DebugLogInlineView(debugLog: debugLog)
                            }
                        }
#endif

                        Button("Reset First-Time Experience", role: .destructive) {
                            showResetConfirmation = true
                        }
                    }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .background(palette.pageBackground)
            .foregroundStyle(palette.primaryText)
            .tint(palette.accent)
            .environment(\.colorScheme, .dark)
            .onAppear {
                lastNonQuietMode = locationManager.lastNonQuietContentMode

                if locationManager.contentMode != .quiet {
                    lastNonQuietMode = locationManager.contentMode
                }
            }
            .onChange(of: locationManager.contentMode) { _, newMode in
                if newMode.factMode != nil, !aiSharingConsent.isGranted {
                    locationManager.contentMode = .namesOnly
                    return
                }
                guard newMode != .quiet else { return }
                lastNonQuietMode = newMode
                locationManager.lastNonQuietContentMode = newMode
            }
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showPrivacyNotice) {
            PrivacyNoticeView()
        }
        .alert("Clear local RideHorizon data?", isPresented: $showClearLocalDataConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear data", role: .destructive) {
                onClearLocalData()
            }
        } message: {
            Text("This removes local settings, cached facts, ride history, release diagnostics, consent and proxy access from this iPhone. It does not yet submit a remote deletion request.")
        }
    }

    private var palette: SettingsPalette {
        SettingsPalette(nightMode: nightMode)
    }

    private func boundarySpeechSummary(seconds: Int) -> String {
        if seconds == 0 {
            "Announcements speak on every boundary change."
        } else {
            "Minimum gap: \(seconds) second\(seconds == 1 ? "" : "s") between boundary announcements."
        }
    }
}

private struct SettingsPalette {
    let pageBackground: Color
    let sectionBackground: Color
    let rowBackground: Color
    let fieldBackground: Color
    let fieldBorder: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color

    init(nightMode: Bool) {
        let nightPrimary = Color(red: 1.0, green: 0.30, blue: 0.18)
        pageBackground = Color.black
        sectionBackground = Color(red: 0.07, green: 0.07, blue: 0.07)
        rowBackground = nightMode ? Color(red: 0.08, green: 0.08, blue: 0.08) : Color(red: 0.12, green: 0.12, blue: 0.12)
        fieldBackground = nightMode ? Color(red: 0.03, green: 0.03, blue: 0.03) : Color(red: 0.18, green: 0.18, blue: 0.18)
        fieldBorder = nightMode ? Color(red: 0.85, green: 0.20, blue: 0.14) : Color(red: 0.55, green: 0.55, blue: 0.55)
        primaryText = nightMode ? nightPrimary : Color(red: 0.97, green: 0.97, blue: 0.97)
        secondaryText = nightMode ? Color(red: 1.0, green: 0.76, blue: 0.68) : Color(red: 0.92, green: 0.92, blue: 0.92)
        accent = nightMode ? Color(red: 1.0, green: 0.45, blue: 0.35) : Color(red: 0.00, green: 0.48, blue: 1.00)
    }
}

private struct SettingsSectionHeader: View {
    let title: String
    let palette: SettingsPalette

    init(_ title: String, palette: SettingsPalette) {
        self.title = title
        self.palette = palette
    }

    var body: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .foregroundStyle(palette.primaryText)
            .textCase(nil)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let palette: SettingsPalette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(title, palette: palette)
                .padding(.top, 0)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(palette.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let palette: SettingsPalette

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)
                    if let subtitle {
                        Text(subtitle)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(3)
                    }
                }

                Spacer(minLength: 12)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(palette.accent)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 72)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(palette.rowBackground)
        }
        .buttonStyle(.plain)
        .listRowBackground(palette.rowBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subtitle == nil ? title : "\(title). \(subtitle!)")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

private struct SettingsTextFieldRow: View {
    let title: String
    let example: String
    @Binding var text: String
    let palette: SettingsPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Optional", text: $text, prompt: Text("Optional"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .textContentType(.none)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(palette.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(palette.fieldBorder, lineWidth: 1)
                )

            Text(example)
                .font(.callout.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .listRowBackground(palette.rowBackground)
    }
}

private struct SectionToggleRows: View {
    @ObservedObject var locationManager: LocationManager
    let palette: SettingsPalette

    var body: some View {
        Group {
            SectionToggle(title: "Road", isOn: $locationManager.announceStreet, palette: palette)
            SectionToggle(title: "Town", isOn: $locationManager.announceTown, palette: palette)
            SectionToggle(title: "County", isOn: $locationManager.announceCounty, palette: palette)
            SectionToggle(title: "Region", isOn: $locationManager.announceNation, palette: palette)
            SectionToggle(title: "Country", isOn: $locationManager.announceCountry, palette: palette)
        }
    }
}

private struct SectionToggle: View {
    let title: String
    @Binding var isOn: Bool
    let palette: SettingsPalette

    var body: some View {
        SettingsToggleRow(title: title, subtitle: nil, isOn: $isOn, palette: palette)
    }
}

private struct FactInterestCategoryPicker: View {
    @Binding var selectedCategories: [FactInterestCategory]
    let palette: SettingsPalette

    var body: some View {
        ForEach(FactInterestCategory.allCases) { category in
            SettingsToggleRow(
                title: category.label,
                subtitle: category.prompt,
                isOn: Binding(
                    get: { selectedCategories.contains(category) },
                    set: { isSelected in
                        var set = Set(selectedCategories)
                        if isSelected {
                            set.insert(category)
                        } else {
                            set.remove(category)
                        }
                        selectedCategories = FactInterestCategory.allCases
                            .filter { set.contains($0) }
                    }
                ),
                palette: palette
            )
        }
    }
}

private struct LogHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationManager: LocationManager
    @Binding var logs: [RideLogEntry]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    if logs.isEmpty {
                        ContentUnavailableView(
                            "No log entries yet",
                            systemImage: "list.bullet",
                            description: Text("Place changes and manual test steps appear here.")
                        )
                    } else {
                        ForEach(logs) { log in
                            LogRow(log: log, showSpokenPhrase: true)
                        }
                    }
                }

                Button(action: logCurrentLocation) {
                    Label(locationManager.testMode ? "Next test location" : "Log current location", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
            }
            .navigationTitle("Log")
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func logCurrentLocation() {
        if locationManager.testMode {
            locationManager.advanceTestLocation()
            return
        }

        locationManager.requestLocation()

        if let location = locationManager.lastKnownLocation,
           let address = locationManager.lastKnownAddress {
            logs.insert(
                RideLogEntry(
                    timestamp: Date(),
                    location: location,
                    address: address,
                    utteredPhrase: nil
                ),
                at: 0
            )
            AppDiagnostics.log("Manual ride log entry added.")
        } else {
            AppDiagnostics.log("Location or address not available for manual log entry.")
        }
    }
}

private struct LogRow: View {
    let log: RideLogEntry
    let showSpokenPhrase: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocationSummaryFormatter.summary(for: log.address))
                .font(.headline)

            if showSpokenPhrase, let phrase = log.utteredPhrase {
                Text("Spoke: \(phrase)")
                    .font(.subheadline)
            }

            Text("\(log.address.administrativeArea), \(log.address.country)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(isoDateFormatter.string(from: log.timestamp))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(log.location.latitude, specifier: "%.5f"), \(log.location.longitude, specifier: "%.5f")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
private struct DebugLogInlineView: View {
    @ObservedObject var debugLog: DebugLogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(debugLog.entries.count) events")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") {
                    debugLog.clear()
                }
                .disabled(debugLog.entries.isEmpty)
            }

            if debugLog.entries.isEmpty {
                Text("No debug events yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(debugLog.entries.prefix(30)) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.category)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(isoDateFormatter.string(from: entry.timestamp))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.message)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
#endif

private let isoDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

private enum AppBuildMetadata {
    private static let buildDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static var versionLabel: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let buildStamp = formattedBuildTimestamp(buildNumber) ?? buildNumber
        return "RideHorizon v\(shortVersion)  ·  \(buildStamp)"
    }

    static var titleDetailLabel: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let buildStamp = formattedBuildTimestamp(buildNumber) ?? "build \(buildNumber)"
        return "v\(shortVersion)  ·  \(buildStamp)"
    }

    static var titlePrimaryLabel: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        return "RideHorizon v\(shortVersion)"
    }

    static var titleTimestampLabel: String {
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "Build \(buildNumber)"
    }

    static func shouldShow(testMode: Bool) -> Bool {
        return testMode
    }

    private static func formattedBuildTimestamp(_ buildNumber: String) -> String? {
        let compact = buildNumber.replacingOccurrences(of: ".", with: "")
        if compact.count >= 8 {
            let datePart = String(compact.prefix(8))
            let timePart = compact.count > 8 ? String(compact.dropFirst(8).prefix(4)) : nil
            let parseInput = timePart == nil ? "\(datePart)0000" : "\(datePart)\(timePart!)"
            let parser = DateFormatter()
            parser.dateFormat = "yyyyMMddHHmm"
            parser.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = parser.date(from: parseInput) {
                return "build \(buildDateFormatter.string(from: date)) UTC"
            }
        }
        return nil
    }
}
