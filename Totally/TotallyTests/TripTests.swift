//
//  TripTests.swift
//  TotallyTests
//
//  Unit tests for the Trip/BasketItem domain model. All money is pence.
//

import Foundation
import Testing
@testable import Totally

struct TripTests {

    // MARK: - add

    @Test func addCreatesLineWithUnitPriceTimesQuantity() {
        var trip = Trip(budgetInPence: 10_00)
        let id = trip.add(name: "Milk", unitPriceInPence: 120, quantity: 2)

        #expect(trip.items.count == 1)
        let item = trip.items.first { $0.id == id }
        #expect(item?.name == "Milk")
        #expect(item?.quantity == 2)
        #expect(item?.lineTotalInPence == 240)
        #expect(item?.unitPriceInPence == 120)
    }

    @Test func addDefaultsQuantityToOne() {
        var trip = Trip()
        trip.add(name: "Bread", unitPriceInPence: 99)

        #expect(trip.items.first?.quantity == 1)
        #expect(trip.items.first?.lineTotalInPence == 99)
    }

    @Test func addClampsNonPositiveQuantityToOne() {
        var trip = Trip()
        trip.add(name: "Eggs", unitPriceInPence: 200, quantity: 0)

        #expect(trip.items.first?.quantity == 1)
        #expect(trip.items.first?.lineTotalInPence == 200)
    }

    // MARK: - addOffer

    @Test func addOfferStoresExactOfferTotal() {
        var trip = Trip()
        trip.add(name: "placeholder", unitPriceInPence: 1) // ensure non-empty basket state doesn't matter
        trip.addOffer(name: "Beans", offerTotalInPence: 100, quantity: 3)

        let offerItem = trip.items.last!
        #expect(offerItem.quantity == 3)
        #expect(offerItem.lineTotalInPence == 100)
        #expect(offerItem.unitPriceInPence == 33) // integer-divides, display only
    }

    // MARK: - edit

    @Test func editUpdatesNameTotalAndQuantity() {
        var trip = Trip()
        let id = trip.add(name: "Milk", unitPriceInPence: 100, quantity: 1)

        trip.edit(id: id, name: "Oat Milk", lineTotalInPence: 250, quantity: 2)

        let item = trip.items.first { $0.id == id }
        #expect(item?.name == "Oat Milk")
        #expect(item?.lineTotalInPence == 250)
        #expect(item?.quantity == 2)
    }

    @Test func editClampsQuantityToAtLeastOne() {
        var trip = Trip()
        let id = trip.add(name: "Milk", unitPriceInPence: 100, quantity: 1)

        trip.edit(id: id, name: "Milk", lineTotalInPence: 100, quantity: 0)

        #expect(trip.items.first?.quantity == 1)
    }

    @Test func editIsNoOpForUnknownId() {
        var trip = Trip()
        trip.add(name: "Milk", unitPriceInPence: 100, quantity: 1)

        trip.edit(id: UUID(), name: "Ghost", lineTotalInPence: 999, quantity: 5)

        #expect(trip.items.count == 1)
        #expect(trip.items.first?.name == "Milk")
    }

    // MARK: - setQuantity

    @Test func setQuantityScalesSingleItemLineTotal() {
        var trip = Trip()
        let id = trip.add(name: "Milk", unitPriceInPence: 120, quantity: 1)

        trip.setQuantity(3, for: id)

        let item = trip.items.first { $0.id == id }
        #expect(item?.quantity == 3)
        #expect(item?.lineTotalInPence == 360)
    }

    @Test func setQuantityScalesOfferLineProportionally() {
        var trip = Trip()
        let id = trip.addOffer(name: "Beans", offerTotalInPence: 100, quantity: 3)

        trip.setQuantity(6, for: id)

        let item = trip.items.first { $0.id == id }
        #expect(item?.quantity == 6)
        #expect(item?.lineTotalInPence == 200)
    }

    @Test func setQuantityZeroRemovesItem() {
        var trip = Trip()
        let id = trip.add(name: "Milk", unitPriceInPence: 120, quantity: 2)

        trip.setQuantity(0, for: id)

        #expect(trip.items.isEmpty)
    }

