//
//  ManualEntryView.swift
//  Totally
//
//  Simple modal form for hand-adding a basket item (name, price, quantity).
//  This is the manual-entry path from docs/architecture/ui.md. Offers /
//  multibuys get their own dedicated handling in a later milestone; for now
//  this covers the straightforward "add an item" case.
//

import SwiftUI

struct ManualEntryView: View {
    /// Called with the parsed values when the user commits. Price is the
    /// per-unit price in integer pence.
    let onAdd: (_ name: String, _ unitPriceInPence: Int, _ quantity: Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var priceText: String = ""
    @State private var quantity: Int = 1

    private var parsedPence: Int? { Money.pence(fromPoundsString: priceText) }
    private var canAdd: Bool { parsedPence != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name (optional)", text: $name)
                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Stepper(value: $quantity, in: 1...99) {
                        Text("Quantity: \(quantity)")
                    }
                }
            }
            .navigationTitle("Add manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let pence = parsedPence else { return }
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        onAdd(trimmed.isEmpty ? "Item" : trimmed, pence, quantity)
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }
}

#Preview {
    ManualEntryView { _, _, _ in }
}
