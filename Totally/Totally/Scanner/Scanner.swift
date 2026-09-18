//
//  Scanner.swift
//  Totally
//
//  The seam between the UI and everything camera/OCR related. The UI only
//  ever sees `Capture` / `ScanResult` — never Vision or VisionKit types.
//  See docs/architecture/scanner.md.
//

import Foundation

/// A best-guess reading of a shelf label.
struct Capture: Equatable {
    /// Best-guess product name.
    var name: String
    /// The biggest-number price found, as integer pence.
    var priceInPence: Int
    /// `true` -> auto-add; `false` -> show confirm card.
    var isConfident: Bool
}

/// The outcome of one `scanNextItem()` call.
enum ScanResult: Equatable {
    /// A label was read (confident or not — see `Capture.isConfident`).
    case captured(Capture)
    /// The user backed out of the camera without a capture.
    case cancelled
    /// Nothing usable was found.
    case failed(reason: String)
}

/// Presents the camera, resolves once a label is read, cancelled, or failed.
protocol Scanner {
    @MainActor
    func scanNextItem() async -> ScanResult
}

extension ScanResult {
    /// The `Capture` to auto-add to the basket, or `nil` if this result
    /// should not add anything (low-confidence captures, cancellation, or
    /// failure). Low-confidence handling itself is out of scope here — see
    /// docs/architecture/scanner.md — this only decides the auto-add path.
    var captureToAutoAdd: Capture? {
        guard case .captured(let capture) = self, capture.isConfident else { return nil }
        return capture
    }

    /// The pre-fill for the confirm card when the app is *unsure*, or `nil`
    /// when no card should appear. A low-confidence capture pre-fills the
    /// card with its best-guess name/price so the user can correct then add;
    /// a failed read pre-fills an empty card so the user can type it in.
    /// Confident captures (auto-added) and user cancellation show no card.
    /// See docs/architecture/ui.md.
    var captureToConfirm: Capture? {
        switch self {
        case .captured(let capture):
            return capture.isConfident ? nil : capture
        case .failed:
            return Capture(name: "", priceInPence: 0, isConfident: false)
        case .cancelled:
            return nil
        }
    }
}
