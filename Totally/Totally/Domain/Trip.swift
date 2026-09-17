//
//  Trip.swift
//  Totally
//
//  Trip domain model and mutating operations. All money is stored as
//  integer pence. See docs/architecture/basket-domain.md for the full
//  model description.
//

import Foundation

struct Trip: Equatable {
    var budgetInPence: Int
    var items: [BasketItem]

    init(budgetInPence: Int = 0, items: [BasketItem] = []) {
        self.budgetInPence = budgetInPence
        self.items = items
    }

    var totalInPence: Int { items.reduce(0) { $0 + $1.lineTotalInPence } }
    var remainingInPence: Int { budgetInPence - totalInPence }
    var isOverBudget: Bool { remainingInPence < 0 }

    /// Set/adjust the trip budget. Can be changed mid-trip.
    mutating func setBudget(_ budgetInPence: Int) {
        self.budgetInPence = budgetInPence
    }

    /// Append a new item; line total = unit price × quantity. Drives a
    /// scanner capture (qty 1) and the simple manual-entry path.
    @discardableResult
    mutating func add(name: String, unitPriceInPence: Int, quantity: Int = 1) -> UUID {
        let clampedQuantity = max(quantity, 1)
        let item = BasketItem(
            name: name,
            quantity: clampedQuantity,
            lineTotalInPence: unitPriceInPence * clampedQuantity
        )
        items.append(item)
        return item.id
    }

    /// Append a multibuy offer line whose line total is the exact offer
    /// total (e.g. "3 for £1.00"). This is the manual-entry path for offers.
    @discardableResult
    mutating func addOffer(name: String, offerTotalInPence: Int, quantity: Int) -> UUID {
        let clampedQuantity = max(quantity, 1)
        let item = BasketItem(
            name: name,
            quantity: clampedQuantity,
            lineTotalInPence: offerTotalInPence
        )
        items.append(item)
        return item.id
    }

    /// The +/- controls. Quantity floors at 1; passing 0 (or less) removes
    /// the item. For existing lines, the line total scales proportionally
    /// so multibuy offer totals stay penny-accurate.
    mutating func setQuantity(_ quantity: Int, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        if quantity < 1 {
            items.remove(at: index)
            return
        }

        let item = items[index]
        guard item.quantity != quantity else { return }

        let scaledTotal = roundedProportion(
            of: item.lineTotalInPence,
            from: item.quantity,
            to: quantity
        )
        items[index].quantity = quantity
        items[index].lineTotalInPence = scaledTotal
    }

    /// Correct a row directly (name, total, and/or quantity).
    mutating func edit(id: UUID, name: String, lineTotalInPence: Int, quantity: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].name = name
        items[index].lineTotalInPence = lineTotalInPence
        items[index].quantity = max(quantity, 1)
    }

    /// Delete a row.
    mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// Clear the basket; keeps the current budget unless a new one is given.
    mutating func startNewTrip(budget: Int? = nil) {
        items = []
        if let budget {
            budgetInPence = budget
        }
    }
}

/// Scales `total` from `fromQuantity` to `toQuantity`, rounding to the
/// nearest pence (round-half-up) so proportional scaling stays exact for
/// evenly-divisible cases and penny-accurate otherwise.
private func roundedProportion(of total: Int, from fromQuantity: Int, to toQuantity: Int) -> Int {
    guard fromQuantity > 0 else { return total }
    let numerator = total * toQuantity
    let denominator = fromQuantity
    let half = denominator / 2
    if numerator >= 0 {
        return (numerator + half) / denominator
    } else {
        return -((-numerator + half) / denominator)
    }
}
