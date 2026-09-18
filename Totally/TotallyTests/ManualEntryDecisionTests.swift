//
//  ManualEntryDecisionTests.swift
//  TotallyTests
//
//  Verifies the manual-entry qty-1-vs-qty>1 routing rule from
//  docs/architecture/ui.md: leaving quantity at 1 treats price as a unit
//  price; setting quantity above 1 treats price as the offer's exact total.
//

import Foundation
import Testing
@testable import Totally

struct ManualEntryDecisionTests {

    @Test func quantityOneRoutesToItemWithUnitPrice() {
        let outcome = ManualEntryOutcome.decide(name: "Milk", priceInPence: 120, quantity: 1)
        #expect(outcome == .item(name: "Milk", unitPriceInPence: 120, quantity: 1))
    }

    @Test func quantityAboveOneRoutesToOfferWithExactTotal() {
        let outcome = ManualEntryOutcome.decide(name: "Beans", priceInPence: 100, quantity: 3)
        #expect(outcome == .offer(name: "Beans", offerTotalInPence: 100, quantity: 3))
    }

    @Test func unevenOfferKeepsTripTotalPennyAccurate() {
        var trip = Trip(budgetInPence: 10_00)

        let normalOutcome = ManualEntryOutcome.decide(name: "Bread", priceInPence: 99, quantity: 1)
        let offerOutcome = ManualEntryOutcome.decide(name: "Beans", priceInPence: 100, quantity: 3)

        apply(normalOutcome, to: &trip)
        apply(offerOutcome, to: &trip)

        #expect(trip.items.count == 2)
        let offerItem = trip.items.first { $0.name == "Beans" }
        #expect(offerItem?.lineTotalInPence == 100)
        #expect(offerItem?.quantity == 3)
        // 100 / 3 = 33.33..., integer-divides for display only; the stored
        // line total (source of truth) is still exactly 100.
        #expect(offerItem?.unitPriceInPence == 33)
        #expect(trip.totalInPence == 99 + 100)
    }

    /// Mirrors the routing HomeView performs in its ManualEntryView sheet.
    private func apply(_ outcome: ManualEntryOutcome, to trip: inout Trip) {
        switch outcome {
        case let .item(name, unitPriceInPence, quantity):
            trip.add(name: name, unitPriceInPence: unitPriceInPence, quantity: quantity)
        case let .offer(name, offerTotalInPence, quantity):
            trip.addOffer(name: name, offerTotalInPence: offerTotalInPence, quantity: quantity)
        }
    }
}
