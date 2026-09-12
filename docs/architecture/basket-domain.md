# Basket & Trip Domain

Pure state and logic for the shopping trip. No UI, no camera, no OCR. All money
is **integer pence**.

## Model

```swift
struct BasketItem: Identifiable {
    var id: UUID
    var name: String
    var quantity: Int            // >= 1
    var lineTotalInPence: Int    // SOURCE OF TRUTH for what this line costs

    // Display-only unit price. Integer-divides, so it may be ~approximate for
    // offers that don't divide evenly (e.g. 3 for £1.00 -> shows ~£0.33 each).
    var unitPriceInPence: Int { lineTotalInPence / max(quantity, 1) }
}
```

`lineTotalInPence` is the authority so the trip total is always penny-accurate,
including multibuy offers like "3 for £1.00". `unitPriceInPence` is derived for
display only.

- A **scanned/single item** at price `p`, qty `q`: `lineTotalInPence = p * q`.
- A **multibuy offer** "N for £X": qty `N`, `lineTotalInPence = X` (the offer
  total entered by the user), stored exactly.

struct Trip {
    var budgetInPence: Int
    var items: [BasketItem]
    var totalInPence: Int       { items.reduce(0) { $0 + $1.lineTotalInPence } }
    var remainingInPence: Int   { budgetInPence - totalInPence }
    var isOverBudget: Bool      { remainingInPence < 0 }
}
```

## Operations

- `setBudget(_:)` — set/adjust the trip budget (can be changed mid-trip).
- `add(name:unitPriceInPence:quantity:)` — append a new item; line total =
  unit price × quantity. This is what a **Scanner capture** drives (qty 1) and
  the simple **manual entry** path.
- `addOffer(name:offerTotalInPence:quantity:)` — append a multibuy line whose
  line total is the exact offer total (e.g. "3 for £1.00"). This is the
  **manual entry** path for offers.
- `setQuantity(_:for:)` — the +/- controls; quantity floors at 1 (0 = delete).
  For offer lines, adjusting quantity scales the line total proportionally.
- `edit(id:name:lineTotalInPence:quantity:)` — correct a row.
- `remove(id:)` — delete a row.
- `startNewTrip(budget:)` — clear the basket; keeps or resets budget.

## Persistence

Exactly one **current trip** is persisted via **SwiftData**, so a locked phone
or backgrounded app mid-shop loses nothing. Every mutation saves. "New trip"
replaces it. No long-term history in v1 (a future area could keep past trips).

## Explicit non-goals

- No knowledge of how an item was captured (scanned vs typed by hand — the
  same item shapes are produced either way).
- No multi-trip history, no sync, no accounts.
