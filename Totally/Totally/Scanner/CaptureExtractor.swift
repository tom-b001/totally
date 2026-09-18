//
//  CaptureExtractor.swift
//  Totally
//
//  Pure text -> Capture parsing: no VisionKit/Vision types here, just
//  `RecognizedLine` values (text + bounding box area + OCR confidence) so
//  this can be unit tested without a camera. See docs/architecture/scanner.md.
//

import Foundation

/// One recognised line of text from the live camera feed, plus the signals
/// used to interpret it: how large its bounding box is on screen (a proxy
/// for font size — the price is usually the biggest text on the label) and
/// the OCR engine's confidence in the transcript.
struct RecognizedLine: Equatable {
    var text: String
    /// Area of the bounding quad, in the coordinate space VisionKit reports
    /// bounds in. Only meaningful relative to other lines from the same read.
    var boundingArea: CGFloat
    /// VNRecognizedText's top-candidate confidence, 0...1.
    var confidence: Float
}

enum CaptureExtractor {
    /// A price must land in this range to be considered plausible (1p...£999.99).
    private static let plausiblePriceRange = 1...99_999

    /// Minimum OCR confidence required for a capture to be confident — but
    /// only applied when the recognizer actually reports a confidence.
    ///
    /// VisionKit's live `DataScannerViewController` tracking reports a
    /// per-item confidence of `0` even on clean reads (unlike a static
    /// `VNRecognizeTextRequest`), so a hard `>= threshold` gate would reject
    /// every real scan. We therefore treat a reported confidence of `0` as
    /// "unknown" and fall back to the structural signals (plausible price +
    /// non-empty name); a *positive* confidence below the threshold still
    /// marks the read as not confident. See docs/architecture/scanner.md.
    private static let confidentThreshold: Float = 0.5

    /// Turns one batch of recognised lines into a best-guess `Capture`, or
    /// `nil` if nothing price-like was found at all.
    static func extract(from lines: [RecognizedLine]) -> Capture? {
        // VisionKit's live scanner groups a shelf label into a few multi-line
        // *blocks* (e.g. the whole name block, and a price block that contains
        // both the headline price and the small-print per-unit price). Explode
        // each block into physical lines so price/name logic works per line,
        // while keeping the parent block's bounding area as the font-size proxy.
        let physicalLines: [RecognizedLine] = lines.flatMap { block in
            block.text
                .split(whereSeparator: \.isNewline)
                .map { sub in
                    RecognizedLine(
                        text: sub.trimmingCharacters(in: .whitespaces),
                        boundingArea: block.boundingArea,
                        confidence: block.confidence
                    )
                }
        }

        let candidates = physicalLines.compactMap { line -> (line: RecognizedLine, pence: Int)? in
            // Structural exclusions come first — these are the "has a unit
            // after it" lines a human reads past to find the money: per-unit
            // small print ("39.5p per 100g"), weights ("340g", "6 x 30g"),
            // and the internal product code ("42032"). They must never be
            // treated as the shelf price even if they look numeric.
            guard !isPerUnitPrice(line.text) else { return nil }
            guard !isWeight(line.text) else { return nil }
            guard !isProductCode(line.text) else { return nil }
            guard let pence = parsePrice(from: line.text) else { return nil }
            return (line, pence)
        }

        // Bounding-box area is only a *tiebreaker*: once the structural rules
        // above have narrowed the field to money-shaped, non-excluded lines,
        // the headline price is the one printed largest on the tag.
        guard let priceMatch = candidates.max(by: { $0.line.boundingArea < $1.line.boundingArea }) else {
            return nil
        }

        // Name: prefer the largest-area *block* that isn't the price block,
        // joining its lines so a multi-line name ("DOMINION\nImperials/
        // Mintoes/ Humbugs\n200g") is kept whole rather than truncated to its
        // first line. Price/per-unit/code/weight lines within it are dropped.
        let name = bestName(from: lines, excludingPriceLine: priceMatch.line.text)

        let plausiblePrice = plausiblePriceRange.contains(priceMatch.pence)
        // Confidence only counts against us when it's actually reported
        // (> 0). A reported 0 means "unknown" for live tracking, not "bad".
        let confidence = priceMatch.line.confidence
        let confidenceOK = confidence == 0 || confidence >= confidentThreshold
        let isConfident = plausiblePrice && !name.isEmpty && confidenceOK

        return Capture(
            name: name,
            priceInPence: priceMatch.pence,
            isConfident: isConfident
        )
    }

