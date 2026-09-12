# Scanner

The only area that touches the camera or OCR. Turns a live camera view of an
Aldi shelf label into a structured capture, or reports that it couldn't.

## Interface (the seam)

```swift
struct Capture {
    var name: String            // best-guess product name
    var priceInPence: Int       // the biggest-number price, as integer pence
    var isConfident: Bool       // true -> auto-add; false -> show confirm card
}

enum ScanResult {
    case captured(Capture)      // confident or low-confidence (see isConfident)
    case cancelled              // user backed out
    case failed(reason: String) // nothing usable found
}

protocol Scanner {
    // Presents the camera, resolves once a label is read, cancelled, or failed.
    func scanNextItem() async -> ScanResult
}
```

Everything below is hidden behind this. The UI never sees Vision types.

## Responsibilities

- **Live text recognition** via VisionKit `DataScannerViewController` (recognises
  text in the live feed, gives bounding boxes + per-item confidence).
- **Price extraction**: from the recognised text tokens, pick the **largest
  numeric value** as the price. Parse both `79p`/`79` (pence) and `£2.49`/`2.49`
  (pounds) into integer pence. The bounding box area is a strong signal for
  "biggest number = price".
- **Name extraction**: take the prominent non-price text lines (typically the
  large product-name block) as the name.
- **Confidence gating**: combine OCR confidence, whether a plausible price was
  found, and steadiness (label held in frame briefly) into `isConfident`.
  Confident -> resolve and auto-close. Not confident -> still return a
  `Capture` but with `isConfident = false` so the UI shows the confirm card.
- **Duplicate suppression**: remember the last captured label (its text/price)
  for a few seconds; ignore a re-read that matches, so walking past or lingering
  doesn't double-add.

## Explicit non-goals

- No basket, total, budget, or persistence knowledge.
- No product-code lookup — the internal Aldi code (`85752`) is not used.
- No per-unit price / size parsing in v1 (label shows `39.5p per 100g`; ignored).

## Risks

- OCR misreading a price straight into the total is the main risk. Mitigated by
  confidence gating + the confirm card + fully editable basket rows.
- Glare/angle on glossy ESLs. Mitigated by requiring a steady, confident read
  rather than firing on the first frame.
