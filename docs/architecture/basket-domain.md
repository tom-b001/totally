# Basket & Trip Domain

Pure state and logic for the shopping trip. No UI, no camera, no OCR. All money
is **integer pence**.

## Model

```swift
struct BasketItem: Identifiable {
    var id: UUID
    var name: String
    var unitPriceInPence: Int
    var quantity: Int           // >= 1
    var lineTotalInPence: Int { unitPriceInPence * quantity }
}

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
- `add(name:priceInPence:)` — append a new item at quantity 1. This is what a
  Scanner capture drives.
- `setQuantity(_:for:)` — the +/- controls; quantity floors at 1 (0 = delete).
- `edit(id:name:priceInPence:)` — correct a row.
- `remove(id:)` — delete a row.
- `startNewTrip(budget:)` — clear the basket; keeps or resets budget.

## Persistence

Exactly one **current trip** is persisted via **SwiftData**, so a locked phone
or backgrounded app mid-shop loses nothing. Every mutation saves. "New trip"
replaces it. No long-term history in v1 (a future area could keep past trips).

## Explicit non-goals

- No knowledge of how an item was captured (scanned vs typed by hand — same
  `add`).
- No multi-trip history, no sync, no accounts.
