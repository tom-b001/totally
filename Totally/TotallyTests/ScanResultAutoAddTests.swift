//
//  ScanResultAutoAddTests.swift
//  TotallyTests
//
//  Pure unit tests for the confident-capture -> auto-add decision, no
//  UIKit/AudioToolbox/VisionKit involved.
//

import Testing
@testable import Totally

struct ScanResultAutoAddTests {
    @Test
    func confidentCaptureIsAutoAdded() {
        let capture = Capture(name: "Aldi Free Range Eggs", priceInPence: 79, isConfident: true)
        let result = ScanResult.captured(capture)

        #expect(result.captureToAutoAdd == capture)
    }

    @Test
    func lowConfidenceCaptureIsNotAutoAdded() {
        let capture = Capture(name: "Something", priceInPence: 150, isConfident: false)
        let result = ScanResult.captured(capture)

        #expect(result.captureToAutoAdd == nil)
    }

    @Test
    func cancelledResultIsNotAutoAdded() {
        #expect(ScanResult.cancelled.captureToAutoAdd == nil)
    }

    @Test
    func failedResultIsNotAutoAdded() {
        #expect(ScanResult.failed(reason: "no text").captureToAutoAdd == nil)
    }
}
