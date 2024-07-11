import XCTest
import CoreLocation
@testable import MotoGuide

class LocationManagerTests: XCTestCase {
    var locationManager: LocationManager!
    
    override func setUp() {
        super.setUp()
        locationManager = LocationManager()
    }
    
    override func tearDown() {
        locationManager = nil
        super.tearDown()
    }
    
    func testLocationUpdates() {
        // Simulate location updates
        let initialLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let newLocation = CLLocation(latitude: 37.8044, longitude: -122.2711)
        
        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [initialLocation])
        XCTAssertEqual(locationManager.lastKnownLocation?.latitude, initialLocation.coordinate.latitude)
        XCTAssertEqual(locationManager.lastKnownLocation?.longitude, initialLocation.coordinate.longitude)
        
//        locationManager.locationManager(CLLocationManager(), didUpdateLocations: [newLocation])
//        XCTAssertEqual(locationManager.lastKnownLocation?.latitude, newLocation.coordinate.latitude)
//        XCTAssertEqual(locationManager.lastKnownLocation?.longitude, newLocation.coordinate.longitude)
    }
}
