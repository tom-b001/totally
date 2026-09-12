# 0001 — Read shelf labels with OCR, not barcode scanning

## Status
Accepted

## Context
The app's job is to capture prices off Aldi shelf labels. The instinctive design
for a "scanner" app is to scan a product barcode. But Aldi electronic shelf
labels (see the sample label) carry only an **internal item code** (e.g. 85752)
with **no scannable product barcode**, and there is no public Aldi product
database to resolve a code to a name/price anyway. The label does, however,
print the **product name** and a **large, high-contrast price** as text.

## Decision
Capture items via **on-device optical character recognition** of the shelf
label (Apple Vision / VisionKit live text), extracting the product name and the
price (the largest numeric value on the label). No barcode scanning; the item
code is ignored.

## Consequences
- The Scanner area is built around text recognition + numeric parsing (pence vs
  pounds, "biggest number = price"), not a barcode framework.
- OCR can misread; we mitigate with confidence gating, a confirm card for
  low-confidence reads, and fully editable basket rows.
- Fully offline, no network or product-lookup dependency.
- Reversing this (e.g. if labels gained barcodes or a data source appeared)
  would mean replacing the Scanner internals — but the `Scanner` seam
  (`scanNextItem() -> ScanResult`) would stay stable.
