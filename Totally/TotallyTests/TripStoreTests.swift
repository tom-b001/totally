//
//  TripStoreTests.swift
//  TotallyTests
//
//  Verifies the current trip round-trips through SwiftData: mutations save
//  immediately, and a fresh `TripStore` backed by the same persistent store
//  (simulating an app relaunch) restores the same budget and basket.
//

import Foundation
import SwiftData
import Testing
@testable import Totally

@MainActor
struct TripStoreTests {

    /// Creates a SwiftData container backed by a fresh on-disk store at
    /// `url` so separate `ModelContainer` instances pointed at the same
    /// file behave like separate app launches sharing persisted state.
    private func makeContainer(at url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(url: url)
        return try ModelContainer(for: PersistedTrip.self, configurations: configuration)
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store.sqlite")
    }

    @Test func freshStoreStartsWithEmptyTrip() throws {
        let container = try makeContainer(at: temporaryStoreURL())
        let store = TripStore(modelContext: container.mainContext)

        #expect(store.trip.budgetInPence == 0)
        #expect(store.trip.items.isEmpty)
    }

    @Test func relaunchRestoresBudgetAndBasket() throws {
        let url = temporaryStoreURL()

        let firstLaunch = try makeContainer(at: url)
        let firstStore = TripStore(modelContext: firstLaunch.mainContext)
        firstStore.setBudget(50_00)
        firstStore.add(name: "Milk", unitPriceInPence: 120, quantity: 2)
        firstStore.addOffer(name: "Beans", offerTotalInPence: 100, quantity: 3)

        let secondLaunch = try makeContainer(at: url)
        let secondStore = TripStore(modelContext: secondLaunch.mainContext)

        #expect(secondStore.trip.budgetInPence == 50_00)
        #expect(secondStore.trip.items.count == 2)
        #expect(secondStore.trip.items.map(\.name) == ["Milk", "Beans"])
        #expect(secondStore.trip.totalInPence == 340)
    }

    @Test func everyMutationPersistsImmediately() throws {
        let url = temporaryStoreURL()

        let firstLaunch = try makeContainer(at: url)
        let firstStore = TripStore(modelContext: firstLaunch.mainContext)
        let id = firstStore.add(name: "Bread", unitPriceInPence: 99, quantity: 1)
        firstStore.setQuantity(3, for: id)

        let secondLaunch = try makeContainer(at: url)
        let secondStore = TripStore(modelContext: secondLaunch.mainContext)

        #expect(secondStore.trip.items.first?.quantity == 3)
        #expect(secondStore.trip.items.first?.lineTotalInPence == 99 * 3)
    }

    @Test func newTripReplacesPersistedBasketButCanKeepBudget() throws {
        let url = temporaryStoreURL()

        let firstLaunch = try makeContainer(at: url)
        let firstStore = TripStore(modelContext: firstLaunch.mainContext)
        firstStore.setBudget(20_00)
        firstStore.add(name: "Eggs", unitPriceInPence: 250, quantity: 1)
        firstStore.startNewTrip()

        let secondLaunch = try makeContainer(at: url)
        let secondStore = TripStore(modelContext: secondLaunch.mainContext)

        #expect(secondStore.trip.items.isEmpty)
        #expect(secondStore.trip.budgetInPence == 20_00)
    }
}
