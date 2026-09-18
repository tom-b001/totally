//
//  ScannerCameraView.swift
//  Totally
//
//  Thin SwiftUI wrapper around VisionKit's `DataScannerViewController`. Turns
//  live camera text recognition into `RecognizedLine` values (text +
//  bounding box area + OCR confidence); does not interpret them (no
//  price/name extraction here — that's `CaptureExtractor`, via
//  `VisionKitScanner`). See docs/architecture/scanner.md.
//

import SwiftUI
import VisionKit
import os.log

private let logger = Logger(subsystem: "com.totally.app", category: "Scanner")

/// Callback-driven wrapper: reports each batch of recognised text lines as
/// they're read, and reports if the user cancels.
struct ScannerCameraView: UIViewControllerRepresentable {
    var onRecognizedText: (_ lines: [RecognizedLine]) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
            // No camera (e.g. Simulator) — report failure via cancel so the
            // caller can surface a clear "scanning isn't available" result.
            let placeholder = UIViewController()
            placeholder.view.backgroundColor = .black
            DispatchQueue.main.async { onCancel() }
            return placeholder
        }

        let scanner = DataScannerViewController(
            // Pin OCR to English (UK-only app). Without an explicit language,
            // VisionKit auto-detects a locale and has been observed picking
            // Romanian ("Locale not supported: ro"), which misreads "£" as
            // "€"/"E" and mangles diacritics ("70% Dầrk"). Forcing en-GB/en-US
            // makes it transcribe the real "£" and Latin letters correctly.
            recognizedDataTypes: [.text(languages: ["en-GB", "en-US"])],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        // Deliberately NOT starting scanning here: `DataScannerViewController`
        // must already be in the window/view hierarchy for `startScanning()`
        // to actually engage recognition — calling it this early throws (and
        // silently does nothing useful) even though the camera preview and
        // guidance overlay still render. See `updateUIViewController`.
        return scanner
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard !context.coordinator.hasStartedScanning,
              let scanner = uiViewController as? DataScannerViewController else { return }
        context.coordinator.hasStartedScanning = true
        do {
            try scanner.startScanning()
            logger.debug("DataScannerViewController.startScanning() succeeded")
        } catch {
            logger.error("DataScannerViewController.startScanning() failed: \(error, privacy: .public)")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onRecognizedText: onRecognizedText)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onRecognizedText: (_ lines: [RecognizedLine]) -> Void
        var hasStartedScanning = false

        init(onRecognizedText: @escaping (_ lines: [RecognizedLine]) -> Void) {
            self.onRecognizedText = onRecognizedText
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            logger.debug("didAdd: \(addedItems.count) item(s), allItems: \(allItems.count)")
            let lines: [RecognizedLine] = addedItems.compactMap { item in
                guard case .text(let text) = item else { return nil }
                let confidence = text.observation.topCandidates(1).first?.confidence ?? 0
                return RecognizedLine(
                    text: text.transcript,
                    boundingArea: Self.area(of: text.bounds),
                    confidence: confidence
                )
            }
            guard !lines.isEmpty else { return }
            onRecognizedText(lines)
        }

        /// Shoelace-formula area of the bounds quad. `RecognizedItem.Bounds`
        /// is four corner points, not a `CGRect`, so this can't be
        /// `width * height`.
        private static func area(of bounds: RecognizedItem.Bounds) -> CGFloat {
            let points = [bounds.topLeft, bounds.topRight, bounds.bottomRight, bounds.bottomLeft]
            var sum: CGFloat = 0
            for i in 0..<points.count {
                let current = points[i]
                let next = points[(i + 1) % points.count]
                sum += (current.x * next.y) - (next.x * current.y)
            }
            return abs(sum) / 2
        }
    }
}
