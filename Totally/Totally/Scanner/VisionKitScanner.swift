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

@MainActor
@Observable
final class VisionKitScanner: Scanner {
    var isPresenting = false

    private var continuation: CheckedContinuation<ScanResult, Never>?

    func scanNextItem() async -> ScanResult {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.isPresenting = true
        }
    }

    /// Called by the camera view once it has recognised some text.
    func handleRecognizedText(_ lines: [RecognizedLine]) {
        guard let capture = CaptureExtractor.extract(from: lines) else { return }
        resolve(.captured(capture))
    }

    /// Called by the camera view if the user backs out or the camera isn't
    /// available (e.g. no camera hardware, as in the Simulator).
    func handleCancel() {
        resolve(.cancelled)
    }

    private func resolve(_ result: ScanResult) {
        guard continuation != nil else { return }
        isPresenting = false
        continuation?.resume(returning: result)
        continuation = nil
    }
}
