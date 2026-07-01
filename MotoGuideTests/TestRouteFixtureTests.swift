import XCTest
import CoreLocation
@testable import MotoGuide

final class TestRouteFixtureTests: XCTestCase {
    func testRouteHasNamedWaypoints() {
        XCTAssertEqual(TestRouteFixture.routeName, "Gloucestershire test route")
        XCTAssertEqual(TestRouteFixture.waypoints.count, 11)
        XCTAssertFalse(TestRouteFixture.waypoints.contains(where: { $0.name.isEmpty }))
    }

    func testCoordinatesMatchWaypoints() {
        XCTAssertEqual(TestRouteFixture.coordinates.count, TestRouteFixture.waypoints.count)

        for (index, waypoint) in TestRouteFixture.waypoints.enumerated() {
            let coordinate = TestRouteFixture.coordinates[index]
            XCTAssertEqual(coordinate.latitude, waypoint.latitude)
            XCTAssertEqual(coordinate.longitude, waypoint.longitude)
        }
    }

    func testWaypointIndexWraps() {
        let first = TestRouteFixture.waypoint(at: 0)
        let wrapped = TestRouteFixture.waypoint(at: TestRouteFixture.waypoints.count)

        XCTAssertEqual(first, wrapped)
    }

    func testRouteStaysWithinGloucestershireLatLongRange() {
        for waypoint in TestRouteFixture.waypoints {
            XCTAssertGreaterThan(waypoint.latitude, 51.64)
            XCTAssertLessThan(waypoint.latitude, 51.70)
            XCTAssertGreaterThan(waypoint.longitude, -2.75)
            XCTAssertLessThan(waypoint.longitude, -2.58)
        }
    }
}
