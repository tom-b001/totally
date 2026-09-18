//
//  TripStore.swift
//  Totally
//
//  Owns the current `Trip` and persists it to SwiftData on every mutation.
//  Exactly one `PersistedTrip` row is kept: the store loads it on init (or
//  creates one if this is the first launch) and saves the model context
//  after each domain operation. "New trip" replaces the row's contents
//  rather than creating a new one. See docs/architecture/basket-domain.md.
//

import Foundation
import SwiftData

@Observable
final class TripStore {
    private(set) var trip: Trip

    private let modelContext: ModelContext
    private let record: PersistedTrip

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        let descriptor = FetchDescriptor<PersistedTrip>()
        if let existing = try? modelContext.fetch(descriptor).first {
            record = existing
        } else {
            let created = PersistedTrip()
            modelContext.insert(created)
            record = created
        }

        let items = (try? JSONDecoder().decode([BasketItem].self, from: record.itemsData)) ?? []
        trip = Trip(budgetInPence: record.budgetInPence, items: items)
    }

    private func persist() {
        record.budgetInPence = trip.budgetInPence
        record.itemsData = (try? JSONEncoder().encode(trip.items)) ?? Data()
        try? modelContext.save()
    }

    func setBudget(_ budgetInPence: Int) {
        trip.setBudget(budgetInPence)
        persist()
    }

    @discardableResult
    func add(name: String, unitPriceInPence: Int, quantity: Int = 1) -> UUID {
        let id = trip.add(name: name, unitPriceInPence: unitPriceInPence, quantity: quantity)
        persist()
        return id
    }

    @discardableResult
    func addOffer(name: String, offerTotalInPence: Int, quantity: Int) -> UUID {
        let id = trip.addOffer(name: name, offerTotalInPence: offerTotalInPence, quantity: quantity)
        persist()
        return id
    }

    func setQuantity(_ quantity: Int, for id: UUID) {
        trip.setQuantity(quantity, for: id)
        persist()
    }

    func edit(id: UUID, name: String, lineTotalInPence: Int, quantity: Int) {
        trip.edit(id: id, name: name, lineTotalInPence: lineTotalInPence, quantity: quantity)
        persist()
    }

    func remove(id: UUID) {
        trip.remove(id: id)
        persist()
    }

    func startNewTrip(budget: Int? = nil) {
        trip.startNewTrip(budget: budget)
        persist()
    }
}
