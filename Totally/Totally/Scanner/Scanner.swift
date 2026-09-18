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
