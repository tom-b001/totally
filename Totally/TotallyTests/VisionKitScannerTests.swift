//
//  VisionKitScannerTests.swift
//  TotallyTests
//
//  Unit tests for the testable, non-camera parts of the scanner seam: the
//  async continuation lifecycle and its delegation to `CaptureExtractor`.
//  See CaptureExtractorTests for the price/name parsing logic itself.
//  Live camera behaviour can't be exercised outside a real device, so that
//  part is left to manual verification.
//

import Testing
@testable import Totally

@MainActor
struct VisionKitScannerTests {
    @Test
    func recognizedTextResolvesCapturedResult() async {
        let scanner = VisionKitScanner()

        async let result = scanner.scanNextItem()

        // Give scanNextItem a chance to suspend and set isPresenting before
        // we resolve it.
        while !scanner.isPresenting {
            await Task.yield()
        }

        scanner.handleRecognizedText([
            RecognizedLine(text: "Oat Milk 1L", boundingArea: 100, confidence: 0.9),
            RecognizedLine(text: "89p", boundingArea: 400, confidence: 0.9),
        ])

        let scanResult = await result
        #expect(scanResult == .captured(Capture(name: "Oat Milk 1L", priceInPence: 89, isConfident: true)))
        #expect(scanner.isPresenting == false)
    }

    @Test
    func cancelResolvesCancelledResult() async {
        let scanner = VisionKitScanner()

        async let result = scanner.scanNextItem()

        while !scanner.isPresenting {
            await Task.yield()
        }

        scanner.handleCancel()

        let scanResult = await result
        #expect(scanResult == .cancelled)
        #expect(scanner.isPresenting == false)
    }
}
