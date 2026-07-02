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
            LocationScreenView(locationManager: locationManager) {
                locationManager.repeatCurrentAnnouncement()
            }
            .navigationTitle("Location")
            .toolbar {
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

    private enum OverlayLayout {
        static let horizontalPad: CGFloat = 12
        static let verticalPad: CGFloat = 8
        static let cornerRadius: CGFloat = 12
        static let summaryLineLimit: Int = 2
        static let hierarchyLineLimit: Int = 2
        static let phraseLineLimit: Int = 3
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LocationMapView(
                coordinate: locationManager.lastKnownLocation,
                locationStatus: locationManager.locationStatus,
                allowsInteraction: locationManager.allowsMapInteraction
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: OverlayLayout.verticalPad) {
                currentInformationPanel
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onRepeat)
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
                .font(.headline)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(OverlayLayout.summaryLineLimit)

            let availableRows = LocationSummaryFormatter.hierarchyRows(for: locationManager.lastKnownAddress).filter(\.isAvailable)
            Text(
                availableRows
                    .map(\.value)
                    .joined(separator: " · ")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(OverlayLayout.hierarchyLineLimit)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Label("Location status", systemImage: "location")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Label(locationManager.locationStatus.riderMessage, systemImage: locationManager.locationStatus.needsSettingsAction ? "location.slash" : "location")
                    .font(.caption)
                    .foregroundStyle(locationManager.locationStatus.needsSettingsAction ? .orange : .secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Last spoken phrase")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(locationManager.lastSpokenPhrase ?? "No spoken phrase yet")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(OverlayLayout.phraseLineLimit)
                if let timestamp = locationManager.lastSpokenAt {
                    Text(isoDateFormatter.string(from: timestamp))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: OverlayLayout.cornerRadius))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to repeat the current location announcement.")
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(locationManager.contentMode.label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if locationManager.contentMode == .quiet {
                    Label("Quiet", systemImage: "speaker.slash.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Always running", systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !locationManager.allowsMapInteraction {
                    Label("Map locked", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct LocationMapView: View {
    let coordinate: CLLocationCoordinate2D?
    let locationStatus: LocationServiceStatus
    let allowsInteraction: Bool
    @Environment(\.openURL) private var openURL
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var snapshot: CoordinateSnapshot? {
        coordinate.map(CoordinateSnapshot.init)
    }

    var body: some View {
        Group {
            if let snapshot {
                Map(
                    position: $cameraPosition,
                    interactionModes: allowsInteraction ? .all : []
                ) {
                    Marker("Current Location", coordinate: snapshot.coordinate)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    updateCamera(snapshot)
                }
                .onChange(of: snapshot) { _, newValue in
                    updateCamera(newValue)
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

    private func updateCamera(_ snapshot: CoordinateSnapshot) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: snapshot.coordinate,
                latitudinalMeters: 40_000,
                longitudinalMeters: 40_000
            )
        )
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
                                locationManager.contentMode = isQuiet ? .quiet : .shortFacts
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
                    TextField("Home country", text: $locationManager.homeCountry, prompt: Text("Optional"))
                    TextField("Home region", text: $locationManager.homeRegion, prompt: Text("Optional"))
                    TextField("Familiar regions", text: $locationManager.familiarRegions, prompt: Text("Optional, comma-separated"))
                        .textInputAutocapitalization(.words)

                    Text("Provide home context so facts can avoid obvious or repeated geography.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Advanced") {
                    Picker("Location check frequency", selection: $locationManager.locationCheckInterval) {
                        ForEach(intervals, id: \.self) { interval in
                            Text("\(interval) seconds").tag(interval)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bluetooth Audio Delay: \(locationManager.bluetoothDelaySeconds, specifier: "%.1f")s")
                        Slider(
                            value: $locationManager.bluetoothDelaySeconds,
                            in: 0...3,
                            step: 0.1
                        )
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
                            LogRow(log: log, showSpokenPhrase: locationManager.testMode)
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
