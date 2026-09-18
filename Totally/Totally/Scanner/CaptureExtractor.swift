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

    /// Minimum OCR confidence (of the line the price was read from) required
    /// for a capture to be confident.
    private static let confidentThreshold: Float = 0.5

    /// Turns one batch of recognised lines into a best-guess `Capture`, or
    /// `nil` if nothing price-like was found at all.
    static func extract(from lines: [RecognizedLine]) -> Capture? {
        let candidates = lines.compactMap { line -> (line: RecognizedLine, pence: Int)? in
            guard let pence = parsePrice(from: line.text) else { return nil }
            return (line, pence)
        }

        // The bounding box area is the signal for "biggest number = price":
        // shelf labels print the price in the largest font on the tag.
        guard let priceMatch = candidates.max(by: { $0.line.boundingArea < $1.line.boundingArea }) else {
            return nil
        }

        let nameCandidates = lines.filter { $0.text != priceMatch.line.text }
        let name = nameCandidates.max(by: { $0.boundingArea < $1.boundingArea })?.text
            ?? lines.first(where: { $0.text != priceMatch.line.text })?.text
            ?? ""

        let plausiblePrice = plausiblePriceRange.contains(priceMatch.pence)
        let isConfident = plausiblePrice
            && !name.isEmpty
            && priceMatch.line.confidence >= confidentThreshold

        return Capture(
            name: name,
            priceInPence: priceMatch.pence,
            isConfident: isConfident
        )
    }

    /// Parses a single line of text for a price, returning integer pence.
    /// Handles `£2.49` / `£2.49p`-style pounds and `79p` / `79 p`-style pence.
    /// Returns the first (and normally only) match per line.
    static func parsePrice(from text: String) -> Int? {
        // £x.xx or £x -> pounds, converted to pence.
        if let match = text.range(of: #"£\s*(\d+)(?:\.(\d{1,2}))?"#, options: .regularExpression) {
            let matched = String(text[match])
            return poundsMatchToPence(matched)
        }

        // xxp / xx p -> already pence.
        if let match = text.range(of: #"(?<![\d.])(\d{1,4})\s*p\b"#, options: .regularExpression, range: nil) {
            let matched = String(text[match])
            let digits = matched.filter { $0.isNumber }
            return Int(digits)
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
