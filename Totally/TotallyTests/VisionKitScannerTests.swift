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

// Serialized: several tests mutate the shared static `VisionKitScanner.scanTimeout`
// (there's no instance-level equivalent), so running them concurrently risks one
// test's timeout override leaking into another's assertions.
@Suite(.serialized)
@MainActor
struct VisionKitScannerTests {
    @Test
    func recognizedTextResolvesCapturedResult() async {
        let scanner = VisionKitScanner()
        scanner.dwellDuration = .milliseconds(1)

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

    @Test
    func unparseableTextEventuallyResolvesFailedWithoutRequiringCancel() async {
        // A regression test for getting stuck in the camera forever: if no
        // batch of recognized text ever yields a plausible price, the scan
        // must still resolve (as .failed) once the timeout elapses, rather
        // than leaving `isPresenting` true indefinitely.
        let scanner = VisionKitScanner()
        scanner.dwellDuration = .milliseconds(1)
        VisionKitScanner.scanTimeout = .milliseconds(50)
        defer { VisionKitScanner.scanTimeout = .seconds(10) }

        async let result = scanner.scanNextItem()

        while !scanner.isPresenting {
            await Task.yield()
        }

        scanner.handleRecognizedText([
            RecognizedLine(text: "no price here", boundingArea: 100, confidence: 0.9),
        ])

        let scanResult = await result
        guard case .failed = scanResult else {
            Issue.record("expected .failed, got \(scanResult)")
            return
        }
        #expect(scanner.isPresenting == false)
    }

    @Test
    func reScanningSameLabelInSubsequentSessionResolvesPromptly() async {
        // Regression for totally-716.11: cross-session duplicate suppression
        // used to swallow a re-read of the same label in a *subsequent*
        // scanNextItem() call, returning from acceptDwelledCandidate without
        // resuming the continuation — so a deliberate re-open pointed at the
        // same label hung until the 10s timeout. A new user-initiated scan is
        // an explicit "add this" signal, so it must resolve .captured promptly
        // rather than being suppressed.
        let scanner = VisionKitScanner()
        scanner.dwellDuration = .milliseconds(1)
        // A short timeout so this test fails fast (rather than in 10s) if the
        // re-scan ever regresses to hanging instead of resolving.
        VisionKitScanner.scanTimeout = .milliseconds(200)
        defer { VisionKitScanner.scanTimeout = .seconds(10) }

        let lines = [
            RecognizedLine(text: "Oat Milk 1L", boundingArea: 100, confidence: 0.9),
            RecognizedLine(text: "89p", boundingArea: 400, confidence: 0.9),
        ]

        // First scan captures the label.
        async let firstResult = scanner.scanNextItem()
        while !scanner.isPresenting {
            await Task.yield()
        }
        scanner.handleRecognizedText(lines)
        let first = await firstResult
        #expect(first == .captured(Capture(name: "Oat Milk 1L", priceInPence: 89, isConfident: true)))

        // A subsequent scan on the SAME scanner instance, re-reading the SAME
        // label immediately: must resolve .captured promptly, not hang.
        async let secondResult = scanner.scanNextItem()
        while !scanner.isPresenting {
            await Task.yield()
        }
        scanner.handleRecognizedText(lines)
        let second = await secondResult
        #expect(second == .captured(Capture(name: "Oat Milk 1L", priceInPence: 89, isConfident: true)))
        #expect(scanner.isPresenting == false)
    }

    @Test
    func differentLabelRightAfterIsCaptured() async {
        let scanner = VisionKitScanner()
        scanner.dwellDuration = .milliseconds(1)

        async let firstResult = scanner.scanNextItem()
        while !scanner.isPresenting {
            await Task.yield()
        }
        scanner.handleRecognizedText([
            RecognizedLine(text: "Oat Milk 1L", boundingArea: 100, confidence: 0.9),
            RecognizedLine(text: "89p", boundingArea: 400, confidence: 0.9),
        ])
        _ = await firstResult

        async let secondResult = scanner.scanNextItem()
        while !scanner.isPresenting {
            await Task.yield()
        }
        scanner.handleRecognizedText([
            RecognizedLine(text: "Bananas", boundingArea: 100, confidence: 0.9),
            RecognizedLine(text: "59p", boundingArea: 400, confidence: 0.9),
        ])

        let second = await secondResult
        #expect(second == .captured(Capture(name: "Bananas", priceInPence: 59, isConfident: true)))
    }

    @Test
    func transientTextDoesNotResolveBeforeDwellElapses() async {
        // A single instantaneous read (e.g. the camera briefly glancing over
        // incidental text while moving toward the shelf label) must not be
        // accepted immediately: it needs to be held for `dwellDuration`.
        let scanner = VisionKitScanner()
        scanner.dwellDuration = .milliseconds(200)

        async let result = scanner.scanNextItem()
        while !scanner.isPresenting {
            await Task.yield()
        }

        scanner.handleRecognizedText([
            RecognizedLine(text: "Oat Milk 1L", boundingArea: 100, confidence: 0.9),
            RecognizedLine(text: "89p", boundingArea: 400, confidence: 0.9),
        ])

        // Well before the dwell period elapses, the scan must still be
        // waiting rather than having resolved.
        try? await Task.sleep(for: .milliseconds(20))
        #expect(scanner.isPresenting == true, "a single transient read must not resolve before dwellDuration elapses")

        scanner.handleCancel()
        let scanResult = await result
        #expect(scanResult == .cancelled)
    }

    @Test
    func textHeldSteadyPastDwellIsAccepted() async {
        // The same recognised text repeated across recognition callbacks —
        // simulating the camera continuing to see the same label — must
        // resolve once it has been held for at least `dwellDuration`.
        let scanner = VisionKitScanner()
        scanner.dwellDuration = .milliseconds(30)
        let lines = [
            RecognizedLine(text: "Oat Milk 1L", boundingArea: 100, confidence: 0.9),
            RecognizedLine(text: "89p", boundingArea: 400, confidence: 0.9),
        ]

        async let result = scanner.scanNextItem()
        while !scanner.isPresenting {
            await Task.yield()
        }

        scanner.handleRecognizedText(lines)
        // Repeated recognition callbacks for the same label shouldn't reset
        // or otherwise disrupt the in-progress dwell.
        scanner.handleRecognizedText(lines)

        let scanResult = await result
        #expect(scanResult == .captured(Capture(name: "Oat Milk 1L", priceInPence: 89, isConfident: true)))
    }

    @Test
    func changingTextBeforeDwellElapsesResetsTheDwellTimer() async {
        // If the recognised text changes partway through the dwell window
        // (e.g. the camera drifted across two labels), the dwell must
        // restart for the new candidate rather than accepting it early on
        // the strength of the abandoned one's elapsed time.
        let scanner = VisionKitScanner()
        scanner.dwellDuration = .milliseconds(40)

        async let result = scanner.scanNextItem()
        while !scanner.isPresenting {
            await Task.yield()
        }

        scanner.handleRecognizedText([
            RecognizedLine(text: "Oat Milk 1L", boundingArea: 100, confidence: 0.9),
            RecognizedLine(text: "89p", boundingArea: 400, confidence: 0.9),
        ])

        // Most of the way through the first candidate's dwell window, a
        // different label appears.
        try? await Task.sleep(for: .milliseconds(30))
        scanner.handleRecognizedText([
            RecognizedLine(text: "Bananas", boundingArea: 100, confidence: 0.9),
            RecognizedLine(text: "59p", boundingArea: 400, confidence: 0.9),
        ])

        // Shortly after, less than a fresh dwell window for the new
        // candidate, nothing should have resolved yet.
        try? await Task.sleep(for: .milliseconds(20))
        #expect(scanner.isPresenting == true, "the dwell timer must restart for a new candidate")

        let scanResult = await result
        #expect(scanResult == .captured(Capture(name: "Bananas", priceInPence: 59, isConfident: true)))
    }

    @Test
    func partialFrameOmittingPriceDoesNotDiscardInProgressDwell() async {
        // Regression for totally-716.10: real-device evidence (Moser Roth)
        // showed a valid price read starting a dwell, then VisionKit's next
        // callback arriving as a partial frame with ONLY the name block (no
        // price) because didAdd delivers per-frame deltas, not the whole
        // scene. That partial batch must NOT cancel the in-progress dwell —
        // the good 175p read should still be accepted rather than timing out.
        let scanner = VisionKitScanner()
        scanner.dwellDuration = .milliseconds(50)
        VisionKitScanner.scanTimeout = .milliseconds(500)
        defer { VisionKitScanner.scanTimeout = .seconds(10) }

        async let result = scanner.scanNextItem()
        while !scanner.isPresenting {
            await Task.yield()
        }

        // Frame 1: the full label — name block plus the price block (175p).
        scanner.handleRecognizedText([
            RecognizedLine(text: "MOSER ROTH Organic Bars 100g", boundingArea: 100, confidence: 0.9),
            RecognizedLine(text: "175p", boundingArea: 400, confidence: 0.9),
        ])

        // Frame 2, before the dwell elapses: a partial frame that re-reads
        // ONLY the name block (the price block didn't re-fire that frame).
        // This must not discard the dwell already in progress on 175p.
        try? await Task.sleep(for: .milliseconds(10))
        scanner.handleRecognizedText([
            RecognizedLine(text: "MOSER ROTH Organic Bars 100g", boundingArea: 100, confidence: 0.9),
        ])

        let scanResult = await result
        #expect(scanResult == .captured(Capture(name: "MOSER ROTH Organic Bars 100g", priceInPence: 175, isConfident: true)))
        #expect(scanner.isPresenting == false)
    }
}
