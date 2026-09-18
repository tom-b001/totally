//
//  VisionKitScannerTests.swift
//  TotallyTests
//
//  Unit tests for the testable, non-camera parts of the scanner seam: the
//  async continuation lifecycle and the (stub) text-to-Capture mapping.
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

        scanner.handleRecognizedText(["Oat Milk 1L", "89p"])

        let scanResult = await result
        #expect(scanResult == .captured(Capture(name: "Oat Milk 1L", priceInPence: 0, isConfident: false)))
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
