# Aldi Budget Scanner

A native iOS app for keeping a shopping trip under budget. Point the phone at an
Aldi shelf label, and the app reads the price and product name straight off the
label with on-device text recognition (OCR) — no barcodes — and adds it to an
itemised basket with a running total measured against a budget you set for the
trip.

Built for a single user, fully offline, no accounts, no backend.

## How it works

1. Set a **budget** for the trip.
2. Tap **Scan next item** — the camera opens.
3. Point at a shelf label. On a confident read the app auto-adds the item
   (name + price, quantity 1) and closes the camera, with a beep/haptic.
4. If the read is uncertain it shows an editable **confirm card** to correct
   before adding.
5. The **basket** shows every item with name, unit price, and quantity (with
   +/− steppers). Edit or delete any row at any time.
6. The header always shows the running **total** and how much budget is
   **remaining** — turning red when you go over.

The current trip is saved, so locking or closing the phone mid-shop loses
nothing. "New trip" clears the basket to start again.

## Why OCR instead of barcodes

Aldi electronic shelf labels have no scannable product barcode and there is no
public Aldi product database — but they do print a large, high-contrast price
and the product name. So the app reads the label as text. See
[ADR-0001](docs/adr/0001-ocr-not-barcode.md).

## Tech

- **SwiftUI**, iOS 17+
- **VisionKit** (`DataScannerViewController`) for live text recognition
- **SwiftData** for persisting the current trip
- Money stored as integer pence; handles both `79p` and `£2.49` labels

## Documentation

### Architecture
- [Overview](docs/architecture/overview.md) — the system, actors, scan flow,
  and how the areas fit together
- [Scanner](docs/architecture/scanner.md) — camera + OCR, price/name extraction,
  duplicate suppression
- [Basket & Trip domain](docs/architecture/basket-domain.md) — basket, budget,
  totals, persistence
- [UI](docs/architecture/ui.md) — the SwiftUI screens

### Decisions
- [ADR-0001 — Read shelf labels with OCR, not barcode scanning](docs/adr/0001-ocr-not-barcode.md)

### Reference
- [CONTEXT.md](CONTEXT.md) — glossary of canonical terms

## Project tracking

Work is tracked with [beads](https://github.com/gastownhall/beads) (`bd`). Run
`bd ready` to see available work; the plan is staged as three milestones
(runnable basket → OCR scanning → robustness).
