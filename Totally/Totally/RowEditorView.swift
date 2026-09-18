//
//  RowEditorView.swift
//  Totally
//
//  Modal form for correcting a basket row after the fact: name, unit price,
//  and quantity, or deleting the row outright. Seeded from an existing
//  `BasketItem`. See docs/architecture/ui.md.
//

import SwiftUI

struct RowEditorView: View {
    let item: BasketItem

    /// Called with the corrected values when the user saves. Price is the
    /// per-unit price in integer pence; the line total is derived as
    /// price × quantity.
    let onSave: (_ name: String, _ unitPriceInPence: Int, _ quantity: Int) -> Void

    /// Called when the user deletes the row.
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var priceText: String
    @State private var quantity: Int

    init(
        item: BasketItem,
        onSave: @escaping (_ name: String, _ unitPriceInPence: Int, _ quantity: Int) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: item.name)
        _priceText = State(initialValue: Money.string(fromPence: item.unitPriceInPence).replacingOccurrences(of: "£", with: ""))
        _quantity = State(initialValue: item.quantity)
    }

    private var parsedPence: Int? { Money.pence(fromPoundsString: priceText) }
    private var canSave: Bool { parsedPence != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)
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

                Section {
                    Button("Delete item", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let pence = parsedPence else { return }
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        onSave(trimmed.isEmpty ? "Item" : trimmed, pence, quantity)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    RowEditorView(
        item: BasketItem(name: "Bananas", quantity: 2, lineTotalInPence: 138),
        onSave: { _, _, _ in },
        onDelete: {}
    )
}
