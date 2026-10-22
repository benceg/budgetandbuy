import CoreLocation
import Foundation

/// How long it takes to get from one place to another, by car and on foot.
/// Worked out when it's needed, from wherever you are: never saved.
struct Journey: Equatable {
    var driveMinutes: Int
    var walkMinutes: Int

    static func + (lhs: Journey, rhs: Journey) -> Journey {
        Journey(driveMinutes: lhs.driveMinutes + rhs.driveMinutes, walkMinutes: lhs.walkMinutes + rhs.walkMinutes)
    }

    /// A rough journey when Maps can't work one out: roads are about a third
    /// longer than a straight line, at typical speeds in town.
    init(estimatingStraightLine metres: CLLocationDistance) {
        let kilometres = metres / 1_000 * 1.3
        driveMinutes = max(1, Int((kilometres / 30 * 60).rounded()))
        walkMinutes = max(1, Int((kilometres / 4.8 * 60).rounded()))
    }

    init(driveMinutes: Int, walkMinutes: Int) {
        self.driveMinutes = driveMinutes
        self.walkMinutes = walkMinutes
    }

    /// "6 min", or "1 hr 10 min" for long journeys.
    static func format(minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

enum Route {
    /// The order to visit stores in: the one nearest `origin` first, then
    /// whichever is nearest the one before, as the crow flies. Without an
    /// origin, it starts from the first store.
    static func order(_ stores: [Store], from origin: CLLocation?) -> [Store] {
        var remaining = stores
        var route: [Store] = []
        var here = origin
        while !remaining.isEmpty {
            let index = here.map { here in
                remaining.indices.min { here.distance(from: remaining[$0].location) < here.distance(from: remaining[$1].location) }!
            } ?? 0
            let next = remaining.remove(at: index)
            route.append(next)
            here = next.location
        }
        return route
    }

    /// The store nearest `origin`, as the crow flies, or nil without one.
    static func nearest(_ stores: [Store], to origin: CLLocation?) -> Store? {
        guard let origin else { return nil }
        return stores.min { lhs, rhs in
            (origin.distance(from: lhs.location), lhs.name ?? "") < (origin.distance(from: rhs.location), rhs.name ?? "")
        }
    }
}
