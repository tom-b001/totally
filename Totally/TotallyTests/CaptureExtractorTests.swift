//
//  CaptureExtractorTests.swift
//  TotallyTests
//
//  Pure unit tests for price/name parsing, no VisionKit/camera involved.
//

import Testing
@testable import Totally

struct CaptureExtractorTests {
    @Test
    func penceLabelParsesCorrectly() {
        // A sample Aldi-style shelf label: large price in pence, smaller
        // product name and per-weight small print.
        let lines = [
            RecognizedLine(text: "Aldi Free Range Eggs", boundingArea: 300, confidence: 0.95),
            RecognizedLine(text: "79p", boundingArea: 900, confidence: 0.92),
            RecognizedLine(text: "13.2p per egg", boundingArea: 60, confidence: 0.8),
        ]

        let capture = CaptureExtractor.extract(from: lines)

        #expect(capture == Capture(name: "Aldi Free Range Eggs", priceInPence: 79, isConfident: true))
    }

    @Test
    func poundsLabelParsesCorrectly() {
        let lines = [
            RecognizedLine(text: "Oat Milk 1L", boundingArea: 250, confidence: 0.9),
            RecognizedLine(text: "£2.49", boundingArea: 800, confidence: 0.9),
        ]

        let capture = CaptureExtractor.extract(from: lines)

        #expect(capture == Capture(name: "Oat Milk 1L", priceInPence: 249, isConfident: true))
    }

    @Test
    func wholePoundPriceParsesWithoutDecimal() {
        let lines = [
            RecognizedLine(text: "Sourdough Loaf", boundingArea: 200, confidence: 0.9),
            RecognizedLine(text: "£3", boundingArea: 700, confidence: 0.9),
        ]

        let capture = CaptureExtractor.extract(from: lines)

        #expect(capture == Capture(name: "Sourdough Loaf", priceInPence: 300, isConfident: true))
    }

    @Test
    func largestBoundingBoxWinsWhenMultipleNumbersPresent() {
        // "39.5p per 100g" (small print) should lose to "£1.20" (the actual,
        // larger-printed shelf price) even though both are numeric.
        let lines = [
            RecognizedLine(text: "Cheddar Cheese 200g", boundingArea: 300, confidence: 0.9),
            RecognizedLine(text: "£1.20", boundingArea: 850, confidence: 0.9),
            RecognizedLine(text: "39.5p per 100g", boundingArea: 50, confidence: 0.7),
        ]

        let capture = CaptureExtractor.extract(from: lines)

        #expect(capture?.priceInPence == 120)
    }

    @Test
    func lowConfidenceReadIsNotConfident() {
        let lines = [
            RecognizedLine(text: "Blurry Item", boundingArea: 300, confidence: 0.3),
            RecognizedLine(text: "99p", boundingArea: 900, confidence: 0.2),
        ]

        let capture = CaptureExtractor.extract(from: lines)

        #expect(capture?.isConfident == false)
    }

    @Test
    func noPriceFoundReturnsNil() {
        let lines = [
            RecognizedLine(text: "Just some shelf text", boundingArea: 300, confidence: 0.9),
        ]

        #expect(CaptureExtractor.extract(from: lines) == nil)
    }

    // MARK: - Real Aldi ESL label shape

    @Test
    func liveScannerZeroConfidenceIsTreatedAsConfident() {
        // VisionKit's live DataScannerViewController reports confidence 0 even
        // on clean reads; a plausible price + name should still be confident.
        let lines = [
            RecognizedLine(text: "Oat Milk 1L", boundingArea: 250, confidence: 0),
            RecognizedLine(text: "89p", boundingArea: 900, confidence: 0),
        ]

        let capture = CaptureExtractor.extract(from: lines)

        #expect(capture == Capture(name: "Oat Milk 1L", priceInPence: 89, isConfident: true))
    }

