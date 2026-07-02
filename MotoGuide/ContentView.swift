import SwiftUI
import CoreLocation
import MapKit
import UIKit

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
            ("street", "Street", address.flatMap { valid($0.street) }),
            ("town", "Town", address.flatMap { valid($0.town) }),
            ("county", "County", address.flatMap { valid($0.county) }),
            ("region", "Region", address.flatMap { valid($0.administrativeArea) }),
            ("country", "Country", address.flatMap { valid($0.country) })
        ]
        let currentID = values.first { $0.value != nil }?.id

        return values.map { item in
            LocationHierarchyRow(
                id: item.id,
                label: item.label,
                value: item.value ?? "Unavailable",
                isCurrent: item.id == currentID,
                isAvailable: item.value != nil
            )
        }
    }

    private static func valid(_ value: String) -> String? {
        Address.isValidPlaceName(value) ? value : nil
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var firstRunState = FirstRunState()
    @AppStorage("MotoGuideMapLabelScale") private var mapLabelScale = 1.0
#if DEBUG
    @StateObject private var debugLog = DebugLogStore.shared
#endif
    @State private var logs: [RideLogEntry] = []
    @State private var showOnboarding = false
    @State private var showResetConfirmation = false
    @State private var showResetCompleteMessage = false
    @State private var showSettings = false
    @State private var showLog = false

    var body: some View {
        NavigationStack {
            LocationScreenView(
                locationManager: locationManager,
                onRepeat: {
                    locationManager.repeatCurrentAnnouncement()
                },
                mapLabelScale: mapLabelScale
            )
            .navigationTitle("Moto Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Moto Guide")
                        .font(.headline.weight(.semibold))
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
            showOnboarding = firstRunState.needsOnboarding
            if !firstRunState.needsOnboarding {
                startRideIfNeeded()
            }
        }
        .sheet(isPresented: $showSettings) {
#if DEBUG
            SettingsView(
                locationManager: locationManager,
                showResetConfirmation: $showResetConfirmation,
                debugLog: debugLog
            )
#else
            SettingsView(
                locationManager: locationManager,
                showResetConfirmation: $showResetConfirmation
            )
#endif
        }
        .sheet(isPresented: $showLog) {
            LogHistoryView(locationManager: locationManager, logs: $logs)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(firstRunState: firstRunState) {
                showOnboarding = false
                startRideIfNeeded()
            }
        }
        .alert("Reset First-Time Experience?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetFirstRunExperience()
            }
        } message: {
            Text("Clears onboarding state so MotoGuide behaves like a fresh install. Onboarding will appear again immediately.")
        }
        .alert("First-time experience reset", isPresented: $showResetCompleteMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Onboarding is showing again. No app restart needed.")
        }
    }

    private func startRideIfNeeded() {
        locationManager.beginRideTracking()
        locationManager.requestLocation()
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
        print("Log added: \(entry.timestamp) - \(location.latitude), \(location.longitude) - \(address.toJSON() ?? "N/A")")
    }
}

private struct LocationScreenView: View {
    @ObservedObject var locationManager: LocationManager
    let onRepeat: () -> Void
    let mapLabelScale: Double
    @AppStorage("MotoGuideRepeatHintDismissed") private var repeatHintDismissed = false

