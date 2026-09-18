//
//  Money.swift
//  Totally
//
//  UI-only helpers for turning integer pence into pounds-and-pence display
//  strings and parsing user-entered pounds back into pence. The domain
//  always stores integer pence; this file only affects presentation and
//  input parsing at the UI boundary.
//

import Foundation

enum Money {
    /// Formats integer pence as a "£x.yy" string (handles negatives).
    static func string(fromPence pence: Int) -> String {
        let sign = pence < 0 ? "-" : ""
        let absolute = abs(pence)
        let pounds = absolute / 100
        let remainder = absolute % 100
        return String(format: "%@£%d.%02d", sign, pounds, remainder)
    }

    /// Parses a user-entered pounds string (e.g. "1.50", "£1.50", "2")
    /// into integer pence. Returns nil if it can't be parsed.
    static func pence(fromPoundsString text: String) -> Int? {
        var trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("£") {
            trimmed.removeFirst()
        }
        trimmed = trimmed.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        switch parts.count {
        case 1:
            guard let pounds = Int(parts[0]) else { return nil }
            return pounds * 100
        case 2:
            guard let pounds = Int(parts[0]) else { return nil }
            var pencePart = String(parts[1])
            // Normalise to exactly two digits.
            if pencePart.count == 1 { pencePart += "0" }
            guard pencePart.count == 2, let pennies = Int(pencePart) else { return nil }
            return pounds * 100 + pennies
        default:
            return nil
        }
    }
}
