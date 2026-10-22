import CoreData
import CoreLocation
import Testing
@testable import BudgetAndBuy

@MainActor
struct RouteTests {
    let persistence = PersistenceController(inMemory: true)
    var household: Household { persistence.ensureHousehold() }

    /// Shops along a line running north, a kilometre or so apart.
    private func store(_ name: String, latitude: Double) -> Store {
        let store = household.addStore()
        store.name = name
        store.latitude = latitude
        store.longitude = -0.1
        return store
    }

    @Test func startsNearestYouThenGoesToTheNearestNext() {
        let south = store("South", latitude: 51.50)
        let middle = store("Middle", latitude: 51.51)
        let north = store("North", latitude: 51.52)
        let nearNorth = CLLocation(latitude: 51.525, longitude: -0.1)
        #expect(Route.order([south, middle, north], from: nearNorth) == [north, middle, south])
        let nearMiddle = CLLocation(latitude: 51.511, longitude: -0.1)
        middle.latitude = 51.512
        // North is nearer the middle shop than south is.
        #expect(Route.order([south, north, middle], from: nearMiddle) == [middle, north, south])
    }

    @Test func withoutYourLocationStartsFromTheFirstShop() {
        let south = store("South", latitude: 51.50)
        let middle = store("Middle", latitude: 51.51)
        let north = store("North", latitude: 51.52)
        #expect(Route.order([north, south, middle], from: nil) == [north, middle, south])
    }

    @Test func nearestNeedsYourLocation() {
        let south = store("South", latitude: 51.50)
        let north = store("North", latitude: 51.52)
        #expect(Route.nearest([south, north], to: CLLocation(latitude: 51.519, longitude: -0.1)) == north)
        #expect(Route.nearest([south, north], to: nil) == nil)
    }

    @Test func estimatesJourneysFromTheStraightLine() {
        // 3 km as the crow flies is about 3.9 km by road.
        let journey = Journey(estimatingStraightLine: 3_000)
        #expect(journey.driveMinutes == 8)
        #expect(journey.walkMinutes == 49)
        #expect(Journey(estimatingStraightLine: 0).driveMinutes == 1)
    }

    @Test func journeysAddUp() {
        let total = Journey(driveMinutes: 8, walkMinutes: 31) + Journey(driveMinutes: 5, walkMinutes: 19)
        #expect(total == Journey(driveMinutes: 13, walkMinutes: 50))
    }
}