    @Test func setQuantityNegativeRemovesItem() {
        var trip = Trip()
        let id = trip.add(name: "Milk", unitPriceInPence: 120, quantity: 2)

        trip.setQuantity(-1, for: id)

        #expect(trip.items.isEmpty)
    }

    @Test func setQuantityIsNoOpForUnknownId() {
        var trip = Trip()
        trip.add(name: "Milk", unitPriceInPence: 120, quantity: 2)

        trip.setQuantity(5, for: UUID())

        #expect(trip.items.count == 1)
        #expect(trip.items.first?.quantity == 2)
    }

    @Test func setQuantitySameValueIsNoOp() {
        var trip = Trip()
        let id = trip.add(name: "Milk", unitPriceInPence: 120, quantity: 2)

        trip.setQuantity(2, for: id)

        #expect(trip.items.first?.lineTotalInPence == 240)
    }

    // MARK: - remove

    @Test func removeDeletesRow() {
        var trip = Trip()
        let id = trip.add(name: "Milk", unitPriceInPence: 120, quantity: 1)
        trip.add(name: "Bread", unitPriceInPence: 99, quantity: 1)

        trip.remove(id: id)

        #expect(trip.items.count == 1)
        #expect(trip.items.first?.name == "Bread")
    }

    @Test func removeIsNoOpForUnknownId() {
        var trip = Trip()
        trip.add(name: "Milk", unitPriceInPence: 120, quantity: 1)

        trip.remove(id: UUID())

        #expect(trip.items.count == 1)
    }

    // MARK: - setBudget

    @Test func setBudgetUpdatesBudget() {
        var trip = Trip(budgetInPence: 1000)
        trip.setBudget(2500)

        #expect(trip.budgetInPence == 2500)
    }

    // MARK: - startNewTrip

    @Test func startNewTripClearsItemsAndKeepsBudgetByDefault() {
        var trip = Trip(budgetInPence: 1500)
        trip.add(name: "Milk", unitPriceInPence: 120, quantity: 1)

        trip.startNewTrip()

        #expect(trip.items.isEmpty)
        #expect(trip.budgetInPence == 1500)
    }

    @Test func startNewTripCanResetBudget() {
        var trip = Trip(budgetInPence: 1500)
        trip.add(name: "Milk", unitPriceInPence: 120, quantity: 1)

        trip.startNewTrip(budget: 3000)

        #expect(trip.items.isEmpty)
        #expect(trip.budgetInPence == 3000)
    }

    // MARK: - total / remaining / isOverBudget

    @Test func totalSumsAllLineTotals() {
        var trip = Trip()
        trip.add(name: "Milk", unitPriceInPence: 120, quantity: 2)   // 240
        trip.addOffer(name: "Beans", offerTotalInPence: 100, quantity: 3) // 100

        #expect(trip.totalInPence == 340)
    }

    @Test func totalIsZeroForEmptyBasket() {
        let trip = Trip(budgetInPence: 1000)
        #expect(trip.totalInPence == 0)
        #expect(trip.remainingInPence == 1000)
        #expect(trip.isOverBudget == false)
    }

    @Test func remainingIsBudgetMinusTotal() {
        var trip = Trip(budgetInPence: 1000)
        trip.add(name: "Milk", unitPriceInPence: 120, quantity: 2) // 240

        #expect(trip.remainingInPence == 760)
    }

    @Test func isOverBudgetFalseWhenExactlyAtBudget() {
        var trip = Trip(budgetInPence: 240)
        trip.add(name: "Milk", unitPriceInPence: 120, quantity: 2) // 240

        #expect(trip.remainingInPence == 0)
        #expect(trip.isOverBudget == false)
    }

    @Test func isOverBudgetTrueWhenTotalExceedsBudget() {
        var trip = Trip(budgetInPence: 100)
        trip.add(name: "Milk", unitPriceInPence: 120, quantity: 1) // 120

        #expect(trip.remainingInPence == -20)
        #expect(trip.isOverBudget == true)
    }
}
