//
//  BasketItem.swift
//  Totally
//
//  Basket line item. All money is stored as integer pence. See
//  docs/architecture/basket-domain.md for the full model description.
//

import Foundation

struct BasketItem: Identifiable, Equatable, Codable {
    var id: UUID
    var name: String
    var quantity: Int            // >= 1
    var lineTotalInPence: Int    // SOURCE OF TRUTH for what this line costs

    init(id: UUID = UUID(), name: String, quantity: Int, lineTotalInPence: Int) {
        self.id = id
        self.name = name
        self.quantity = max(quantity, 1)
        self.lineTotalInPence = lineTotalInPence
    }

    // Display-only unit price. Integer-divides, so it may be ~approximate for
    // offers that don't divide evenly (e.g. 3 for £1.00 -> shows ~£0.33 each).
    var unitPriceInPence: Int { lineTotalInPence / max(quantity, 1) }
}
