# Architecture Overview

## What this is

A native iOS (SwiftUI) app for a single user: my wife, shopping in Aldi. She
walks the aisles, scans shelf labels, and the app keeps a running basket with
item names, prices, and quantities, plus a running total measured against a
budget she sets for the trip.

## The core problem

Aldi shelf labels have **no scannable product barcode** and there is no public
Aldi product database. But the label prints the **product name** and a **large,
high-contrast price** (e.g. `79p`, `£2.49`). So the app reads the label with
**on-device OCR** (Apple Vision / VisionKit) rather than scanning a barcode.

## Actors

- **Shopper** (the only user): sets a budget, scans items, edits the basket,
  watches the remaining total.
- **iPhone camera + on-device text recognition**: the "scanner".

## The one-tap scan flow

1. Shopper taps **Scan next item**. The camera opens.
2. The app watches the live feed for a shelf label.
3. On a **confident capture** (name + biggest-number price, held steady), the
   camera **auto-closes** and the item is added to the basket with quantity 1.
   A beep/haptic confirms.
4. On a **low-confidence capture** or failure, the app **alerts** the shopper and
   shows an editable **confirm card** pre-filled with its best guess to correct.
5. Rapid re-reads of the same label are ignored so one item isn't double-counted.
6. Any basket row can be edited later (name, price, quantity, delete) when the
   camera is closed.

## Major system areas (deep modules behind small seams)

The app is small; keep seams few. Three areas:

### 1. Scanner (`docs/architecture/scanner.md`)
Owns everything about turning a camera view of a shelf label into a
`Capture(name, priceInPence, confidence)`. Hides Vision/VisionKit, price
parsing ("biggest number", pence vs pounds), and dwell/steadiness gating behind a
small interface. **This is the only area that touches the camera or OCR.**

### 2. Basket & Trip domain (`docs/architecture/basket-domain.md`)
Owns the trip: the basket items, quantities, line totals, running total, the
budget, and remaining. Pure value/state logic with no UI or camera knowledge.
Owns persistence of the current trip so it survives the app closing mid-shop.

### 3. UI (`docs/architecture/ui.md`)
SwiftUI screens: the basket/budget home screen, the scan camera screen, the
confirm/correct card, and row editing. Talks to the Scanner for captures and to
the Basket domain for state. Holds no business logic of its own.

Data flow: **UI → Scanner → Capture → Basket domain → persisted trip → UI**.

## Key constraints & decisions

- **Platform**: native SwiftUI, iOS 17+ (modern SwiftUI, VisionKit
  `DataScannerViewController`, SwiftData for storage).
- **Distribution**: installed via Xcode from a personal machine (no App Store).
- **Offline**: fully on-device; no network, no accounts, no backend.
- **Currency**: money stored as **integer pence**; handles `79p` and `£2.49`
  labels; totals shown in `£`.
- **Persistence**: one current trip persisted (SwiftData); "New trip" clears it.
  No long-term trip history in v1.
- **Price selection**: the largest numeric token on the label is the price;
  the smaller per-unit price (`39.5p per 100g`) is ignored.
