//
//  ScanResultConfirmTests.swift
//  TotallyTests
//
//  Pure unit tests for the low-confidence/failure -> confirm-card decision,
//  the mirror of ScanResultAutoAddTests. No UIKit/VisionKit involved.
//

import Testing
@testable import Totally

struct ScanResultConfirmTests {
    @Test
    func confidentCaptureShowsNoConfirmCard() {
        let capture = Capture(name: "Aldi Free Range Eggs", priceInPence: 79, isConfident: true)
        #expect(ScanResult.captured(capture).captureToConfirm == nil)
    }

    @Test
    func lowConfidenceCapturePrefillsConfirmCard() {
        let capture = Capture(name: "Somehing", priceInPence: 150, isConfident: false)
        #expect(ScanResult.captured(capture).captureToConfirm == capture)
    }

    @Test
    func failedResultPrefillsEmptyConfirmCard() {
        let prefill = ScanResult.failed(reason: "no text").captureToConfirm
        #expect(prefill == Capture(name: "", priceInPence: 0, isConfident: false))
    }

    @Test
    func cancelledResultShowsNoConfirmCard() {
        #expect(ScanResult.cancelled.captureToConfirm == nil)
    }

    @Test
    func autoAddAndConfirmAreMutuallyExclusive() {
        let confident = ScanResult.captured(Capture(name: "A", priceInPence: 99, isConfident: true))
        let unsure = ScanResult.captured(Capture(name: "B", priceInPence: 99, isConfident: false))

        // Confident: auto-adds, no card.
        #expect(confident.captureToAutoAdd != nil)
        #expect(confident.captureToConfirm == nil)

        // Unsure: no auto-add, shows card.
        #expect(unsure.captureToAutoAdd == nil)
        #expect(unsure.captureToConfirm != nil)
    }
}
