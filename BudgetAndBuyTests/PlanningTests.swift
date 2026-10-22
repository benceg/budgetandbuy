import CoreData
import Testing
@testable import BudgetAndBuy

@MainActor
struct PlanningTests {
    let persistence = PersistenceController(inMemory: true)
    var household: Household { persistence.ensureHousehold() }

    /// A cheap store a drive away, a dear one round the corner, and a list
    /// where each is cheaper for something.
    private func shop() throws -> (list: ShoppingList, far: Store, near: Store) {
        let far = household.addStore()
        far.name = "Aldi"
        far.travelMinutes = 20
        far.distanceKm = 10
        let near = household.addStore()
        near.name = "Co-op"
        near.travel = .walk
        near.travelMinutes = 4
        let list = household.addList()
        let milk = try #require(list.addItem(named: "Milk")?.product)
        let bread = try #require(list.addItem(named: "Bread")?.product)
        let saffron = try #require(list.addItem(named: "Saffron")?.product)
        far.recordPrice(145, for: milk)
        near.recordPrice(275, for: milk)
        far.recordPrice(250, for: bread)
        near.recordPrice(120, for: bread)
        near.recordPrice(600, for: saffron)
        return (list, far, near)
    }

    @Test func cheapestSplitsTheShopWhenItSavesEnough() throws {
        let (list, far, near) = try shop()
        let comparison = StoreComparison(items: Array(list.items ?? []), stores: [far, near])
        let plan = try #require(ShoppingPlan(goal: .cheapest, comparison: comparison))
        #expect(plan.stops.map(\.store) == [near, far])
        #expect(plan.totalMinor == 120 + 600 + 145)
        #expect(plan.pricedCount == 3)
        #expect(plan.travelMinutes == 24)
    }

    @Test func oneStopUsesTheStoreThatCoversMost() throws {
        let (list, far, near) = try shop()
        let comparison = StoreComparison(items: Array(list.items ?? []), stores: [far, near])
        let plan = try #require(ShoppingPlan(goal: .fewestStops, comparison: comparison))
        #expect(plan.stops.map(\.store) == [near])
        #expect(plan.totalMinor == 275 + 120 + 600)
    }

    @Test func closestUsesTheNearestStore() throws {
        let (list, far, near) = try shop()
        let comparison = StoreComparison(items: Array(list.items ?? []), stores: [far, near])
        let plan = try #require(ShoppingPlan(goal: .closest, comparison: comparison))
        #expect(plan.stops.map(\.store) == [near])
    }

    @Test func noPlanWithoutPrices() {
        let store = household.addStore()
        let list = household.addList()
        list.addItem(named: "Milk")
        let comparison = StoreComparison(items: Array(list.items ?? []), stores: [store])
        #expect(ShoppingPlan(goal: .cheapest, comparison: comparison) == nil)
    }

    @Test func estimatesUseTheCheapestPriceUnlessShopping() throws {
        let (list, far, near) = try shop()
        let items = Array(list.items ?? [])
        list.addItem(named: "Celeriac")
        let anywhere = ListEstimate(items: Array(list.items ?? []), stores: [far, near])
        #expect(anywhere.totalMinor == 145 + 120 + 600)
        #expect(anywhere.pricedCount == 3)
        #expect(anywhere.itemCount == 4)
        #expect(anywhere.aisles.first?.category == .other)

        let atAldi = ListEstimate(items: items, stores: [far, near], preferring: far)
        // Aldi's own prices where it has them, the cheapest elsewhere otherwise.
        #expect(atAldi.totalMinor == 145 + 250 + 600)
    }

    @Test func estimatesCountQuantities() throws {
        let store = household.addStore()
        let list = household.addList()
        let milk = try #require(list.addItem(named: "Milk"))
        milk.quantity = 3
        store.recordPrice(100, for: try #require(milk.product))
        let estimate = ListEstimate(items: [milk], stores: [store])
        #expect(estimate.totalMinor == 300)
        #expect(estimate.aisles.map(\.category) == [.dairyAndEggs])
    }

    @Test func budgetsReportWhatsLeft() {
        let under = BudgetProgress(spentMinor: 3_214, budgetMinor: 5_000)
        #expect(under.remainingMinor == 1_786)
        #expect(!under.isOver)
        #expect(abs(under.fraction - 0.6428) < 0.001)

        #expect(BudgetProgress(spentMinor: 6_000, budgetMinor: 5_000).isOver)
        #expect(BudgetProgress(spentMinor: 6_000, budgetMinor: 0).fraction == 0)
        #expect(!BudgetProgress(spentMinor: 6_000, budgetMinor: 0).isOver)
    }
}
