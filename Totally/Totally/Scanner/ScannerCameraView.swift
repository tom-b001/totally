//
//  ScannerCameraView.swift
//  Totally
//
//  Thin SwiftUI wrapper around VisionKit's `DataScannerViewController`. Turns
//  live camera text recognition into recognised text tokens; does not
//  interpret them (no price/name extraction here — that's `VisionKitScanner`
//  and, longer-term, totally-716.2.2). See docs/architecture/scanner.md.
//

import SwiftUI
import VisionKit

/// Callback-driven wrapper: reports each batch of recognised text lines as
/// they're read, and reports if the user cancels.
struct ScannerCameraView: UIViewControllerRepresentable {
    var onRecognizedText: (_ lines: [String]) -> Void
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
        private let onRecognizedText: (_ lines: [String]) -> Void

        init(onRecognizedText: @escaping (_ lines: [String]) -> Void) {
            self.onRecognizedText = onRecognizedText
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAddItems addedItems: [RecognizedItem]
        ) {
            let lines: [String] = addedItems.compactMap { item in
                guard case .text(let text) = item else { return nil }
                return text.transcript
            }
            guard !lines.isEmpty else { return }
            onRecognizedText(lines)
        }
    }
}
