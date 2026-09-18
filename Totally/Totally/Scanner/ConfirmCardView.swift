//
//  ConfirmCardView.swift
//  Totally
//
//  The "we're not sure" correction surface. Shown only when a scan is a
//  low-confidence read or a failure — never on a confident auto-add. The
//  card is pre-filled with the best-guess name and price so the user can
//  correct them, then Add commits or Cancel discards. See
//  docs/architecture/ui.md.
//
//  Follows the same completion-closure pattern as `ManualEntryView`: the
//  presenter (`HomeView`) owns the `@State` and passes `onConfirm`; this
//  view owns its own dismissal.
//

import SwiftUI

struct ConfirmCardView: View {
    /// The best-guess capture to pre-fill the fields with. An empty name and
    /// zero price (from a failed read) simply start the user on a blank card.
    let capture: Capture
    /// Called with the corrected values when the user commits. Price is the
    /// per-unit price in integer pence.
    let onConfirm: (_ name: String, _ unitPriceInPence: Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var priceText: String

    init(
        capture: Capture,
        onConfirm: @escaping (_ name: String, _ unitPriceInPence: Int) -> Void
    ) {
        self.capture = capture
        self.onConfirm = onConfirm
        _name = State(initialValue: capture.name)
        // A zero price (failed read) starts blank rather than "0.00".
        let prefillPrice = capture.priceInPence > 0
            ? Money.string(fromPence: capture.priceInPence).replacingOccurrences(of: "£", with: "")
            : ""
        _priceText = State(initialValue: prefillPrice)
    }

    private var parsedPence: Int? { Money.pence(fromPoundsString: priceText) }
    private var canAdd: Bool { parsedPence != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (optional)", text: $name)
                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Check this item")
                } footer: {
                    Text("We weren't sure about this read. Correct it if needed, then add.")
                }
            }
            .navigationTitle("Confirm item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let pence = parsedPence else { return }
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        onConfirm(trimmed.isEmpty ? "Item" : trimmed, pence)
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }
}

#Preview {
    ConfirmCardView(
        capture: Capture(name: "Aldi Free Range Eggs", priceInPence: 189, isConfident: false)
    ) { _, _ in }
}
