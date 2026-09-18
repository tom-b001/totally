//
//  VisionKitScanner.swift
//  Totally
//
//  Concrete `Scanner` backed by `ScannerCameraView`. Owns the async seam:
//  `scanNextItem()` suspends until the camera reports recognised text,
//  cancellation, or failure, and drives whether the camera sheet is shown.
//
//  Turning recognised text lines into a `Capture` is delegated to
//  `CaptureExtractor`, which is pure/testable and knows nothing about
//  VisionKit.
//

import Foundation
import Observation
import os.log

private let logger = Logger(subsystem: "com.totally.app", category: "Scanner")

@MainActor
@Observable
final class VisionKitScanner: Scanner {
    /// How long to wait for a confident/plausible capture before giving up
    /// and resolving `.failed`, so an unparseable label never strands the
    /// user in the camera indefinitely (they can also always tap Cancel).
    static var scanTimeout: Duration = .seconds(10)

    /// How long a captured label is remembered so a matching re-read is
    /// ignored, so lingering on/walking past a label doesn't double-add it.
    /// Instance (not static) so concurrently-running tests can't race on a
    /// shared value. See docs/architecture/scanner.md.
    var duplicateSuppressionWindow: Duration = .seconds(3)

    var isPresenting = false

    private var continuation: CheckedContinuation<ScanResult, Never>?
    private var timeoutTask: Task<Void, Never>?
    private let clock = ContinuousClock()
    private var lastCapture: Capture?
    private var lastCaptureAt: ContinuousClock.Instant?

    func scanNextItem() async -> ScanResult {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.isPresenting = true
            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: Self.scanTimeout)
                guard !Task.isCancelled else { return }
                logger.debug("scan timed out after \(String(describing: Self.scanTimeout), privacy: .public) with no plausible capture")
                self?.resolve(.failed(reason: "No confident read within \(Self.scanTimeout)"))
            }
        }
    }

    /// Called by the camera view once it has recognised some text.
    func handleRecognizedText(_ lines: [RecognizedLine]) {
        // Temporary diagnostic logging: real on-device labels don't always
        // match CaptureExtractor's parsing assumptions (e.g. a price split
        // across tokens, or a misread currency symbol). This surfaces the
        // raw OCR output so misses can be diagnosed and fixed.
        for line in lines {
            logger.debug("recognized line: \"\(line.text, privacy: .public)\" confidence=\(line.confidence) boundingArea=\(line.boundingArea)")
        }

        guard let capture = CaptureExtractor.extract(from: lines) else {
            logger.debug("extract(from:) found no plausible price in this batch")
            return
        }

        if isDuplicate(of: capture) {
            logger.debug("suppressing duplicate re-read of \"\(capture.name, privacy: .public)\" at \(capture.priceInPence)p")
            return
        }

        lastCapture = capture
        lastCaptureAt = clock.now
        resolve(.captured(capture))
    }

    /// `true` when `capture` matches the last label we resolved a capture
    /// for, within `duplicateSuppressionWindow`. Only name + price are
    /// compared, so a low-confidence read still counts as a duplicate of an
    /// earlier confident one for the same label (and vice versa).
    private func isDuplicate(of capture: Capture) -> Bool {
        guard let lastCapture, let lastCaptureAt else { return false }
        guard lastCapture.name == capture.name, lastCapture.priceInPence == capture.priceInPence else {
            return false
        }
        return clock.now - lastCaptureAt < duplicateSuppressionWindow
    }

    /// Called by the camera view if the user backs out or the camera isn't
    /// available (e.g. no camera hardware, as in the Simulator).
    func handleCancel() {
        resolve(.cancelled)
    }

    private func resolve(_ result: ScanResult) {
        guard continuation != nil else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        isPresenting = false
        continuation?.resume(returning: result)
        continuation = nil
    }
}
