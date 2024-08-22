import SwiftUI
import CoreLocation
import AVFoundation

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var logs: [(timestamp: Date, location: CLLocationCoordinate2D, address: Address)] = []
    private let speechSynthesizer = AVSpeechSynthesizer()

    let intervals = [1, 2, 5, 10, 15, 30, 60, 120, 300] // Options for location check intervals

    var body: some View {
        VStack {
            Toggle("Test Mode", isOn: $locationManager.testMode)
                .padding()
            
            Toggle("Speak After Every Geocode", isOn: $locationManager.speakAfterEveryGeocode)
                .padding()
            
            Picker("Location Check Interval (seconds)", selection: $locationManager.locationCheckInterval) {
                ForEach(intervals, id: \.self) { interval in
                    Text("\(interval) seconds").tag(interval)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()

            Toggle("Repeat Street", isOn: $locationManager.repeatStreet)
                .padding()
            
            Toggle("Repeat Town", isOn: $locationManager.repeatTown)
                .padding()
            
            Toggle("Repeat County", isOn: $locationManager.repeatCounty)
                .padding()

            Toggle("Repeat Country", isOn: $locationManager.repeatAdministrativeArea)
                .padding()

            List(logs, id: \.timestamp) { log in
                VStack(alignment: .leading) {
                    Text("Timestamp: \(log.timestamp, formatter: dateFormatter)")
                    Text("Location: \(log.location.latitude), \(log.location.longitude)")
                    Text("Street: \(log.address.street)")
                    Text("Town: \(log.address.town)")
                    Text("County: \(log.address.county)")
                    Text("Country: \(log.address.administrativeArea)")
                }
            }

            Button(action: {
                if locationManager.testMode {
                    locationManager.logTestLocation()
                } else {
                    locationManager.requestLocation()
                }
                
                if let location = locationManager.lastKnownLocation, let address = locationManager.lastKnownAddress {
                    logs.append((timestamp: Date(), location: location, address: address))
                    print("Log added: \(Date()) - \(location.latitude), \(location.longitude) - \(address.toJSON() ?? "N/A")")
                } else {
                    print("Location or address not available")
                }
            }) {
                Text("Log")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
        .onAppear {
            locationManager.requestLocation()
            locationManager.onAddressChange = { address in
                if let location = locationManager.lastKnownLocation {
                    logs.append((timestamp: Date(), location: location, address: address))
                    print("Auto log added: \(Date()) - \(location.latitude), \(location.longitude) - \(address.toJSON() ?? "N/A")")
                }
            }
        }
    }
    
    private func speak(address: Address) {
        guard AVSpeechSynthesisVoice.speechVoices().count > 0 else {
            print("No available voices.")
            return
        }
        let utterance = AVSpeechUtterance(string: address.toString(includeStreet: locationManager.repeatStreet, includeTown: locationManager.repeatTown, includeCounty: locationManager.repeatCounty, includeAdministrativeArea: locationManager.repeatAdministrativeArea))
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        print("Speaking address from button: \(address.toString(includeStreet: locationManager.repeatStreet, includeTown: locationManager.repeatTown, includeCounty: locationManager.repeatCounty, includeAdministrativeArea: locationManager.repeatAdministrativeArea))")
        speechSynthesizer.speak(utterance)
        print("Utterance spoken from button: \(utterance.speechString)")
    }
}

// Date formatter for displaying the timestamp
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