    /// A per-unit "small print" price like `39.5p per 100g` / `£1.20 per kg`.
    private static func isPerUnitPrice(_ text: String) -> Bool {
        text.range(of: #"(?i)\bper\b"#, options: .regularExpression) != nil
    }

    /// The internal Aldi product code: a bare 4-6 digit number with no price
    /// marker. Not a name and not a price.
    private static func isProductCode(_ text: String) -> Bool {
        text.range(of: #"^\d{4,6}$"#, options: .regularExpression) != nil
    }

    /// A bare pack size / weight line like `200g`, `1L`, `6 x 30g`, `500ml`.
    private static func isWeight(_ text: String) -> Bool {
        text.range(
            of: #"(?i)^\d+(\.\d+)?\s*(g|kg|ml|l|cl|x\b.*)$"#,
            options: .regularExpression
        ) != nil
    }

    /// Builds the product name from the largest-area *block* that isn't the
    /// price block. The block's lines are joined (so a multi-line name stays
    /// whole), with price/per-unit/code/weight/empty lines removed, and a
    /// trailing weight/size line dropped.
    private static func bestName(from blocks: [RecognizedLine], excludingPriceLine priceLine: String) -> String {
        // The name block is the largest-area block that isn't purely the price
        // and carries at least one plain (non-price/code/weight) line.
        let nameBlock = blocks
            .filter { block in
                let lines = physicalLines(of: block.text)
                let hasPlainLine = lines.contains { line in
                    !line.isEmpty
                        && line != priceLine
                        && parsePrice(from: line) == nil
                        && !isProductCode(line)
                        && !isWeight(line)
                }
                return hasPlainLine
            }
            .max(by: { $0.boundingArea < $1.boundingArea })

        guard let nameBlock else { return "" }

        let kept = physicalLines(of: nameBlock.text).filter { line in
            !line.isEmpty
                && line != priceLine
                && !isPerUnitPrice(line)
                && parsePrice(from: line) == nil
                && !isProductCode(line)
                && !isWeight(line)
        }
        return kept.joined(separator: " ")
    }

    /// Splits a recognised text block into trimmed, non-empty physical lines.
    private static func physicalLines(of text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }


    /// Parses a single line of text for a price, returning integer pence.
    /// Handles `£2.49` / `£2.49p`-style pounds and `79p` / `79 p`-style pence.
    /// Returns the first (and normally only) match per line.
    static func parsePrice(from text: String) -> Int? {
        // Normalise comma decimals (`£2,49`, `39,5p`) to dots so European-style
        // OCR reads parse the same as `.`-decimals.
        let normalized = text.replacingOccurrences(
            of: #"(?<=\d),(?=\d)"#, with: ".", options: .regularExpression
        )

        // £x.xx or £x -> pounds, converted to pence.
        if let match = normalized.range(of: #"£\s*(\d+)(?:\.(\d{1,2}))?"#, options: .regularExpression) {
            let matched = String(normalized[match])
            return poundsMatchToPence(matched)
        }

        // xxp / xx p -> already pence. The `(?<![\d.,])` lookbehind stops us
        // matching the fractional part of a decimal (e.g. the `5` in `39.5p`).
        if let match = normalized.range(of: #"(?<![\d.,])(\d{1,4})\s*p\b"#, options: .regularExpression) {
            let matched = String(normalized[match])
            let digits = matched.filter { $0.isNumber }
            return Int(digits)
        }

        // A bare, money-shaped decimal with EXACTLY two decimal places and no
        // currency marker (e.g. "1.09") -> pounds.pence. On many Aldi tags the
        // "£" is a small superscript that OCR reads on a separate line, leaving
        // the headline price as a plain "1.09". Two decimals is what makes it
        // money: a weight like "1.5" (one decimal) or an integer like "340" is
        // NOT a price and must not match here.
        if normalized.range(of: #"^\s*\d+\.\d{2}\s*$"#, options: .regularExpression) != nil {
            return poundsMatchToPence(normalized.trimmingCharacters(in: .whitespaces))
        }

        return nil
    }

    private static func poundsMatchToPence(_ matched: String) -> Int? {
        let stripped = matched.replacingOccurrences(of: "£", with: "").trimmingCharacters(in: .whitespaces)
        let parts = stripped.split(separator: ".", maxSplits: 1)
        guard let poundsPart = parts.first, let pounds = Int(poundsPart) else { return nil }
        var pence = pounds * 100
        if parts.count == 2 {
            var fraction = String(parts[1])
            if fraction.count == 1 { fraction += "0" }
            pence += Int(fraction) ?? 0
        }
        return pence
    }
}
