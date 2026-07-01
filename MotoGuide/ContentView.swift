import SwiftUI
import CoreLocation

private struct RideLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let location: CLLocationCoordinate2D
    let address: Address
    let utteredPhrase: String?
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var firstRunState = FirstRunState()
    @State private var logs: [RideLogEntry] = []
    @State private var showOnboarding = false
    @State private var showResetConfirmation = false
    @State private var showResetCompleteMessage = false

    var body: some View {
        TabView {
            SettingsView(
                locationManager: locationManager,
                showResetConfirmation: $showResetConfirmation
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }

            LogHistoryView(locationManager: locationManager, logs: $logs)
                .tabItem {
                    Label("Log", systemImage: "list.bullet")
                }
        }
        .onAppear {
            showOnboarding = firstRunState.needsOnboarding
            if !firstRunState.needsOnboarding {
                startRideIfNeeded()
            }
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

private struct SettingsView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showResetConfirmation: Bool

    let intervals = [1, 2, 5, 10, 15, 30, 60, 120, 300]

    var body: some View {
        NavigationStack {
            Form {
                Section("Ride") {
                    Toggle("Test Mode", isOn: $locationManager.testMode)

                    Picker("Announcement Style", selection: $locationManager.contentMode) {
                        ForEach(ContentMode.allCases) { mode in
                            Text(mode.label).tag(mode)
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
                }

                Section("Location") {
                    Toggle("Speak After Every Geocode (Debug)", isOn: $locationManager.speakAfterEveryGeocode)

                    Picker("Check Interval", selection: $locationManager.locationCheckInterval) {
                        ForEach(intervals, id: \.self) { interval in
                            Text("\(interval) seconds").tag(interval)
                        }
                    }
                }

                Section("Announce") {
                    Toggle("Street", isOn: $locationManager.announceStreet)
                    Toggle("Town", isOn: $locationManager.announceTown)
                    Toggle("County", isOn: $locationManager.announceCounty)
                    Toggle("Nation", isOn: $locationManager.announceNation)
                    Toggle("Country", isOn: $locationManager.announceCountry)
                }

                Section {
                    DisclosureGroup("Advanced") {
                        DisclosureGroup("Developer") {
                            Text("Testing tools only. Not for normal rides.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button("Reset First-Time Experience", role: .destructive) {
                                showResetConfirmation = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct LogHistoryView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var logs: [RideLogEntry]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Ride history appears here as boundaries change. Turn on Test Mode in Settings, then use Log to step through the Gloucestershire test route without riding.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                List(logs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.timestamp, formatter: dateFormatter)
                            .font(.headline)
                        Text("\(log.location.latitude, specifier: "%.5f"), \(log.location.longitude, specifier: "%.5f")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if Address.isValidPlaceName(log.address.street) {
                            Text(log.address.street)
                        }

                        Text("\(log.address.town), \(log.address.county)")

                        Text("\(log.address.administrativeArea), \(log.address.country)")
                            .foregroundStyle(.secondary)

                        if locationManager.testMode, let phrase = log.utteredPhrase {
                            Text("Spoke: \"\(phrase)\"")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button(action: logCurrentLocation) {
                    Text("Log")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Log")
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

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