    @Test
    func realAldiLabelBlocksExtractPriceNameIgnoringPerUnitAndCode() {
        // Exactly how VisionKit grouped a real DOMINION sweets label: the name
        // as one multi-line block, the product code alone, and a price block
        // containing both the headline 79p and the 39.5p-per-100g small print.
        let lines = [
            RecognizedLine(
                text: "DOMINION\nImperials/ Mintoes/ Humbugs\n200g",
                boundingArea: 26644, confidence: 0
            ),
            RecognizedLine(text: "85752", boundingArea: 647, confidence: 0),
            RecognizedLine(text: "79 p\n39.5p per 100g", boundingArea: 12640, confidence: 0),
        ]

        let capture = CaptureExtractor.extract(from: lines)

        #expect(capture?.priceInPence == 79)
        #expect(capture?.name == "DOMINION Imperials/ Mintoes/ Humbugs")
        #expect(capture?.isConfident == true)
    }

    @Test
    func perUnitPriceAloneIsNotTreatedAsThePrice() {
        // If the only price-like text is a per-unit small print, we should not
        // capture it as the shelf price.
        let lines = [
            RecognizedLine(text: "Some Item", boundingArea: 300, confidence: 0),
            RecognizedLine(text: "39.5p per 100g", boundingArea: 200, confidence: 0),
        ]

        #expect(CaptureExtractor.extract(from: lines) == nil)
    }

    @Test
    func decimalPenceFractionIsNotMisparsedAsAPrice() {
        // Regression: "39.5p" must not yield a garbage "5p"; the fractional
        // part of a decimal is not a standalone pence price.
        #expect(CaptureExtractor.parsePrice(from: "39.5p") == nil)
        #expect(CaptureExtractor.parsePrice(from: "39,5p") == nil)
    }

    @Test
    func commaDecimalPoundsPriceParses() {
        // European-style comma decimals should parse like dot decimals.
        #expect(CaptureExtractor.parsePrice(from: "£2,49") == 249)
    }

    @Test
    func productCodeIsNeverPriceOrName() {
        let lines = [
            RecognizedLine(text: "85752", boundingArea: 5000, confidence: 0),
            RecognizedLine(text: "Real Name", boundingArea: 400, confidence: 0),
            RecognizedLine(text: "59p", boundingArea: 900, confidence: 0),
        ]

        let capture = CaptureExtractor.extract(from: lines)

        #expect(capture?.priceInPence == 59)
        #expect(capture?.name == "Real Name")
    }

    // MARK: - Bare decimal price with no currency marker (totally-716.8)

    @Test
    func bareTwoDecimalPriceParsesAsPounds() {
        // The Aldi headline price often reads as a plain "1.09" because the "£"
        // is a small superscript OCR puts on another line. Two decimals = money.
        #expect(CaptureExtractor.parsePrice(from: "1.09") == 109)
        #expect(CaptureExtractor.parsePrice(from: "£ 1.09") == 109)
    }

    @Test
    func nonMoneyShapedNumbersAreNotPrices() {
        // Single-decimal (a weight-ish value), bare integers, and the product
        // code must NOT be read as prices.
        #expect(CaptureExtractor.parsePrice(from: "1.9") == nil)
        #expect(CaptureExtractor.parsePrice(from: "109") == nil)
        #expect(CaptureExtractor.parsePrice(from: "340") == nil)
    }

    @Test
    func realAldiPeanutButterLabelWithBareDecimalPriceExtracts() {
        // GRANDESSA Peanut Butter: £1.09 headline reads as a bare "1.09", with
        // the per-100g small print, weight and product code all present. The
        // structural rules must pick 109 and ignore 340g/100g/42032/32.1p.
        let lines = [
            RecognizedLine(
                text: "GRANDESSA\nPeanut Butter\nSmooth/Crunchy\n340g",
                boundingArea: 26000, confidence: 0
            ),
            RecognizedLine(text: "1.09", boundingArea: 12000, confidence: 0),
            RecognizedLine(text: "32.1p per 100g", boundingArea: 200, confidence: 0),
            RecognizedLine(text: "42032", boundingArea: 600, confidence: 0),
        ]

        let capture = CaptureExtractor.extract(from: lines)

        #expect(capture?.priceInPence == 109)
        #expect(capture?.name == "GRANDESSA Peanut Butter Smooth/Crunchy")
        #expect(capture?.isConfident == true)
    }
}
