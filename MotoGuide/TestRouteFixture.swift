import CoreLocation

/// Fixed coordinates for simulator and manual test-mode rides through Gloucestershire.
enum TestRouteFixture {
    struct Waypoint: Equatable {
        let name: String
        let coordinate: CLLocationCoordinate2D

        var latitude: Double { coordinate.latitude }
        var longitude: Double { coordinate.longitude }

        static func == (lhs: Waypoint, rhs: Waypoint) -> Bool {
            lhs.name == rhs.name
                && lhs.latitude == rhs.latitude
                && lhs.longitude == rhs.longitude
        }
    }

    static let routeName = "Gloucestershire test route"

    static let waypoints: [Waypoint] = [
        Waypoint(
            name: "Start near Nailsworth",
            coordinate: CLLocationCoordinate2D(latitude: 51.697100524640355, longitude: -2.5829796037672668)
        ),
        Waypoint(
            name: "East of Nailsworth",
            coordinate: CLLocationCoordinate2D(latitude: 51.67516332778249, longitude: -2.62098520043736)
        ),
        Waypoint(
            name: "Duplicate coordinate check",
            coordinate: CLLocationCoordinate2D(latitude: 51.67516332778248, longitude: -2.62098520043735)
        ),
        Waypoint(
            name: "Near Minchinhampton",
            coordinate: CLLocationCoordinate2D(latitude: 51.64924416101017, longitude: -2.6660494148164005)
        ),
        Waypoint(
            name: "South of Minchinhampton",
            coordinate: CLLocationCoordinate2D(latitude: 51.645541521767775, longitude: -2.6659134575167327)
        ),
        Waypoint(
            name: "Approaching Stroud",
            coordinate: CLLocationCoordinate2D(latitude: 51.6441810900248, longitude: -2.6622519048050606)
        ),
        Waypoint(
            name: "Stroud area",
            coordinate: CLLocationCoordinate2D(latitude: 51.644251133248034, longitude: -2.6658230544736745)
        ),
        Waypoint(
            name: "West of Stroud",
            coordinate: CLLocationCoordinate2D(latitude: 51.6434797750484, longitude: -2.6681738532921466)
        ),
        Waypoint(
            name: "Towards Stonehouse",
            coordinate: CLLocationCoordinate2D(latitude: 51.645606290328224, longitude: -2.690032591865103)
        ),
        Waypoint(
            name: "Stonehouse approach",
            coordinate: CLLocationCoordinate2D(latitude: 51.645954265539636, longitude: -2.71116900134705)
        ),
        Waypoint(
            name: "End near Stonehouse",
            coordinate: CLLocationCoordinate2D(latitude: 51.64533789808418, longitude: -2.747411725394253)
        )
    ]

    static var coordinates: [CLLocationCoordinate2D] {
        waypoints.map(\.coordinate)
    }

    static func waypoint(at index: Int) -> Waypoint {
        waypoints[index % waypoints.count]
    }
}
