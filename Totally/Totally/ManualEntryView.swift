//
//  ManualEntryView.swift
//  Totally
//
//  Modal form for hand-adding a basket item (name, price, quantity). This is
//  the manual-entry path from docs/architecture/ui.md. Leaving quantity at 1
//  treats the price as a single item's unit price; setting quantity above 1
//  treats it as a multibuy offer TOTAL (e.g. "3 for £1.00"), so the basket
//  line stores that total exactly rather than an approximate unit price. See
//  docs/architecture/basket-domain.md for `add` vs `addOffer`.
//

import SwiftUI

/// The two ways a manual-entry form submission maps onto the domain: a
/// single item at a unit price, or a multibuy offer with an exact total.
/// Pulled out as a pure function so the qty-1-vs-qty>1 routing rule is
/// unit-testable without going through SwiftUI.
enum ManualEntryOutcome: Equatable {
    case item(name: String, unitPriceInPence: Int, quantity: Int)
    case offer(name: String, offerTotalInPence: Int, quantity: Int)

    /// Quantity 1 -> the price is a single unit price (`add`).
    /// Quantity > 1 -> the price is the offer's exact total (`addOffer`).
    static func decide(name: String, priceInPence: Int, quantity: Int) -> ManualEntryOutcome {
        if quantity > 1 {
            return .offer(name: name, offerTotalInPence: priceInPence, quantity: quantity)
        }
        return .item(name: name, unitPriceInPence: priceInPence, quantity: quantity)
    }
}

struct ManualEntryView: View {
    /// Called with the routed outcome when the user commits.
    let onCommit: (_ outcome: ManualEntryOutcome) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var priceText: String = ""
    @State private var quantity: Int = 1

    private var parsedPence: Int? { Money.pence(fromPoundsString: priceText) }
    private var canAdd: Bool { parsedPence != nil }
    private var isOffer: Bool { quantity > 1 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name (optional)", text: $name)
                    HStack {
                        Text(priceLabel)
                        Spacer()
                        TextField("0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Stepper(value: $quantity, in: 1...99) {
                        Text("Quantity: \(quantity)")
                    }
                    if isOffer {
                        Text("Enter the total for all \(quantity), e.g. \"\(quantity) for £1.00\".")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                        let outcome = ManualEntryOutcome.decide(
                            name: trimmed.isEmpty ? "Item" : trimmed,
                            priceInPence: pence,
                            quantity: quantity
                        )
                        onCommit(outcome)
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }

    private var priceLabel: String {
        isOffer ? "Offer total" : "Price"
    }
}

#Preview {
    ManualEntryView { _ in }
}
