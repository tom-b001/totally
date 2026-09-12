# Glossary

Canonical terms for this project. Definitions only — no implementation detail.

- **Trip**: One shopping session. Has a budget and a basket. Cleared when the
  user starts a new trip. Only one trip is active at a time.
- **Basket**: The collection of basket items in the current trip.
- **Basket item**: A single line in the basket — a name, a unit price, and a
  quantity. Its line total is unit price × quantity.
- **Scan**: The act of pointing the camera at a shelf label to capture an item.
  Begins when the user taps "Scan next item" and ends when an item is captured,
  cancelled, or fails.
- **Shelf label**: An Aldi electronic shelf label. Shows a product name, a large
  price (e.g. `79p` or `£2.49`), a size, an internal item code, and a per-unit
  price. Has **no scannable product barcode**.
- **Capture**: A successful read of a shelf label into a price and a name.
- **Confident capture**: A capture whose OCR confidence is high enough to add to
  the basket automatically without user confirmation.
- **Low-confidence capture**: A capture the app is unsure about; the user is
  shown a pre-filled, editable confirm card before it is added.
- **Price**: The item's shelf price. Taken to be the largest numeric value on
  the label (distinct from the smaller per-unit price).
- **Budget**: A money target the user sets at the start of a trip.
- **Remaining**: Budget minus basket total. May be negative (over budget).