    private enum OverlayLayout {
        static let horizontalPad: CGFloat = 12
        static let verticalPad: CGFloat = 8
        static let cornerRadius: CGFloat = 12
        static let summaryLineLimit: Int = 2
        static let hierarchyLineLimit: Int = 1
        static let phraseLineLimit: Int = 3
        static let panelBackgroundOpacity: Double = 0.82
        static let panelTextColor: Color = .white
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LocationMapView(
                coordinate: locationManager.lastKnownLocation,
                locationStatus: locationManager.locationStatus,
                allowsInteraction: locationManager.allowsMapInteraction,
                mapLabelScale: mapLabelScale
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: OverlayLayout.verticalPad) {
                currentInformationPanel
                    .contentShape(Rectangle())
                    .onTapGesture {
                        repeatHintDismissed = true
                        onRepeat()
                    }
                statusPanel
                if locationManager.testMode {
                    Button {
                        locationManager.logTestLocation()
                    } label: {
                        Label("Next test location", systemImage: "arrow.forward.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, OverlayLayout.horizontalPad)
            .padding(.bottom, OverlayLayout.horizontalPad)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var currentInformationPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocationSummaryFormatter.summary(for: locationManager.lastKnownAddress))
                .font(.system(size: scaledFont(24)))
                .fontWeight(.semibold)
                .foregroundStyle(OverlayLayout.panelTextColor)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(OverlayLayout.summaryLineLimit)

            if let contextLine = LocationSummaryFormatter.contextLine(for: locationManager.lastKnownAddress) {
                Text(contextLine)
                    .font(.system(size: scaledFont(18)))
                    .foregroundStyle(OverlayLayout.panelTextColor.opacity(0.9))
                    .lineLimit(OverlayLayout.hierarchyLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !repeatHintDismissed {
                Label("Tap the place name to repeat it", systemImage: "speaker.wave.2")
                    .font(.system(size: scaledFont(14)))
                    .fontWeight(.medium)
                    .foregroundStyle(OverlayLayout.panelTextColor.opacity(0.92))
                    .padding(.top, 2)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Label("Location status", systemImage: "location")
                    .font(.system(size: scaledFont(11)))
                    .foregroundStyle(Color.white.opacity(0.85))
                Label(locationManager.locationStatus.riderMessage, systemImage: locationManager.locationStatus.needsSettingsAction ? "location.slash" : "location")
                    .font(.system(size: scaledFont(13)))
                    .foregroundStyle(locationManager.locationStatus.needsSettingsAction ? .orange : Color.white.opacity(0.9))
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Last spoken phrase")
                    .font(.system(size: scaledFont(12)))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .textCase(.uppercase)
                Text(locationManager.lastSpokenPhrase ?? "No spoken phrase yet")
                    .font(.system(size: scaledFont(17)))
                    .foregroundStyle(OverlayLayout.panelTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(OverlayLayout.phraseLineLimit)
                if let timestamp = locationManager.lastSpokenAt {
                    Text(isoDateFormatter.string(from: timestamp))
                        .font(.system(size: scaledFont(11)))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        }
        .padding()
        .background(Color.black.opacity(OverlayLayout.panelBackgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: OverlayLayout.cornerRadius))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to repeat the current location announcement.")
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(locationManager.contentMode.label)
                    .font(.system(size: scaledFont(16)))
                    .fontWeight(.semibold)
                    .foregroundStyle(OverlayLayout.panelTextColor)
                Spacer()
                if locationManager.contentMode == .quiet {
                    Label("Quiet", systemImage: "speaker.slash.fill")
                        .font(.system(size: scaledFont(12)))
                        .foregroundStyle(.orange)
                } else {
                    Label("Always running", systemImage: "location.fill")
                        .font(.system(size: scaledFont(12)))
                        .foregroundStyle(OverlayLayout.panelTextColor.opacity(0.9))
                }
                if !locationManager.allowsMapInteraction {
                    Label("Map locked", systemImage: "lock.fill")
                        .font(.system(size: scaledFont(12)))
                        .foregroundStyle(OverlayLayout.panelTextColor.opacity(0.8))
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(OverlayLayout.panelBackgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func scaledFont(_ points: CGFloat) -> CGFloat {
        max(11, points * CGFloat(mapLabelScale))
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
        static let area: CLLocationDistance = 16_000
        static let minimum: CLLocationDistance = 2_000
        static let maximum: CLLocationDistance = 120_000
    }

    private let controlButtonSize: CGFloat = 52

    private var snapshot: CoordinateSnapshot? {
        coordinate.map(CoordinateSnapshot.init)
    }

    var body: some View {
        Group {
            if let snapshot {
                ZStack(alignment: .topTrailing) {
                    Map(
                        position: $cameraPosition,
                        interactionModes: allowsInteraction ? .all : []
                    ) {
                        Annotation("Current Location", coordinate: snapshot.coordinate) {
                            VStack(spacing: 2) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: scaledFont(28), weight: .semibold))
                                    .foregroundStyle(.blue)
                                    .shadow(radius: 2)
                                Text("You")
                                    .font(.system(size: scaledFont(16), weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.55))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        centerOnCurrentLocationIfNeeded(snapshot)
                    }
                    .onChange(of: snapshot) { _, newValue in
                        centerOnCurrentLocationIfNeeded(newValue)
                    }
                    .onChange(of: cameraPosition) {
                        guard !isProgrammaticCameraUpdate else {
                            isProgrammaticCameraUpdate = false
                            return
                        }
                        followsLocation = false
                    }

                VStack(spacing: 10) {
                        mapControlButton(systemName: "plus") {
                            adjustMapZoom(by: 0.8)
                        }

                        mapControlButton(systemName: "minus") {
                            adjustMapZoom(by: 1.25)
                        }

                        Button {
                            resetMap(to: snapshot.coordinate)
                        } label: {
                            Label("Reset", systemImage: "location.magnifyingglass")
                                .font(.system(size: scaledFont(15), weight: .semibold))
                                .lineLimit(1)
                                .frame(minWidth: controlButtonSize, minHeight: 24)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.35))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                        }
                        .foregroundStyle(Color.white)
                    }
                    .padding(.top, 12)
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
        case .denied:
            return "Enable location access in Settings so MotoGuide can show where you are."
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

    private func centerOnCurrentLocationIfNeeded(_ snapshot: CoordinateSnapshot) {
        if !hasInitializedCamera {
            hasInitializedCamera = true
            moveCamera(to: snapshot.coordinate)
            return
        }

        if followsLocation {
            moveCamera(to: snapshot.coordinate)
        }
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
            Image(systemName: systemName)
                .font(.system(size: scaledFont(24), weight: .bold))
                .frame(width: controlButtonSize, height: controlButtonSize)
                .foregroundStyle(Color.white)
                .background(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func clampSpan(_ meters: CLLocationDistance) -> CLLocationDistance {
        max(MapZoom.minimum, min(MapZoom.maximum, meters))
    }

    private func scaledFont(_ points: CGFloat) -> CGFloat {
        max(11, points * CGFloat(mapLabelScale))
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
    @State private var lastNonQuietMode: ContentMode = .shortFacts
    private static let lastNonQuietModeKey = "MotoGuideLastNonQuietContentMode"
    @AppStorage("MotoGuideMapLabelScale") private var mapLabelScale = 1.0
#if DEBUG
    @ObservedObject var debugLog: DebugLogStore
    @AppStorage(ProxyDiagnostics.enabledKey) private var proxyDiagnosticsEnabled = false
#endif

    let intervals = [1, 2, 5, 10, 15, 30, 60, 120, 300]

    var body: some View {
        NavigationStack {
            Form {
                Section("Announcements") {
                    Toggle(
                        "Quiet Mode",
                        isOn: Binding(
                            get: { locationManager.contentMode == .quiet },
                            set: { isQuiet in
                                if isQuiet {
                                    if locationManager.contentMode != .quiet {
                                        lastNonQuietMode = locationManager.contentMode
                                        UserDefaults.standard.set(
                                            lastNonQuietMode.rawValue,
                                            forKey: Self.lastNonQuietModeKey
                                        )
                                    }
                                    locationManager.contentMode = .quiet
                                } else {
                                    let savedMode = UserDefaults.standard.string(forKey: Self.lastNonQuietModeKey)
                                        .flatMap(ContentMode.init(rawValue:))
                                    locationManager.contentMode = savedMode ?? lastNonQuietMode
                                }
                            }
                        )
                    )

                    Picker("Announcement Style", selection: $locationManager.contentMode) {
                        ForEach(ContentMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }

                    Picker("Voice", selection: $locationManager.preferredVoiceIdentifier) {
                        ForEach(locationManager.availableSpeechVoices()) { voice in
                            Text(voice.pickerLabel).tag(voice.identifier)
                        }
                    }
                    .disabled(locationManager.speechProvider != .apple)

                    Picker("Speech provider", selection: $locationManager.speechProvider) {
                        ForEach(SpeechProvider.allCases) { provider in
                            Text(provider.label).tag(provider)
                        }
                    }

                    if let recommendation = locationManager.recommendedSpeechVoice() {
                        Text("Recommended: \(recommendation.displayName) \(recommendation.localeIdentifier)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Preview voice") {
                        locationManager.previewSelectedVoice()
                    }
                    .buttonStyle(.bordered)

                    if let phrase = locationManager.lastSpokenPhrase {
                        Text("Current voice phrase: \(phrase)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    SectionToggleRows(locationManager: locationManager)
                }

                Section("Rider Context") {
                    TextField(
                        "Home country",
                        text: $locationManager.homeCountry,
                        prompt: Text("Example: United Kingdom")
                    )
                    TextField(
                        "Home region",
                        text: $locationManager.homeRegion,
                        prompt: Text("Example: West Midlands")
                    )
                    TextField(
                        "Places you already know",
                        text: $locationManager.familiarRegions,
                        prompt: Text("Example: England, Cotswolds")
                    )
                        .textInputAutocapitalization(.words)

                    Text("What should the fact feed focus on?")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Answering these once helps avoid basic explanations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    FactInterestCategoryPicker(selectedCategories: $locationManager.factInterestCategories)
                }

                Section("Advanced") {
                    Picker("Location check frequency", selection: $locationManager.locationCheckInterval) {
                        ForEach(intervals, id: \.self) { interval in
                            Text("\(interval) seconds").tag(interval)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Map label scale: \(mapLabelScale, specifier: "%.1f")x")
                            .font(.headline)
                        Slider(value: $mapLabelScale, in: 0.8...1.8, step: 0.1)
                        Text("Larger values make on-map labels and overlay text easier to read while riding.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bluetooth Audio Delay: \(locationManager.bluetoothDelaySeconds, specifier: "%.1f")s")
                        Slider(
                            value: $locationManager.bluetoothDelaySeconds,
                            in: 0...3,
                            step: 0.1
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom fact focus (advanced)")
                            .font(.headline)

                        TextField(
                            "Custom preference note",
                            text: $locationManager.customFactInstructions,
                            prompt: Text("Example: engineering details, old roads, old rail.")
                        )
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()

                        Text("Optional free-form preference for all fact themes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    DisclosureGroup("Developer") {
                        Toggle("Test Mode", isOn: $locationManager.testMode)
                        Toggle("Speak After Every Geocode", isOn: $locationManager.speakAfterEveryGeocode)

#if DEBUG
                        DisclosureGroup("Proxy Diagnostics") {
                            Toggle("Enabled", isOn: $proxyDiagnosticsEnabled)
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
            .navigationTitle("Settings")
            .onAppear {
                if let savedMode = UserDefaults.standard.string(forKey: Self.lastNonQuietModeKey),
                   let savedContentMode = ContentMode(rawValue: savedMode) {
                    lastNonQuietMode = savedContentMode
                }

                if locationManager.contentMode != .quiet {
                    lastNonQuietMode = locationManager.contentMode
                }
            }
            .onChange(of: locationManager.contentMode) { _, newMode in
                guard newMode != .quiet else { return }
                lastNonQuietMode = newMode
                UserDefaults.standard.set(newMode.rawValue, forKey: Self.lastNonQuietModeKey)
            }
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct SectionToggleRows: View {
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        DisclosureGroup("What to announce") {
            Toggle("Street", isOn: $locationManager.announceStreet)
            Toggle("Town", isOn: $locationManager.announceTown)
            Toggle("County", isOn: $locationManager.announceCounty)
            Toggle("Region", isOn: $locationManager.announceNation)
            Toggle("Country", isOn: $locationManager.announceCountry)
        }
    }
}

private struct FactInterestCategoryPicker: View {
    @Binding var selectedCategories: [FactInterestCategory]

    var body: some View {
        ForEach(FactInterestCategory.allCases) { category in
            VStack(alignment: .leading, spacing: 2) {
                Toggle(
                    category.label,
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
                    )
                )
                Text(category.prompt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 32)
            }
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
            locationManager.logTestLocation()
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
            print("Log added: \(Date()) - \(location.latitude), \(location.longitude) - \(address.toJSON() ?? "N/A")")
        } else {
            print("Location or address not available")
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
