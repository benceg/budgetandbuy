import CoreData
import Testing
@testable import BudgetAndBuy

@MainActor
struct ShopPlaceTests {
    let persistence = PersistenceController(inMemory: true)
    var household: Household { persistence.ensureHousehold() }

    private func place(_ fullAddress: String, placeID: String? = nil, latitude: Double = 51.32) -> ShopPlace {
        ShopPlace(name: "Tesco", address: String(fullAddress.split(separator: ",").first ?? ""), fullAddress: fullAddress,
                  placeID: placeID, latitude: latitude, longitude: -0.14)
    }

    @Test func addingAShopKeepsItsNameAndPlace() {
        let tesco = place("200 Brighton Road, Coulsdon, CR5 2PL", placeID: "A")
        let store = household.addStore(named: "Tesco Superstore", at: tesco)
        #expect(store.name == "Tesco Superstore")
        #expect(store.address == "200 Brighton Road")
        #expect(store.fullAddress == "200 Brighton Road, Coulsdon, CR5 2PL")
        #expect(store.placeID == "A")
        #expect(store.coordinate.latitude == 51.32)
        #expect(store.colorName != nil)
    }

    @Test func theSameMapsPlaceIsNotAddedTwice() {
        let first = household.addStore(named: "Tesco", at: place("200 Brighton Road, Coulsdon", placeID: "A"))
        first.name = "My Tesco"
        let again = household.addStore(named: "Tesco Superstore", at: place("200 Brighton Rd, Coulsdon", placeID: "A"))
        #expect(again == first)
        #expect(again.name == "My Tesco")
        #expect(household.stores?.count == 1)
    }

    @Test func shopsWithTheSameNameAtDifferentPlacesAreBothAdded() {
        let coulsdon = household.addStore(named: "Tesco", at: place("200 Brighton Road, Coulsdon", placeID: "A"))
        let purley = household.addStore(named: "Tesco", at: place("1 High Street, Purley", placeID: "B", latitude: 51.33))
        #expect(coulsdon != purley)
        #expect(household.stores?.count == 2)
        #expect(coulsdon.sharesName(with: [coulsdon, purley]))
    }

    @Test func differentMapsPlacesAtOneAddressAreDifferentShops() {
        household.addStore(named: "Boots", at: place("Centrale, Croydon", placeID: "A"))
        household.addStore(named: "Tesco", at: place("Centrale, Croydon", placeID: "B"))
        #expect(household.stores?.count == 2)
    }

    @Test func shopsPlacedByHandMatchOnTheirFullAddress() {
        let corner = household.addStore(named: "Corner Shop", at: place("12 Chipstead Valley Road, Coulsdon, CR5 3BA"))
        let again = household.addStore(named: "Corner shop", at: place("12  chipstead valley road, Coulsdon, cr5 3ba"))
        #expect(again == corner)
        #expect(household.stores?.count == 1)

        household.addStore(named: "Corner Shop", at: place("14 Chipstead Valley Road, Coulsdon, CR5 3BA"))
        #expect(household.stores?.count == 2)
    }

    @Test func aShopFromMapsMatchesOneAddedByHandAtItsAddress() {
        let byHand = household.addStore(named: "Aldi", at: place("Lion Green Road, Coulsdon, CR5 2NL"))
        let fromMaps = household.addStore(named: "Aldi", at: place("Lion Green Road, Coulsdon, CR5 2NL", placeID: "A"))
        #expect(fromMaps == byHand)
    }

    @Test func namesOnlyNeedAddressesWhenTheyClash() {
        let aldi = household.addStore(named: "Aldi", at: place("Lion Green Road, Coulsdon", placeID: "A"))
        let tesco = household.addStore(named: "Tesco", at: place("200 Brighton Road, Coulsdon", placeID: "B"))
        #expect(!aldi.sharesName(with: [aldi, tesco]))
        tesco.name = "aldi"
        #expect(aldi.sharesName(with: [aldi, tesco]))
    }

    @Test func newShopsTakeAnUnusedColour() {
        let first = household.addStore(named: "Aldi", at: place("Lion Green Road, Coulsdon", placeID: "A"))
        let second = household.addStore(named: "Tesco", at: place("200 Brighton Road, Coulsdon", placeID: "B"))
        #expect(first.colorName != second.colorName)
    }
}
