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
}
