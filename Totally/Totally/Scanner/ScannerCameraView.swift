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
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onRecognizedText: onRecognizedText)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onRecognizedText: (_ lines: [RecognizedLine]) -> Void

        init(onRecognizedText: @escaping (_ lines: [RecognizedLine]) -> Void) {
            self.onRecognizedText = onRecognizedText
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAddItems addedItems: [RecognizedItem]
        ) {
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
