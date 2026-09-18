//
//  PersistedTrip.swift
//  Totally
//
//  SwiftData record for the single current trip. Exactly one row exists at
//  a time: the basket items are stored as a JSON-encoded blob rather than a
//  relationship graph, since `BasketItem` is a small value type and the
//  whole trip is always read/written as a unit. See
//  docs/architecture/basket-domain.md.
//

import Foundation
import SwiftData

@Model
final class PersistedTrip {
    var budgetInPence: Int
    var itemsData: Data

    init(budgetInPence: Int = 0, itemsData: Data = Data()) {
        self.budgetInPence = budgetInPence
        self.itemsData = itemsData
    }
}
